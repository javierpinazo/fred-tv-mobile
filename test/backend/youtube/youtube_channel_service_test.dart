import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/youtube/youtube_channel_service.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';

const _channel = 'https://www.youtube.com/@curwen';

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

/// Página mínima con un vídeo por id (11 caracteres) y su antigüedad.
String _page(Map<String, String> videos) {
  final data = {
    'items': [
      for (final e in videos.entries)
        {
          'lockupViewModel': {
            'contentId': e.key,
            'contentImage': {
              'b': [
                {
                  'thumbnailBadgeViewModel': {
                    'text': '10:00',
                    'badgeStyle': 'THUMBNAIL_OVERLAY_BADGE_STYLE_DEFAULT'
                  }
                }
              ]
            },
            'metadata': {
              'lockupMetadataViewModel': {
                'title': {'content': 'Vídeo ${e.key}'},
                'metadata': {
                  'metadataParts': [
                    {
                      'text': {'content': e.value}
                    }
                  ]
                }
              }
            }
          }
        }
    ]
  };
  return '<script>var ytInitialData = ${jsonEncode(data)};</script>';
}

http.Response _html(String body) => http.Response.bytes(utf8.encode(body), 200,
    headers: {'content-type': 'text/html; charset=utf-8'});

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

  group('YoutubeChannelService', () {
    test('pide las dos pestañas en español con cabeceras de navegador',
        () async {
      final requests = <http.Request>[];
      final service = YoutubeChannelService(client: MockClient((r) async {
        requests.add(r);
        return _html(_page({
          r.url.path.endsWith('/videos') ? 'aaaaaaaaaaa' : 'bbbbbbbbbbb':
              r.url.path.endsWith('/videos') ? 'hace 2 h' : 'hace 1 h',
        }));
      }));

      final list = await service.programs(_channel);

      expect(requests.map((r) => r.url.toString()).toSet(), {
        'https://www.youtube.com/@curwen/videos?hl=es',
        'https://www.youtube.com/@curwen/streams?hl=es',
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
      final service = YoutubeChannelService(
          client: MockClient((r) async => r.url.path.endsWith('/streams')
              ? http.Response('no', 404)
              : _html(_page({'aaaaaaaaaaa': 'hace 2 h'}))));
      final list = await service.programs(_channel);
      expect(list.single.videoId, 'aaaaaaaaaaa');
    });

    test('una pestaña con error de red: devuelve la otra', () async {
      final service = YoutubeChannelService(client: MockClient((r) async {
        if (r.url.path.endsWith('/videos')) {
          throw http.ClientException('sin red');
        }
        return _html(_page({'bbbbbbbbbbb': 'hace 1 h'}));
      }));
      expect((await service.programs(_channel)).single.videoId, 'bbbbbbbbbbb');
    });

    test('las dos caídas: lanza', () async {
      final service = YoutubeChannelService(
          client: MockClient((r) async => http.Response('no', 500)));
      expect(service.programs(_channel),
          throwsA(isA<YoutubeUnavailableException>()));
    });

    test('páginas sin ytInitialData: lanza', () async {
      final service = YoutubeChannelService(
          client: MockClient(
              (r) async => _html('<html>Antes de continuar</html>')));
      expect(service.programs(_channel),
          throwsA(isA<YoutubeUnavailableException>()));
    });

    test('una pestaña que no responde a tiempo cuenta como caída', () async {
      final service = YoutubeChannelService(
        timeout: const Duration(milliseconds: 50),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/streams')) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
          return _html(_page({'aaaaaaaaaaa': 'hace 2 h'}));
        }),
      );
      expect((await service.programs(_channel)).single.videoId, 'aaaaaaaaaaa');
    });

    test('caché de 2 minutos por canal; force la ignora', () async {
      var calls = 0;
      var now = DateTime(2026, 11, 11, 10);
      final service = YoutubeChannelService(
        clock: () => now,
        client: MockClient((r) async {
          calls++;
          return _html(_page({'aaaaaaaaaaa': 'hace 2 h'}));
        }),
      );

      await service.programs(_channel);
      expect(calls, 2);
      now = now.add(const Duration(minutes: 1));
      await service.programs(_channel);
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
      final service = YoutubeChannelService(
          client: MockClient((r) async => fail
              ? http.Response('no', 500)
              : _html(_page({'aaaaaaaaaaa': 'hace 2 h'}))));
      await expectLater(service.programs(_channel),
          throwsA(isA<YoutubeUnavailableException>()));
      fail = false;
      expect((await service.programs(_channel)).single.videoId, 'aaaaaaaaaaa');
    });
  });
}
