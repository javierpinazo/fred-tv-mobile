import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/archive_vod_parser.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

String search(List<Map<String, Object?>> docs) => jsonEncode({
      'response': {'numFound': docs.length, 'docs': docs}
    });

Map<String, Object?> doc(String id, String title, {Map<String, Object?>? extra}) =>
    {'identifier': id, 'title': title, ...?extra};

void main() {
  test('campos: título, cartel, origen, década y ficha', () {
    final t = parseArchiveSearch(search([
      doc('carne-1968', 'Carne',
          extra: {'year': '1968', 'description': 'Una película argentina.'}),
    ]));
    final m = t.single;
    expect(m.id, 'carne-1968');
    expect(m.title, 'Carne');
    expect(m.posterUrl, 'https://archive.org/services/img/carne-1968');
    expect((m.source as ArchiveSource).videoId, 'carne-1968');
    expect(m.categories, ['1960s']);
    expect(m.details, '1968');
    expect(m.synopsis, 'Una película argentina.');
  });

  test('año ausente o inválido → «Sin fecha»; puede ser número, texto o lista',
      () {
    final t = parseArchiveSearch(search([
      doc('a', 'A'),
      doc('b', 'B', extra: {'year': 'sin año'}),
      doc('c', 'C', extra: {'year': 1975}),
      doc('d', 'D', extra: {'year': ['1983']}),
    ]));
    expect(t[0].categories, ['Sin fecha']);
    expect(t[0].details, '');
    expect(t[1].categories, ['Sin fecha']);
    expect(t[2].categories, ['1970s']);
    expect(t[3].categories, ['1980s']);
  });

  test('descripción: sin HTML, espacios colapsados, recortada a 400; lista ok',
      () {
    final long = 'palabra ' * 100;
    final t = parseArchiveSearch(search([
      doc('a', 'A', extra: {
        'description': 'Hola<br/>  <b>mundo</b>\n\n  fin'
      }),
      doc('b', 'B', extra: {'description': long}),
      doc('c', 'C', extra: {
        'description': ['Primera', 'Segunda']
      }),
      doc('d', 'D'),
    ]));
    expect(t[0].synopsis, 'Hola mundo fin');
    expect(t[1].synopsis.length, lessThanOrEqualTo(401));
    expect(t[1].synopsis.endsWith('…'), isTrue);
    expect(t[2].synopsis, 'Primera');
    expect(t[3].synopsis, '');
  });

  test('título como lista usa el primero; sin identifier o sin título se '
      'descartan', () {
    final t = parseArchiveSearch(search([
      {
        'identifier': 'x',
        'title': ['Primero', 'Segundo']
      },
      {'title': 'Sin id'},
      {'identifier': 'sin-titulo'},
    ]));
    expect(t.map((e) => e.title), ['Primero']);
  });

  group('isAdultText', () {
    test('detecta contenido para adultos', () {
      for (final s in [
        'XXX',
        'Película erótica',
        'cine erotico de los 70',
        'sexploitation',
        'explotación sexual',
        'Explotacion sexual',
        'porn',
        'hardcore',
        '18+',
        'NSFW',
        'adult film',
        'Adult movies only',
        'Young Casanova, Sexuellement Vôtre',
        'Sexy Cat',
        'sexo en la ciudad',
        'una historia sexual',
        'Nude Descending',
        'Desnuda en la playa',
        'Naked City',
        'Striptease',
        'Una película para adultos',
        'cine para adultos',
        'Solo para adultos',
        'pornografía de los 70',
        'película pornográfica',
        'pornographic film',
        'Erotismo y deseo',
        'softcore',
        'Playboy: la película',
      ]) {
        expect(isAdultText(s), isTrue, reason: s);
      }
    });

    test('no descarta títulos legítimos', () {
      for (final s in [
        'Los adultos y el cine',
        'Un adulto mayor',
        'Romeo y Julieta',
        'La noche del terror',
        'Sexto sentido',
        'Año +1800',
        'Los adultos de la familia',
        'Essex 1950',
        'Un hombre desnudo de miedo'.replaceAll('desnudo', 'valiente'),
        '',
      ]) {
        expect(isAdultText(s), isFalse, reason: s);
      }
    });
  });

  test('el filtro de adultos se aplica a título, descripción y subject', () {
    final t = parseArchiveSearch(search([
      doc('ok', 'Película normal'),
      doc('t', 'Porn de los 70'),
      doc('d', 'Normal', extra: {'description': 'Una cinta erótica.'}),
      doc('s', 'Otra', extra: {
        'subject': ['drama', 'Erotica']
      }),
    ]));
    expect(t.map((e) => e.id), ['ok']);
  });

  test('archiveDecade', () {
    expect(archiveDecade(1968), '1960s');
    expect(archiveDecade(2003), '2000s');
    expect(archiveDecade(null), 'Sin fecha');
    expect(archiveDecade(1800), 'Sin fecha');
    expect(archiveDecade(2100), 'Sin fecha');
  });

  test('JSON inválido, sin response.docs o sin títulos válidos → '
      'OnDemandUnavailableException', () {
    for (final bad in [
      'no es json',
      '{}',
      '{"response": {"docs": "x"}}',
      search([]),
      search([
        {'title': 'Sin id'}
      ]),
      search([doc('p', 'porn')]),
    ]) {
      expect(() => parseArchiveSearch(bad),
          throwsA(isA<OnDemandUnavailableException>()),
          reason: bad);
    }
  });
}
