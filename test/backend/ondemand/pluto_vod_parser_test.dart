import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/pluto_vod_parser.dart';

Map<String, Object?> movie(String id, String name, {Map<String, Object?>? extra}) =>
    {'_id': id, 'name': name, 'type': 'movie', ...?extra};

String catalog(List<Map<String, Object?>> categories) => jsonEncode({
      'categories': [
        for (final c in categories)
          {'_id': 'c-${c['name']}', 'name': c['name'], 'items': c['items']},
      ],
    });

void main() {
  test('solo películas: descarta las series', () {
    final t = parsePlutoVodCatalog(catalog([
      {
        'name': 'Acción',
        'items': [
          movie('a1', 'Peli'),
          {'_id': 's1', 'name': 'Serie', 'type': 'series'},
        ],
      },
    ]));
    expect(t.map((e) => e.id), ['a1']);
  });

  test('misma película en varias categorías: una vez con todas', () {
    final t = parsePlutoVodCatalog(catalog([
      {'name': 'Acción', 'items': [movie('a1', 'Peli')]},
      {'name': 'Drama', 'items': [movie('a1', 'Peli'), movie('b2', 'Otra')]},
    ]));
    expect(t.map((e) => e.id), ['a1', 'b2']);
    expect(t.first.categories, ['Acción', 'Drama']);
    expect(t.last.categories, ['Drama']);
  });

  test('campos: sinopsis, cartel vertical, ficha y origen', () {
    final t = parsePlutoVodCatalog(catalog([
      {
        'name': 'Acción',
        'items': [
          movie('a1', 'El último héroe', extra: {
            'summary': 'Resumen',
            'description': 'Descripción larga',
            'genre': 'Action & Adventure',
            'rating': 'R',
            'originalContentDuration': '7245000',
            'covers': [
              {'aspectRatio': '4:3', 'url': 'a'},
              {'aspectRatio': '347:500', 'url': 'b'},
            ],
          }),
        ],
      },
    ]));
    final m = t.single;
    expect(m.title, 'El último héroe');
    expect(m.synopsis, 'Resumen');
    expect(m.posterUrl, 'b');
    expect(m.details, 'Action & Adventure · R · 121 min.');
    expect((m.source as PlutoSource).videoId, 'a1');
  });

  test('sin summary usa description; sin vertical usa la primera cover; '
      'sin covers usa featuredImage; sin nada, vacío', () {
    final t = parsePlutoVodCatalog(catalog([
      {
        'name': 'X',
        'items': [
          movie('1', 'A', extra: {
            'description': 'D',
            'covers': [
              {'aspectRatio': '4:3', 'url': 'u43'}
            ],
          }),
          movie('2', 'B', extra: {
            'featuredImage': {'path': 'feat'}
          }),
          movie('3', 'C'),
        ],
      },
    ]));
    expect(t[0].synopsis, 'D');
    expect(t[0].posterUrl, 'u43');
    expect(t[1].posterUrl, 'feat');
    expect(t[2].posterUrl, '');
    expect(t[2].synopsis, '');
  });

  test('ítems incompletos: sin _id o sin nombre se descartan; sin duración '
      'la ficha omite los minutos', () {
    final t = parsePlutoVodCatalog(catalog([
      {
        'name': 'X',
        'items': [
          {'name': 'Sin id', 'type': 'movie'},
          {'_id': 'n1', 'type': 'movie'},
          movie('ok', 'Con nombre', extra: {'genre': 'Drama'}),
        ],
      },
    ]));
    expect(t.map((e) => e.id), ['ok']);
    expect(t.single.details, 'Drama');
  });

  test('JSON inválido, sin categories o sin ninguna película → '
      'OnDemandUnavailableException', () {
    for (final bad in [
      'no es json',
      '{}',
      '{"categories": "x"}',
      catalog([
        {'name': 'X', 'items': <Object?>[]},
      ]),
      catalog([
        {
          'name': 'X',
          'items': [
            {'_id': 's', 'name': 'S', 'type': 'series'}
          ],
        },
      ]),
    ]) {
      expect(() => parsePlutoVodCatalog(bad),
          throwsA(isA<OnDemandUnavailableException>()),
          reason: bad);
    }
  });

  test('la duración puede venir como número o como texto', () {
    final t = parsePlutoVodCatalog(catalog([
      {
        'name': 'X',
        'items': [
          movie('n', 'Numérica', extra: {'originalContentDuration': 7245000}),
          movie('t', 'Texto', extra: {'originalContentDuration': '3600000'}),
          movie('z', 'Cero', extra: {'originalContentDuration': 0}),
        ],
      },
    ]));
    expect(t[0].details, '121 min.');
    expect(t[1].details, '60 min.');
    expect(t[2].details, '');
  });
}
