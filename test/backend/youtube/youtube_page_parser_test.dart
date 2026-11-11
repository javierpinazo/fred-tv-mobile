import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/youtube/youtube_page_parser.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';

const _default = 'THUMBNAIL_OVERLAY_BADGE_STYLE_DEFAULT';
const _liveStyle = 'THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE';

/// Un elemento con la forma real de la página (noviembre de 2026).
Map<String, dynamic> _lockup(
  String? id,
  String? title, {
  String? badge,
  String style = _default,
  List<String> parts = const [],
}) =>
    {
      if (id != null) 'contentId': id,
      'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
      'contentImage': {
        'thumbnailViewModel': {
          'overlays': [
            if (badge != null)
              {
                'thumbnailBottomOverlayViewModel': {
                  'badges': [
                    {
                      'thumbnailBadgeViewModel': {
                        'text': badge,
                        'badgeStyle': style,
                      }
                    }
                  ]
                }
              }
          ]
        }
      },
      'metadata': {
        'lockupMetadataViewModel': {
          if (title != null) 'title': {'content': title},
          'metadata': {
            'contentMetadataViewModel': {
              'metadataRows': [
                {
                  'metadataParts': [
                    for (final p in parts)
                      {
                        'text': {'content': p}
                      }
                  ]
                }
              ]
            }
          }
        }
      }
    };

String _page(List<Map<String, dynamic>> lockups) {
  final data = {
    'contents': {
      'twoColumnBrowseResultsRenderer': {
        'tabs': [
          {
            'tabRenderer': {
              'content': {
                'richGridRenderer': {
                  'contents': [
                    for (final l in lockups)
                      {
                        'richItemRenderer': {
                          'content': {'lockupViewModel': l}
                        }
                      }
                  ]
                }
              }
            }
          }
        ]
      }
    }
  };
  return '<html><body><script nonce="x">var ytInitialData = '
      '${jsonEncode(data)};</script><script>var other = {};</script>'
      '</body></html>';
}

