import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/plex_vod_provider.dart';
import 'package:open_tv/backend/ondemand/uuid.dart';

final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

const _peli = OnDemandTitle(
  id: 'rk1',
  title: 'P',
  synopsis: '',
  posterUrl: '',
  details: '',
  source: PlexSource('rk1'),
);

OnDemandTitle _con(OnDemandSource s) => OnDemandTitle(
    id: 'x', title: '', synopsis: '', posterUrl: '', details: '', source: s);

String _meta({String protocol = 'hls', String key = '/library/parts/abc-hls.m3u8'}) =>
    jsonEncode({
      'MediaContainer': {
        'Metadata': [
          {
            'Media': [
              {
                'protocol': 'dash',
                'Part': [
                  {'key': '/library/parts/abc-dash.mpd'}
                ]
              },
              {
                'protocol': protocol,
                'Part': [
                  {'key': key}
                ]
              },
            ]
          }
        ]
      }
    });

class _Plex {
  int sessions = 0;
  final List<http.Request> requests = [];
  int sessionStatus = 200;
  String sessionBody = '';
  Object? error;
  Set<String> failingHubs = {};
  String metadata = _meta();

  http.Client client() => MockClient((r) async {
        requests.add(r);
        if (error != null) throw error!;
        if (r.url.host == 'clients.plex.tv') {
          sessions++;
          return http.Response(
              sessionBody.isNotEmpty
                  ? sessionBody
                  : jsonEncode({'authToken': 'tok$sessions'}),
              sessionStatus);
        }
        final path = r.url.path;
        if (path == '/hubs/promoted') {
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'MediaContainer': {
                  'Hub': [
                    {'title': 'En Español', 'key': '/hubs/sections/movies/es'},
                    {'title': 'Terror', 'key': '/hubs/sections/movies/terror'},
                  ]
                }
              })),
              200);
        }
        if (path.startsWith('/hubs/sections/movies/')) {
          if (failingHubs.contains(path)) return http.Response('x', 500);
          return http.Response.bytes(utf8.encode('{"hub":"$path"}'), 200);
        }
        if (path.startsWith('/library/metadata/')) {
          return http.Response(metadata, 200);
        }
        return http.Response('no', 404);
      });
}

Future<List<OnDemandTitle>> _fakeParse(
        List<({String title, String json})> hubs) async =>
    [_peli];

