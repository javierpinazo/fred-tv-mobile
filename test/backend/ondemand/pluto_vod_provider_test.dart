import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/pluto_vod_provider.dart';

const _vod = 'https://vod.example';
const _stitcher = 'https://stitch.example';

String _session(String token) => jsonEncode({
      'sessionToken': token,
      'stitcherParams': 'appName=web&deviceId=abc',
      'servers': {'vod': _vod, 'stitcher': _stitcher},
    });

const _peli = OnDemandTitle(
  id: 'abc123def456',
  title: 'P',
  synopsis: '',
  posterUrl: '',
  details: '',
  source: PlutoSource('abc123def456'),
);

class _Server {
  int sessions = 0;
  int catalogs = 0;
  final List<http.Request> requests = [];
  int sessionStatus = 200;
  int catalogStatus = 200;
  Object? sessionBody;
  Object? error;

  http.Client client() => MockClient((r) async {
        requests.add(r);
        if (error != null) throw error!;
        if (r.url.host == 'boot.pluto.tv') {
          sessions++;
          return http.Response(
              (sessionBody as String?) ?? _session('tok$sessions'),
              sessionStatus);
        }
        catalogs++;
        return http.Response.bytes(utf8.encode('{"catalogo": "Tú"}'), catalogStatus);
      });
}

Future<List<OnDemandTitle>> _fakeParse(String json) async =>
    [_peli.copyTitle(json)];

extension on OnDemandTitle {
  OnDemandTitle copyTitle(String t) => OnDemandTitle(
      id: id,
      title: t,
      synopsis: synopsis,
      posterUrl: posterUrl,
      details: details,
      source: source);
}

void main() {
  test('titles(): sesión, catálogo con Bearer y parseo del cuerpo UTF-8',
      () async {
    final s = _Server();
    final p = PlutoVodProvider(client: s.client(), parse: _fakeParse);
    final titles = await p.titles();
    expect(titles.single.title, '{"catalogo": "Tú"}');

    final boot = s.requests.first.url;
    expect(boot.host, 'boot.pluto.tv');
    expect(boot.path, '/v4/start');
    expect(boot.queryParameters['appName'], 'web');
    expect(boot.queryParameters['deviceType'], 'web');
    expect(boot.queryParameters['serverSideAds'], 'false');
    expect(boot.queryParameters['clientID'],
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));

    final cat = s.requests.last;
    expect(cat.url.toString(),
        '$_vod/v4/vod/categories?includeItems=true&offset=1000&page=1');
    expect(cat.headers['Authorization'], 'Bearer tok1');
  });

  test('caché de 30 minutos', () async {
    final s = _Server();
    var now = DateTime(2026, 11, 15, 12);
    final p = PlutoVodProvider(
        client: s.client(), parse: _fakeParse, now: () => now);
    await p.titles();
    await p.titles();
    expect(s.catalogs, 1);
    now = now.add(const Duration(minutes: 31));
    await p.titles();
    expect(s.catalogs, 2);
  });

  test('resolve(): URL del maestro y Bearer, con sesión nueva cada vez',
      () async {
    final s = _Server();
    final p = PlutoVodProvider(client: s.client(), parse: _fakeParse);
    await p.titles(); // sesión del catálogo (tok1)
    final a = await p.resolve(_peli);
    expect(a.url,
        '$_stitcher/v2/stitch/hls/episode/abc123def456/master.m3u8?appName=web&deviceId=abc&jwt=tok2');
    expect(a.headers, {'Authorization': 'Bearer tok2'});
    final b = await p.resolve(_peli);
    expect(b.headers, {'Authorization': 'Bearer tok3'});
    expect(s.sessions, 3);
  });

  test('resolve(): rechaza lo que no es PlutoSource o trae id raro', () async {
    final p = PlutoVodProvider(client: _Server().client(), parse: _fakeParse);
    OnDemandTitle con(OnDemandSource src) => OnDemandTitle(
        id: 'x', title: '', synopsis: '', posterUrl: '', details: '', source: src);
    await expectLater(
        p.resolve(con(const VimeoSource('1'))), throwsArgumentError);
    for (final bad in ['a/../b', 'x?y', '', 'a b', 'á', 'x' * 65]) {
      await expectLater(p.resolve(con(PlutoSource(bad))), throwsArgumentError,
          reason: 'id «$bad»');
    }
  });

  group('errores → OnDemandUnavailableException', () {
    test('HTTP 500 en la sesión', () async {
      final s = _Server()..sessionStatus = 500;
      final p = PlutoVodProvider(client: s.client(), parse: _fakeParse);
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
      await expectLater(
          p.resolve(_peli), throwsA(isA<OnDemandUnavailableException>()));
    });

    test('HTTP 401 en el catálogo y no se cachea', () async {
      final s = _Server()..catalogStatus = 401;
      final p = PlutoVodProvider(client: s.client(), parse: _fakeParse);
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
      s.catalogStatus = 200;
      expect(await p.titles(), hasLength(1));
    });

    test('error de red', () async {
      final s = _Server()..error = http.ClientException('sin red');
      final p = PlutoVodProvider(client: s.client(), parse: _fakeParse);
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
    });

    test('sesión sin sessionToken o con JSON roto', () async {
      for (final body in ['{}', 'no json', '{"sessionToken": 3}']) {
        final s = _Server()..sessionBody = body;
        final p = PlutoVodProvider(client: s.client(), parse: _fakeParse);
        await expectLater(
            p.titles(), throwsA(isA<OnDemandUnavailableException>()),
            reason: body);
      }
    });

    test('el parser lanza OnDemandUnavailableException', () async {
      final p = PlutoVodProvider(
          client: _Server().client(),
          parse: (_) async => throw OnDemandUnavailableException('x'));
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
    });
  });

  test('id y nombre', () {
    final p = PlutoVodProvider(client: _Server().client());
    expect(p.id, 'pluto');
    expect(p.name, 'Pluto TV');
  });
}