void main() {
  test('vídeo normal', () {
    final p = parseYoutubeTab(_page([
      _lockup('Ejg0OQPYVgw', 'URGENTE: paro',
          badge: '22:45', parts: ['135 k', 'hace 16 h'])
    ])).single;
    expect(p.videoId, 'Ejg0OQPYVgw');
    expect(p.title, 'URGENTE: paro');
    expect(p.kind, YoutubeProgramKind.video);
    expect(p.duration, '22:45');
    expect(p.age, const Duration(hours: 16));
    expect(p.thumbnail, 'https://i.ytimg.com/vi/Ejg0OQPYVgw/mqdefault.jpg');
  });

  test('directo ya emitido', () {
    final p = parseYoutubeTab(_page([
      _lockup('x_dpH2SwLLY', 'Centrífugos',
          badge: '1:03:41', parts: ['4 K', 'Transmitido hace 7 h'])
    ])).single;
    expect(p.kind, YoutubeProgramKind.video);
    expect(p.duration, '1:03:41');
    expect(p.age, const Duration(hours: 7));
  });

  test('directo en curso', () {
    final p = parseYoutubeTab(_page([
      _lockup('yZh3xsFqCt8', 'DW en vivo',
          badge: 'EN VIVO', style: _liveStyle, parts: ['373 lo están viendo'])
    ])).single;
    expect(p.kind, YoutubeProgramKind.live);
    expect(p.duration, isNull);
    expect(p.age, isNull);
  });

  test('programado se descarta', () {
    expect(
        parseYoutubeTab(_page([
          _lockup('nIBahykjMB8', 'FUERTE Y CLARO',
              badge: 'Próximamente',
              parts: ['1 en espera', 'Programado para el 11/11/26, 9:30']),
          _lockup('nIBahykjMB9', 'Upcoming en inglés',
              badge: 'Upcoming', parts: ['Scheduled for 11/11/26, 9:30 AM']),
          _lockup('nIBahykjMB0', 'Sin insignia', parts: ['hace 1 día']),
        ])),
        isEmpty);
  });

  test('conserva el orden de la página y descarta elementos rotos', () {
    final list = parseYoutubeTab(_page([
      _lockup('aaaaaaaaaaa', 'Uno', badge: '1:00', parts: ['hace 1 día']),
      _lockup(null, 'Sin id', badge: '1:00', parts: ['hace 1 día']),
      _lockup('corto', 'Id inválido', badge: '1:00', parts: ['hace 1 día']),
      _lockup('ccccccccccc', null, badge: '1:00', parts: ['hace 1 día']),
      _lockup('ddddddddddd', 'Cuatro', badge: '2:00', parts: ['hace 2 días']),
    ]));
    expect(list.map((p) => p.videoId), ['aaaaaaaaaaa', 'ddddddddddd']);
  });

  test('un vídeo con duración pero sin fecha reconocible sigue saliendo', () {
    final p = parseYoutubeTab(_page([
      _lockup('aaaaaaaaaaa', 'Raro', badge: '3:15', parts: ['12 vistas'])
    ])).single;
    expect(p.kind, YoutubeProgramKind.video);
    expect(p.duration, '3:15');
    expect(p.age, isNull);
  });

  test('canal vacío', () => expect(parseYoutubeTab(_page([])), isEmpty));

  test('sin ytInitialData lanza', () {
    expect(() => parseYoutubeTab('<html>Before you continue</html>'),
        throwsA(isA<YoutubeParseException>()));
    expect(() => parseYoutubeTab('<script>var ytInitialData = {"a": ;</script>'),
        throwsA(isA<YoutubeParseException>()));
    expect(() => parseYoutubeTab('<script>var ytInitialData = [1,2];</script>'),
        throwsA(isA<YoutubeParseException>()));
  });

  test('antigüedades en español (formato real)', () {
    expect(parseYoutubeAge('hace 30 s'), const Duration(seconds: 30));
    expect(parseYoutubeAge('hace 5 min'), const Duration(minutes: 5));
    expect(parseYoutubeAge('hace 16 h'), const Duration(hours: 16));
    expect(parseYoutubeAge('hace 1 día'), const Duration(days: 1));
    expect(parseYoutubeAge('hace 4 días'), const Duration(days: 4));
    expect(parseYoutubeAge('hace 2 sem.'), const Duration(days: 14));
    expect(parseYoutubeAge('hace 3 m'), const Duration(days: 90));
    expect(parseYoutubeAge('Transmitido hace 1 a'), const Duration(days: 365));
    expect(parseYoutubeAge('Transmitido hace 7 h'), const Duration(hours: 7));
  });

  test('antigüedades en español con palabras completas', () {
    expect(parseYoutubeAge('hace 5 minutos'), const Duration(minutes: 5));
    expect(parseYoutubeAge('hace 2 horas'), const Duration(hours: 2));
    expect(parseYoutubeAge('hace 3 semanas'), const Duration(days: 21));
    expect(parseYoutubeAge('hace 1 mes'), const Duration(days: 30));
    expect(parseYoutubeAge('hace 2 meses'), const Duration(days: 60));
    expect(parseYoutubeAge('hace 2 años'), const Duration(days: 730));
  });

  test('antigüedades en inglés, por si YouTube responde en ese idioma', () {
    expect(parseYoutubeAge('5m ago'), const Duration(minutes: 5));
    expect(parseYoutubeAge('16h ago'), const Duration(hours: 16));
    expect(parseYoutubeAge('2w ago'), const Duration(days: 14));
    expect(parseYoutubeAge('1mo ago'), const Duration(days: 30));
    expect(parseYoutubeAge('Streamed 1y ago'), const Duration(days: 365));
    expect(parseYoutubeAge('Streamed 3 weeks ago'), const Duration(days: 21));
  });

  test('lo que no es una antigüedad', () {
    expect(parseYoutubeAge('133 k'), isNull);
    expect(parseYoutubeAge('373 lo están viendo'), isNull);
    expect(parseYoutubeAge('Programado para el 11/11/26, 9:30'), isNull);
    expect(parseYoutubeAge(''), isNull);
  });

  test('lee las listas del canal y salta lo que no es lista', () {
    Map<String, dynamic> item(String id, String? title, {String? type}) => {
          'contentId': id,
          if (type != null) 'contentType': type,
          'metadata': {
            if (title != null)
              'lockupMetadataViewModel': {
                'title': {'content': title}
              }
          },
        };
    final html = _page([
      item('PL4_L4CSNdHPUIm8ajOHFvHniKhc8Z26hY', '#LaEncerrona',
          type: 'LOCKUP_CONTENT_TYPE_PODCAST'),
      item('PLb7sHDpNJW0s', ' ESPECIALES CANAL YA '),
      item('aaaaaaaaaaa', 'un vídeo'),
      item('PLsinTitulo99', null),
      item('PLb7sHDpNJW0s', 'repetida'),
    ]);
    expect(parseYoutubePlaylists(html), [
      (id: 'PL4_L4CSNdHPUIm8ajOHFvHniKhc8Z26hY', title: '#LaEncerrona'),
      (id: 'PLb7sHDpNJW0s', title: 'ESPECIALES CANAL YA'),
    ]);
    expect(() => parseYoutubePlaylists('<html></html>'),
        throwsA(isA<YoutubeParseException>()));
  });
}
