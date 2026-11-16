import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/plex_vod_parser.dart';

String hub(List<Map<String, Object?>> items) => jsonEncode({
      'MediaContainer': {'size': items.length, 'Metadata': items}
    });

Map<String, Object?> movie(String key, String title,
        {Map<String, Object?>? extra}) =>
    {'ratingKey': key, 'title': title, 'type': 'movie', ...?extra};

void main() {
  test('solo películas: descarta las series', () {
    final t = parsePlexHubs([
      (
        title: 'En Español',
        json: hub([
          movie('a', 'Peli'),
          {'ratingKey': 's', 'title': 'Serie', 'type': 'show'},
        ])
      ),
    ]);
    expect(t.map((e) => e.id), ['a']);
  });

  test('misma película en varios estantes: una vez con todos, en orden', () {
    final t = parsePlexHubs([
      (title: 'Terror', json: hub([movie('a', 'Peli')])),
      (title: 'Clásicos', json: hub([movie('a', 'Peli'), movie('b', 'Otra')])),
    ]);
    expect(t.map((e) => e.id), ['a', 'b']);
    expect(t.first.categories, ['Terror', 'Clásicos']);
    expect(t.last.categories, ['Clásicos']);
  });

  test('campos: sinopsis, cartel, ficha y origen', () {
    final t = parsePlexHubs([
      (
        title: 'X',
        json: hub([
          movie('rk1', 'Vulnerables', extra: {
            'summary': 'Resumen',
            'thumb': 'https://img/thumb.jpg',
            'art': 'https://img/art.jpg',
            'year': 2012,
            'contentRating': 'PG-13',
            'duration': 4902375,
          }),
        ])
      ),
    ]);
    final m = t.single;
    expect(m.title, 'Vulnerables');
    expect(m.synopsis, 'Resumen');
    expect(m.posterUrl, 'https://img/thumb.jpg');
    expect(m.details, '2012 · PG-13 · 82 min.');
    expect((m.source as PlexSource).videoId, 'rk1');
  });

  test('cartel: sin thumb usa art; sin nada, vacío. Ficha omite lo ausente',
      () {
    final t = parsePlexHubs([
      (
        title: 'X',
        json: hub([
          movie('1', 'A', extra: {'art': 'https://img/art.jpg'}),
          movie('2', 'B'),
          movie('3', 'C', extra: {'year': '1999', 'duration': '3600000'}),
        ])
      ),
    ]);
    expect(t[0].posterUrl, 'https://img/art.jpg');
    expect(t[1].posterUrl, '');
    expect(t[1].details, '');
    expect(t[1].synopsis, '');
    expect(t[2].details, '1999 · 60 min.');
  });

  test('incompletos: sin ratingKey o sin título se descartan', () {
    final t = parsePlexHubs([
      (
        title: 'X',
        json: hub([
          {'title': 'Sin clave', 'type': 'movie'},
          {'ratingKey': 'k', 'type': 'movie'},
          movie('ok', 'Con todo'),
        ])
      ),
    ]);
    expect(t.map((e) => e.id), ['ok']);
  });

  test('estante sin películas no aporta categoría; uno ilegible se ignora', () {
    final t = parsePlexHubs([
      (
        title: 'Solo series',
        json: hub([
          {'ratingKey': 's', 'title': 'S', 'type': 'show'}
        ])
      ),
      (title: 'Roto', json: 'no es json'),
      (title: 'Buenas', json: hub([movie('a', 'Peli')])),
    ]);
    expect(t.single.categories, ['Buenas']);
  });

  test('todos los estantes inválidos o sin películas → '
      'OnDemandUnavailableException', () {
    for (final bad in [
      <({String title, String json})>[],
      [(title: 'A', json: 'no json')],
      [(title: 'A', json: '{}')],
      [(title: 'A', json: hub([]))],
      [
        (
          title: 'A',
          json: hub([
            {'ratingKey': 's', 'title': 'S', 'type': 'show'}
          ])
        )
      ],
    ]) {
      expect(() => parsePlexHubs(bad),
          throwsA(isA<OnDemandUnavailableException>()));
    }
  });
}
