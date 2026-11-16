import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/ondemand/archive_vod_provider.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

String meta(List<Map<String, Object?>> files) => jsonEncode({'files': files});

Map<String, Object?> file(String name, String format, {Object? size = '100'}) =>
    {'name': name, 'format': format, 'size': size};

const _peli = OnDemandTitle(
  id: 'carne-1968',
  title: 'Carne',
  synopsis: '',
  posterUrl: '',
  details: '',
  source: ArchiveSource('carne-1968'),
);

OnDemandTitle _con(OnDemandSource s) => OnDemandTitle(
    id: 'x', title: '', synopsis: '', posterUrl: '', details: '', source: s);

Future<List<OnDemandTitle>> _fakeParse(String json) async => [_peli];

void main() {
  group('pickArchiveStream', () {
    test('prefiere h.264, luego MPEG4, luego 512Kb MPEG4, luego cualquier mp4',
        () {
      String pick(List<Map<String, Object?>> f) =>
          pickArchiveStream('id', meta(f)).url;
      expect(
          pick([
            file('a.512kb.mp4', '512Kb MPEG4'),
            file('a.mp4', 'MPEG4'),
            file('a.ia.mp4', 'h.264 IA'),
          ]),
          'https://archive.org/download/id/a.ia.mp4');
      expect(
          pick([file('a.512kb.mp4', '512Kb MPEG4'), file('a.mp4', 'MPEG4')]),
          'https://archive.org/download/id/a.mp4');
      expect(pick([file('a.512kb.mp4', '512Kb MPEG4'), file('z.mp4', 'Otro')]),
          'https://archive.org/download/id/a.512kb.mp4');
      expect(pick([file('z.mp4', 'Otro')]),
          'https://archive.org/download/id/z.mp4');
    });

    test('ignora archivos que no son mp4', () {
      expect(
          pickArchiveStream(
                  'id',
                  meta([
                    file('a.ogv', 'Ogg Video'),
                    file('a.mkv', 'Matroska'),
                    file('a.mp4', 'MPEG4'),
                  ]))
              .url,
          'https://archive.org/download/id/a.mp4');
    });

    test('codifica espacios y paréntesis y no lleva cabeceras', () {
      final s = pickArchiveStream(
          'carne-1968', meta([file('Carne Argentina (1968).ia.mp4', 'h.264 IA')]));
      expect(s.url,
          'https://archive.org/download/carne-1968/Carne%20Argentina%20%281968%29.ia.mp4');
      expect(s.headers, isEmpty);
    });

    test('sin ningún mp4, sin files o JSON roto → OnDemandUnavailableException',
        () {
      for (final bad in [
        meta([file('a.ogv', 'Ogg Video')]),
        meta([]),
        '{}',
        'no json',
      ]) {
        expect(() => pickArchiveStream('id', bad),
            throwsA(isA<OnDemandUnavailableException>()),
            reason: bad);
      }
    });
  });

  test('titles(): consulta, parseo UTF-8 y caché de 30 minutos', () async {
    final requests = <Uri>[];
    var now = DateTime(2026, 11, 15, 12);
    final p = ArchiveVodProvider(
      client: MockClient((r) async {
        requests.add(r.url);
        return http.Response.bytes(utf8.encode('{"ñ": 1}'), 200);
      }),
      parse: (json) async {
        expect(json, '{"ñ": 1}');
        return [_peli];
      },
      now: () => now,
    );
    expect(await p.titles(), hasLength(1));

    final q = requests.single;
    expect(q.host, 'archive.org');
    expect(q.path, '/advancedsearch.php');
    expect(q.queryParameters['q'],
        'mediatype:movies AND collection:feature_films AND language:(spanish OR Spanish OR spa)');
    expect(q.queryParametersAll['fl[]'],
        ['identifier', 'title', 'year', 'description', 'subject']);
    expect(q.queryParameters['rows'], '2000');
    expect(q.queryParameters['output'], 'json');
    expect(q.queryParameters['sort[]'], 'downloads desc');

    await p.titles();
    expect(requests, hasLength(1));
    now = now.add(const Duration(minutes: 31));
    await p.titles();
    expect(requests, hasLength(2));
  });

  test('resolve(): pide metadata/<id> y elige el mp4', () async {
    final requests = <Uri>[];
    final p = ArchiveVodProvider(
      client: MockClient((r) async {
        requests.add(r.url);
        return http.Response(
            meta([file('Carne Argentina (1968).ia.mp4', 'h.264 IA')]), 200);
      }),
      parse: _fakeParse,
    );
    final s = await p.resolve(_peli);
    expect(requests.single.toString(), 'https://archive.org/metadata/carne-1968');
    expect(s.url,
        'https://archive.org/download/carne-1968/Carne%20Argentina%20%281968%29.ia.mp4');
  });

  test('resolve(): rechaza lo que no es ArchiveSource o trae id raro', () async {
    final p = ArchiveVodProvider(
        client: MockClient((_) async => http.Response('{}', 200)),
        parse: _fakeParse);
    await expectLater(p.resolve(_con(const VimeoSource('1'))), throwsArgumentError);
    for (final bad in ['a/b', 'x?y', '', 'a b', 'á', 'x' * 129]) {
      await expectLater(p.resolve(_con(ArchiveSource(bad))), throwsArgumentError,
          reason: 'id «$bad»');
    }
  });

  group('errores → OnDemandUnavailableException', () {
    test('HTTP 500 en titles() y resolve()', () async {
      final p = ArchiveVodProvider(
          client: MockClient((_) async => http.Response('x', 500)),
          parse: _fakeParse);
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
      await expectLater(
          p.resolve(_peli), throwsA(isA<OnDemandUnavailableException>()));
    });

    test('error de red y no se cachea', () async {
      var fail = true;
      final p = ArchiveVodProvider(
        client: MockClient((_) async {
          if (fail) throw http.ClientException('sin red');
          return http.Response('{}', 200);
        }),
        parse: _fakeParse,
      );
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
      fail = false;
      expect(await p.titles(), hasLength(1));
    });

    test('el parser lanza OnDemandUnavailableException', () async {
      final p = ArchiveVodProvider(
          client: MockClient((_) async => http.Response('{}', 200)),
          parse: (_) async => throw OnDemandUnavailableException('x'));
      await expectLater(
          p.titles(), throwsA(isA<OnDemandUnavailableException>()));
    });
  });

  test('id y nombre', () {
    final p = ArchiveVodProvider(
        client: MockClient((_) async => http.Response('{}', 200)));
    expect(p.id, 'archive');
    expect(p.name, 'Internet Archive');
  });
}