void main() {
  test('newUuidV4 tiene forma de UUID v4 y no se repite', () {
    final a = newUuidV4(), b = newUuidV4();
    expect(a, matches(_uuid));
    expect(b, matches(_uuid));
    expect(a, isNot(b));
  });

  group('pickPlexStream', () {
    test('elige el HLS, con el token en la URL y en la cabecera', () {
      final s = pickPlexStream('rk1', 'tok', _meta());
      expect(s.url,
          'https://vod.provider.plex.tv/library/parts/abc-hls.m3u8?X-Plex-Token=tok');
      expect(s.headers, {'X-Plex-Token': 'tok'});
    });

    test('sin HLS, sin Media o JSON roto → OnDemandUnavailableException', () {
      for (final bad in [_meta(protocol: 'dash'), '{}', 'no json']) {
        expect(() => pickPlexStream('rk1', 'tok', bad),
            throwsA(isA<OnDemandUnavailableException>()),
            reason: bad);
      }
    });
  });

  test('sesión anónima con las cabeceras de Plex', () async {
    final s = _Plex();
    final p = PlexVodProvider(client: s.client(), parse: _fakeParse);
    await p.titles();
    final r = s.requests.first;
    expect(r.method, 'POST');
    expect(r.url.toString(), 'https://clients.plex.tv/api/v2/users/anonymous');
    expect(r.headers['X-Plex-Client-Identifier'], matches(_uuid));
    expect(r.headers['X-Plex-Product'], 'Plex Web');
    expect(r.headers['X-Plex-Version'], isNotEmpty);
    expect(r.headers['X-Plex-Platform'], isNotEmpty);
    expect(r.headers['Accept'], 'application/json');
  });

  test('titles(): estantes de /hubs/promoted, cada uno por su key', () async {
    final s = _Plex();
    List<({String title, String json})>? got;
    final p = PlexVodProvider(
      client: s.client(),
      parse: (hubs) async {
        got = hubs;
        return [_peli];
      },
    );
    expect(await p.titles(), hasLength(1));

    final promoted =
        s.requests.firstWhere((r) => r.url.path == '/hubs/promoted');
    expect(promoted.url.host, 'vod.provider.plex.tv');
    expect(promoted.headers['X-Plex-Token'], 'tok1');
    final hubReqs = s.requests
        .where((r) => r.url.path.startsWith('/hubs/sections/movies/'))
        .toList();
    expect(hubReqs.map((r) => r.url.path),
        unorderedEquals(['/hubs/sections/movies/es', '/hubs/sections/movies/terror']));
    expect(hubReqs.every((r) => r.url.queryParameters['count'] == '100'), isTrue);
    expect(got!.map((h) => h.title), ['En Español', 'Terror']);
    expect(got!.first.json, '{"hub":"/hubs/sections/movies/es"}');
  });

  test('un estante que falla se omite; si fallan todos → excepción', () async {
    final s = _Plex()..failingHubs = {'/hubs/sections/movies/es'};
    List<({String title, String json})>? got;
    final p = PlexVodProvider(
        client: s.client(),
        parse: (hubs) async {
          got = hubs;
          return [_peli];
        });
    await p.titles();
    expect(got!.map((h) => h.title), ['Terror']);

    final s2 = _Plex()
      ..failingHubs = {
        '/hubs/sections/movies/es',
        '/hubs/sections/movies/terror'
      };
    final p2 = PlexVodProvider(client: s2.client(), parse: _fakeParse);
    await expectLater(
        p2.titles(), throwsA(isA<OnDemandUnavailableException>()));
  });

  test('caché de 30 minutos', () async {
    final s = _Plex();
    var now = DateTime(2026, 11, 15, 12);
    final p = PlexVodProvider(
        client: s.client(), parse: _fakeParse, now: () => now);
    await p.titles();
    await p.titles();
    expect(s.sessions, 1);
    now = now.add(const Duration(minutes: 31));
    await p.titles();
    expect(s.sessions, 2);
  });

  test('resolve(): sesión nueva, metadata y URL con token; 2 resolves → 2 sesiones',
      () async {
    final s = _Plex();
    final p = PlexVodProvider(client: s.client(), parse: _fakeParse);
    final a = await p.resolve(_peli);
    expect(a.url,
        'https://vod.provider.plex.tv/library/parts/abc-hls.m3u8?X-Plex-Token=tok1');
    final meta = s.requests.firstWhere((r) => r.url.path == '/library/metadata/rk1');
    expect(meta.headers['X-Plex-Token'], 'tok1');
    final b = await p.resolve(_peli);
    expect(b.headers, {'X-Plex-Token': 'tok2'});
    expect(s.sessions, 2);
  });

  test('resolve(): rechaza lo que no es PlexSource o trae id raro', () async {
    final p = PlexVodProvider(client: _Plex().client(), parse: _fakeParse);
    await expectLater(p.resolve(_con(const VimeoSource('1'))), throwsArgumentError);
    for (final bad in ['a/../b', 'x?y', '', 'a b', 'á', 'x' * 65]) {
      await expectLater(p.resolve(_con(PlexSource(bad))), throwsArgumentError,
          reason: 'id «$bad»');
    }
  });

  group('errores → OnDemandUnavailableException', () {
    test('sesión HTTP 500, sin authToken o JSON roto', () async {
      for (final setup in [
        (_Plex()..sessionStatus = 500),
        (_Plex()..sessionBody = '{}'),
        (_Plex()..sessionBody = 'no json'),
        (_Plex()..sessionBody = '{"authToken": 3}'),
      ]) {
        final p = PlexVodProvider(client: setup.client(), parse: _fakeParse);
        await expectLater(
            p.titles(), throwsA(isA<OnDemandUnavailableException>()));
        await expectLater(
            p.resolve(_peli), throwsA(isA<OnDemandUnavailableException>()));
      }
    });

    test('error de red y no se cachea', () async {
      final s = _Plex()..error = http.ClientException('sin red');
      final p = PlexVodProvider(client: s.client(), parse: _fakeParse);
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
      s.error = null;
      expect(await p.titles(), hasLength(1));
    });

    test('resolve con metadata sin HLS', () async {
      final s = _Plex()..metadata = _meta(protocol: 'dash');
      final p = PlexVodProvider(client: s.client(), parse: _fakeParse);
      await expectLater(
          p.resolve(_peli), throwsA(isA<OnDemandUnavailableException>()));
    });
  });

  test('id y nombre', () {
    final p = PlexVodProvider(client: _Plex().client());
    expect(p.id, 'plex');
    expect(p.name, 'Plex');
  });
}
