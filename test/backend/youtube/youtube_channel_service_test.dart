import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/youtube/youtube_channel_service.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';

const _channel = 'https://www.youtube.com/@curwen';
const _republica = 'https://www.youtube.com/channel/UC-B7Xv56uNRDkj0vC3QW8Cg';

YoutubeProgram _v(String id,
        {int hours = 0, int days = 0, bool noAge = false}) =>
    YoutubeProgram(
      videoId: id,
      title: 'Vídeo $id',
      kind: YoutubeProgramKind.video,
      duration: '10:00',
      age: noAge ? null : Duration(hours: hours, days: days),
    );

YoutubeProgram _live(String id) => YoutubeProgram(
    videoId: id, title: 'Directo $id', kind: YoutubeProgramKind.live);

String _data(List<Map<String, dynamic>> lockups) {
  final data = {
    'items': [
      for (final l in lockups) {'lockupViewModel': l}
    ]
  };
  return '<script>var ytInitialData = ${jsonEncode(data)};</script>';
}

Map<String, dynamic> _video(String id, String age,
        {String? title, bool live = false}) =>
    {
      'contentId': id,
      'contentImage': {
        'b': [
          {
            'thumbnailBadgeViewModel': {
              'text': live ? 'EN VIVO' : '10:00',
              'badgeStyle': live
                  ? 'THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE'
                  : 'THUMBNAIL_OVERLAY_BADGE_STYLE_DEFAULT'
            }
          }
        ]
      },
      'metadata': {
        'lockupMetadataViewModel': {
          'title': {'content': title ?? 'Vídeo $id'},
          'metadata': {
            'metadataParts': [
              {
                'text': {'content': age}
              }
            ]
          }
        }
      }
    };

/// Página mínima con un vídeo por id (11 caracteres) y su antigüedad.
String _page(Map<String, String> videos) =>
    _data([for (final e in videos.entries) _video(e.key, e.value)]);

/// Pestaña de listas: id → título.
String _playlists(Map<String, String> lists) => _data([
      for (final e in lists.entries)
        {
          'contentId': e.key,
          'metadata': {
            'lockupMetadataViewModel': {
              'title': {'content': e.value}
            }
          }
        }
    ]);

http.Response _html(String body) => http.Response.bytes(utf8.encode(body), 200,
    headers: {'content-type': 'text/html; charset=utf-8'});

final _gone = http.Response('no', 404);

bool _isTab(http.Request r) =>
    r.url.path.endsWith('/videos') || r.url.path.endsWith('/streams');

/// Servicio sin esperas y que, salvo que [handler] diga otra cosa, no
/// encuentra la pestaña de listas.
YoutubeChannelService _service(
  Future<http.Response> Function(http.Request r) handler, {
  DateTime Function()? clock,
  Duration? timeout,
  List<http.Request>? log,
}) =>
    YoutubeChannelService(
      clock: clock,
      retryDelay: Duration.zero,
      timeout: timeout ?? const Duration(seconds: 20),
      client: MockClient((r) async {
        log?.add(r);
        return handler(r);
      }),
    );

