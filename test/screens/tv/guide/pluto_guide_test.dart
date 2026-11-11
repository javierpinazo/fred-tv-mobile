import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/guide/pluto_guide.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';

const _id = '5dcb62e63d4d8f0009f36881';

// Recorte de https://api.pluto.tv/v2/channels/<id>?start=…&stop=… (desordenado
// a propósito: la guía debe ordenarlo).
const _json = '''
{
  "_id": "$_id",
  "name": "Pluto TV Cine Acción",
  "timelines": [
    {
      "start": "2026-10-19T20:08:00.000Z",
      "stop": "2026-10-19T20:38:00.000Z",
      "title": "Las Rutas de Veronica",
      "episode": {
        "number": 13,
        "season": 2,
        "description": "Verónica recorre Asturias.",
        "genre": "Food & Cooking",
        "rating": "TV-G",
        "name": "Comarca Vaqueira",
        "clip": {"originalReleaseDate": "2018-01-01T00:00:00.000Z"},
        "series": {"type": "tv", "name": "Las Rutas de Veronica"}
      }
    },
    {
      "start": "2026-10-19T18:17:00.000Z",
      "stop": "2026-10-19T20:08:00.000Z",
      "title": "Wasabi",
      "episode": {
        "number": 1,
        "season": 1,
        "description": "Un inspector francés viaja a Japón.",
        "genre": "Action & Adventure",
        "rating": "R",
        "name": "Wasabi",
        "clip": {
          "directors": ["Gérard Krawczyk"],
          "actors": ["Jean Reno", "Ryôko Hirosue"],
          "originalReleaseDate": "2001-01-01T00:00:00.000Z"
        },
        "poster": {"path": "https://images.pluto.tv/episodes/x/poster.jpg"},
        "series": {"type": "film", "name": "Wasabi"}
      }
    },
    {
      "start": "2026-10-19T20:38:00.000Z",
      "stop": "2026-10-19T21:00:00.000Z",
      "title": "Conciertos por Stingray",
      "episode": {
        "number": 1268,
        "season": 1,
        "description": "",
        "genre": "Music",
        "rating": "Not Rated",
        "name": "Conciertos por Stingray",
        "clip": {"originalReleaseDate": "1970-01-01T00:00:00.000Z"},
        "series": {"type": "music-video"}
      }
    },
    {"start": "roto", "title": "Sin hora"}
  ]
}
''';

Channel _ch(String? url, {String name = 'Pluto TV Cine Acción'}) => Channel(
    name: name,
    url: url,
    mediaType: MediaType.livestream,
    sourceId: 1,
    favorite: false);

void main() {
  group('plutoChannelId', () {
    test('saca el id del redirector jmp2.uk', () {
      expect(plutoChannelId('https://jmp2.uk/plu-$_id.m3u8'), _id);
    });

    test('saca el id de una dirección directa de Pluto TV', () {
      expect(
          plutoChannelId(
              'https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/$_id/master.m3u8?sid=1'),
          _id);
    });

    test('otras direcciones no son de Pluto TV', () {
      expect(plutoChannelId('https://example.com/plu-$_id.m3u8'), isNull);
      expect(plutoChannelId('https://jmp2.uk/sam-abc.m3u8'), isNull);
      expect(plutoChannelId(null), isNull);
    });
  });

  group('parsePlutoTimelines', () {
    final programs = parsePlutoTimelines(_json);

    test('ordena por hora y descarta las entradas rotas', () {
      expect(programs.map((p) => p.title),
          ['Wasabi', 'Las Rutas de Veronica', 'Conciertos por Stingray']);
      expect(programs.first.start, DateTime.utc(2026, 10, 19, 18, 17));
      expect(programs.first.end, DateTime.utc(2026, 10, 19, 20, 8));
    });

    test('una película trae año, género, clasificación, reparto y póster', () {
      final p = programs[0];
      expect(p.kind, GuideProgramKind.movie);
      expect(p.description, 'Un inspector francés viaja a Japón.');
      expect(p.year, 2001);
      expect(p.genre, 'Action & Adventure');
      expect(p.rating, 'R');
      expect(p.directors, ['Gérard Krawczyk']);
      expect(p.actors, ['Jean Reno', 'Ryôko Hirosue']);
      expect(p.poster, 'https://images.pluto.tv/episodes/x/poster.jpg');
      // "Temporada 1, capítulo 1" es relleno en las películas.
      expect(p.season, isNull);
      expect(p.episode, isNull);
      expect(p.episodeTitle, isNull);
    });

    test('una serie trae temporada, capítulo y título del capítulo', () {
      final p = programs[1];
      expect(p.kind, GuideProgramKind.series);
      expect(p.season, 2);
      expect(p.episode, 13);
      expect(p.episodeTitle, 'Comarca Vaqueira');
      expect(p.year, 2018);
    });

    test('lo que no es película ni serie no inventa datos', () {
      final p = programs[2];
      expect(p.kind, isNull);
      expect(p.season, isNull);
      expect(p.episode, isNull);
      expect(p.year, isNull); // 1970 es "sin fecha"
      expect(p.rating, isNull); // "Not Rated"
      expect(p.description, isNull);
    });

    test('una respuesta inesperada lanza FormatException', () {
      expect(() => parsePlutoTimelines('[]'), throwsFormatException);
    });
  });

  group('PlutoGuide', () {
    test('reconoce los canales por su dirección, no por el nombre', () {
      final g = PlutoGuide(client: MockClient((_) async => http.Response('', 500)));
      expect(g.matches(_ch('https://jmp2.uk/plu-$_id.m3u8', name: 'Otro nombre')),
          isTrue);
      expect(g.matches(_ch('https://example.com/a.m3u8')), isFalse);
    });

    test('pide el día de Lima del canal y devuelve sus programas', () async {
      late Uri asked;
      final g = PlutoGuide(client: MockClient((req) async {
        asked = req.url;
        return http.Response(_json, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final day = await g.day(
          _ch('https://jmp2.uk/plu-$_id.m3u8'), DateTime(2026, 10, 19));
      expect(asked.host, 'api.pluto.tv');
      expect(asked.path, '/v2/channels/$_id');
      // 19-oct en Lima = 05:00 UTC del 19 hasta 05:00 UTC del 20.
      expect(asked.queryParameters['start'], '2026-10-19T05:00:00.000Z');
      expect(asked.queryParameters['stop'], '2026-10-20T05:00:00.000Z');
      expect(day.map((p) => p.title),
          ['Wasabi', 'Las Rutas de Veronica', 'Conciertos por Stingray']);
    });

    test('no vuelve a pedir el mismo día mientras la caché es reciente',
        () async {
      var calls = 0;
      final g = PlutoGuide(client: MockClient((_) async {
        calls++;
        return http.Response(_json, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final ch = _ch('https://jmp2.uk/plu-$_id.m3u8');
      await g.day(ch, DateTime(2026, 10, 19));
      await g.day(ch, DateTime(2026, 10, 19));
      expect(calls, 1);
      await g.day(ch, DateTime(2026, 10, 20));
      expect(calls, 2);
    });

    test('un error del servidor lanza GuideException', () async {
      final g = PlutoGuide(client: MockClient((_) async => http.Response('no', 500)));
      expect(g.day(_ch('https://jmp2.uk/plu-$_id.m3u8'), DateTime(2026, 10, 19)),
          throwsA(isA<GuideException>()));
    });
  });
}