void main() {
  group('mergeYoutubePrograms', () {
    test('directo primero, luego por antigüedad, sin duplicados', () {
      final v = [_v('a', hours: 16), _v('b', days: 1), _v('dup', days: 2)];
      final s = [
        _live('L'),
        _v('c', hours: 7),
        _v('d', days: 1),
        _v('dup', days: 2),
      ];
      expect(mergeYoutubePrograms(v, s).map((p) => p.videoId),
          ['L', 'c', 'a', 'b', 'd', 'dup']);
    });

    test('la antigüedad desconocida va al final', () {
      expect(
          mergeYoutubePrograms([_v('x', noAge: true), _v('y', hours: 1)], [])
              .map((p) => p.videoId),
          ['y', 'x']);
    });

    test('si un vídeo también figura como directo, gana el directo', () {
      final merged = mergeYoutubePrograms([_v('L', hours: 1)], [_live('L')]);
      expect(merged.single.isLive, isTrue);
    });
  });

  group('YoutubeChannelService: emisiones', () {
    test('pide las pestañas en español con cabeceras de navegador', () async {
      final requests = <http.Request>[];
      final service = _service(log: requests, (r) async {
        if (!_isTab(r)) return _gone;
        return _html(_page({
          r.url.path.endsWith('/videos') ? 'aaaaaaaaaaa' : 'bbbbbbbbbbb':
              r.url.path.endsWith('/videos') ? 'hace 2 h' : 'hace 1 h',
        }));
      });

      final list = await service.programs(_channel);

      expect(requests.map((r) => r.url.toString()).toSet(), {
        'https://www.youtube.com/@curwen/videos?hl=es',
        'https://www.youtube.com/@curwen/streams?hl=es',
        'https://www.youtube.com/@curwen/playlists?hl=es',
      });
      for (final r in requests) {
        expect(r.headers['Cookie'], 'SOCS=CAI');
        expect(r.headers['User-Agent'], contains('Chrome'));
        expect(r.headers['Accept-Language'], startsWith('es'));
      }
      expect(list.map((p) => p.videoId), ['bbbbbbbbbbb', 'aaaaaaaaaaa']);
      expect(list.first.title, 'Vídeo bbbbbbbbbbb');
    });

    test('una pestaña caída: devuelve la otra', () async {
      final service = _service((r) async => r.url.path.endsWith('/videos')
          ? _html(_page({'aaaaaaaaaaa': 'hace 2 h'}))
          : _gone);
      final list = await service.programs(_channel);
      expect(list.single.videoId, 'aaaaaaaaaaa');
    });

    test('una pestaña con error de red: devuelve la otra', () async {
      final service = _service((r) async {
        if (r.url.path.endsWith('/streams')) {
          return _html(_page({'bbbbbbbbbbb': 'hace 1 h'}));
        }
        throw http.ClientException('sin red');
      });
      expect((await service.programs(_channel)).single.videoId, 'bbbbbbbbbbb');
    });

    test('las dos caídas, también al reintentar: lanza', () async {
      final requests = <http.Request>[];
      final service =
          _service(log: requests, (r) async => http.Response('no', 500));
      await expectLater(service.programs(_channel),
          throwsA(isA<YoutubeUnavailableException>()));
      expect(requests.where((r) => r.url.path.endsWith('/videos')).length, 2);
      expect(requests.where((r) => r.url.path.endsWith('/streams')).length, 2);
    });

    test('páginas sin ytInitialData: lanza', () async {
      final service =
          _service((r) async => _html('<html>Antes de continuar</html>'));
      expect(service.programs(_channel),
          throwsA(isA<YoutubeUnavailableException>()));
    });

    test('una página que llega sin datos se pide otra vez', () async {
      final requests = <http.Request>[];
      var streams = 0;
      final service = _service(log: requests, (r) async {
        if (r.url.path.endsWith('/videos')) {
          return _html(_page({'aaaaaaaaaaa': 'hace 2 h'}));
        }
        if (r.url.path.endsWith('/streams')) {
          return ++streams == 1
              ? _html('<html>sin datos</html>')
              : _html(_page({'bbbbbbbbbbb': 'hace 1 h'}));
        }
        return _gone;
      });
      final list = await service.programs(_channel);
      expect(list.map((p) => p.videoId), ['bbbbbbbbbbb', 'aaaaaaaaaaa']);
      expect(streams, 2);
      expect(requests.where((r) => r.url.path.endsWith('/videos')).length, 1);
    });

    test('una pestaña que no responde a tiempo cuenta como caída, sin repetir',
        () async {
      var streams = 0;
      final service = _service(
        timeout: const Duration(milliseconds: 50),
        (r) async {
          if (r.url.path.endsWith('/streams')) {
            streams++;
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
          return _isTab(r) ? _html(_page({'aaaaaaaaaaa': 'hace 2 h'})) : _gone;
        },
      );
      expect((await service.programs(_channel)).single.videoId, 'aaaaaaaaaaa');
      expect(streams, 1);
    });

    test('caché de 2 minutos por canal; force la ignora', () async {
      var calls = 0;
      var now = DateTime(2026, 11, 11, 10);
      final service = _service(clock: () => now, (r) async {
        if (!_isTab(r)) return _gone;
        calls++;
        return _html(_page({'aaaaaaaaaaa': 'hace 2 h'}));
      });

      await service.programs(_channel);
      expect(calls, 2);
      now = now.add(const Duration(minutes: 1));
      await service.channelPage(_channel);
      expect(calls, 2, reason: 'dentro de los 2 minutos no vuelve a pedir');
      await service.programs('https://www.youtube.com/@leonmoya');
      expect(calls, 4, reason: 'otro canal no comparte la caché');
      await service.programs(_channel, force: true);
      expect(calls, 6);
      now = now.add(const Duration(minutes: 3));
      await service.programs(_channel);
      expect(calls, 8, reason: 'caducada');
    });

    test('un fallo no se guarda en la caché', () async {
      var fail = true;
      final service = _service((r) async => fail || !_isTab(r)
          ? http.Response('no', 500)
          : _html(_page({'aaaaaaaaaaa': 'hace 2 h'})));
      await expectLater(service.programs(_channel),
          throwsA(isA<YoutubeUnavailableException>()));
      fail = false;
      expect((await service.programs(_channel)).single.videoId, 'aaaaaaaaaaa');
    });
  });

  group('YoutubeChannelService: programas', () {
    test('une lo reconocido por el título con lo que trae la lista', () async {
      final service = _service((r) async {
        final path = r.url.path;
        if (path.endsWith('/videos')) {
          return _html(_data([
            _video('hoyhoyhoyho', 'hace 1 h', title: 'CONFIRMADO #LaEncerrona'),
            _video('ayerayeraye', 'hace 1 día', title: 'URGENTE #LaEncerrona'),
            _video('islasislasi', 'hace 2 días',
                title: 'Trump - Pequeñas Islas'),
            _video('sueltosuelt', 'hace 3 días',
                title: 'ESPECIAL sin programa'),
          ]));
        }
        if (path.endsWith('/streams')) return _html(_data([]));
        if (path.endsWith('/playlists')) {
          return _html(_playlists({
            'PLencerrona1': '#LaEncerrona',
            'PLislas00001': 'Pequeñas Islas',
          }));
        }
        return switch (r.url.queryParameters['list']) {
          // La de hoy aún no está en la lista; trae una más antigua.
          'PLencerrona1' => _html(_data([
              _video('ayerayeraye', 'hace 1 día',
                  title: 'URGENTE #LaEncerrona'),
              _video('viejaviejav', 'hace 5 días', title: 'Sin etiqueta'),
            ])),
          'PLislas00001' => _html(_data([
              _video('islasislasi', 'hace 2 días',
                  title: 'Trump - Pequeñas Islas'),
            ])),
          _ => _gone,
        };
      });

      final page = await service.channelPage(
          'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg');

      expect(page.programs.length, 4);
      final shows = {for (final s in page.shows) s.key: s};
      expect(shows.keys, ['laencerrona', 'pequenasislas']);
      expect(shows['laencerrona']!.name, 'La Encerrona');
      expect(shows['laencerrona']!.programs.map((p) => p.videoId),
          ['hoyhoyhoyho', 'ayerayeraye', 'viejaviejav']);
      expect(shows['pequenasislas']!.programs.single.videoId, 'islasislasi');
    });

    test('un directo sigue en directo aunque su lista lo traiga como vídeo',
        () async {
      final service = _service((r) async {
        final path = r.url.path;
        if (path.endsWith('/videos')) return _html(_data([]));
        if (path.endsWith('/streams')) {
          return _html(_data([
            _video('vivovivoviv', '', title: 'Hoy | La Contra', live: true),
          ]));
        }
        if (path.endsWith('/playlists')) {
          return _html(_playlists({
            'PLcontra0001': 'La Contra EN VIVO',
            'PLcontra0002': 'La Contra Podcast',
          }));
        }
        if (r.url.queryParameters['list'] == 'PLcontra0002') {
          return _html(_data([]));
        }
        return _html(_data([
          _video('vivovivoviv', 'hace 1 h', title: 'Hoy | La Contra'),
          _video('otrootrootr', 'hace 2 días', title: 'Ayer'),
        ]));
      });
      final show = (await service.channelPage(_channel)).shows.single;
      expect(show.name, 'La Contra');
      expect(
          show.programs.map((p) => p.videoId), ['vivovivoviv', 'otrootrootr']);
      expect(show.programs.first.isLive, isTrue);
    });

    test('lee como mucho 6 listas: primero las preferidas', () async {
      final requests = <http.Request>[];
      final lists = {
        for (var i = 1; i <= 9; i++) 'PLlista0000$i': 'Programa número $i'
      };
      final service = _service(log: requests, (r) async {
        final path = r.url.path;
        if (path.endsWith('/videos')) {
          return _html(_page({'aaaaaaaaaaa': 'hace 2 h'}));
        }
        if (path.endsWith('/streams')) return _html(_data([]));
        if (path.endsWith('/playlists')) return _html(_playlists(lists));
        return _html(_data([
          _video('${r.url.queryParameters['list']!.substring(2, 12)}x',
              'hace 3 días'),
        ]));
      });

      final page = await service
          .channelPage(_channel, preferred: ['programanumero9', 'noexiste']);

      final read = [
        for (final r in requests)
          if (r.url.path == '/playlist') r.url.queryParameters['list']
      ];
      expect(read.length, YoutubeChannelService.maxPlaylistPages);
      expect(read.toSet(), {
        'PLlista00009',
        'PLlista00001',
        'PLlista00002',
        'PLlista00003',
        'PLlista00004',
        'PLlista00005',
      });
      for (final r in requests.where((r) => r.url.path == '/playlist')) {
        expect(r.url.queryParameters['hl'], 'es');
      }
      expect(page.shows.map((s) => s.key), contains('programanumero9'));
      expect(page.shows.length, 6, reason: 'los no leídos no tienen emisiones');
    });

    test('cada programa guarda como mucho 20 emisiones', () async {
      final service = _service((r) async {
        final path = r.url.path;
        if (path.endsWith('/playlists')) {
          return _html(_playlists({'PLmuchos0001': 'Muchos'}));
        }
        if (_isTab(r)) return _html(_page({'aaaaaaaaaaa': 'hace 2 h'}));
        return _html(_data([
          for (var i = 10; i < 40; i++) _video('video0000$i', 'hace $i días'),
        ]));
      });
      final show = (await service.channelPage(_channel)).shows.single;
      expect(show.programs.length, YoutubeChannelService.maxShowPrograms);
      expect(show.programs.first.videoId, 'video000010');
    });

    test('sin pestaña de listas quedan los programas incorporados', () async {
      final requests = <http.Request>[];
      final service = _service(log: requests, (r) async {
        final path = r.url.path;
        if (path.endsWith('/streams')) {
          return _html(_data([
            _video('guionguiong', 'hace 2 h',
                title: 'KEIKO SE VA | SIN GUION CON ROSA MARÍA PALACIOS'),
            _video('troyatroyat', 'hace 9 h',
                title: 'KEIKO CHOTEA AL PAPA | ARDE TROYA'),
            _video('papapapapap', 'hace 10 h', title: 'EN VIVO | PAPA | #lr'),
          ]));
        }
        if (path.endsWith('/videos')) return _html(_data([]));
        return _html('<html>sin datos</html>');
      });

      final page = await service.channelPage(_republica);

      expect(
          requests.where((r) => r.url.path.endsWith('/playlists')).length, 2);
      expect(page.programs.length, 3);
      expect(page.shows.map((s) => s.name), ['Sin Guion', 'Arde Troya']);
      expect(page.shows.first.programs.single.videoId, 'guionguiong');
    });

    test('una lista que falla no estropea su programa', () async {
      final service = _service((r) async {
        final path = r.url.path;
        if (path.endsWith('/videos')) {
          return _html(_data([
            _video('hoyhoyhoyho', 'hace 1 h', title: 'CONFIRMADO #LaEncerrona'),
          ]));
        }
        if (path.endsWith('/streams')) return _html(_data([]));
        if (path.endsWith('/playlists')) {
          return _html(_playlists({'PLencerrona1': '#LaEncerrona'}));
        }
        throw http.ClientException('sin red');
      });
      final show = (await service.channelPage(_channel)).shows.single;
      expect(show.programs.single.videoId, 'hoyhoyhoyho');
    });
  });
}
