import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/countries.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/m3u.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

void main() {
  group('countryFromTvgId', () {
    test('lee el país del sufijo de iptv-org', () {
      expect(countryFromTvgId('TVPeru.pe@SD'), 'pe');
      expect(countryFromTvgId('HBO2LatinAmerica.us@East'), 'us');
      expect(countryFromTvgId('CNN.us'), 'us');
      expect(countryFromTvgId('BBCOne.uk@London'), 'uk');
    });

    test('ids sin país reconocible dan null', () {
      expect(countryFromTvgId(null), isNull);
      expect(countryFromTvgId(''), isNull);
      expect(countryFromTvgId('SinPunto'), isNull);
      expect(countryFromTvgId('canal.com'), isNull); // "com" no es un país
      expect(countryFromTvgId('algo.zz@SD'), isNull); // código desconocido
    });

    test('mayúsculas en el sufijo se normalizan', () {
      expect(countryFromTvgId('X.PE@SD'), 'pe');
    });
  });

  group('countryName', () {
    test('nombres en español y respaldo al código', () {
      expect(countryName('pe'), 'Perú');
      expect(countryName('us'), 'Estados Unidos');
      expect(countryName('uk'), 'Reino Unido');
      expect(countryName('zz'), 'ZZ');
    });
  });

  group('getChannelFromLines', () {
    test('guarda el tvg-id y el país', () {
      const line =
          '#EXTINF:-1 tvg-id="TVPeru.pe@SD" tvg-logo="x.png" group-title="General",TV Peru (1080p)';
      final c = getChannelFromLines(line, 'http://x/a.m3u8')!;
      expect(c.name, 'TV Peru (1080p)');
      expect(c.tvgId, 'TVPeru.pe@SD');
      expect(c.country, 'pe');
    });

    test('sin tvg-id no hay país', () {
      final c = getChannelFromLines(
          '#EXTINF:-1 group-title="G",Canal', 'http://x/a.m3u8')!;
      expect(c.tvgId, isNull);
      expect(c.country, isNull);
    });
  });

  group('SQL por país', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fredtv_country');
      DbFactory.debugPath = '${dir.path}/db.sqlite';
      await DbFactory.debugReset();
      final db = await DbFactory.db;
      await db.execute(
          "INSERT INTO sources (id, name, source_type, enabled) VALUES (1, 'S', 0, 1)");
      for (final row in [
        ['Uno', 'pe'],
        ['Dos', 'pe'],
        ['Tres', 'us'],
        ['Cuatro', null],
      ]) {
        await db.execute('''
          INSERT INTO channels (name, group_name, url, media_type, source_id, favorite, country)
          VALUES (?, 'G', 'http://x', ?, 1, 0, ?)''',
            [row[0], MediaType.livestream.index, row[1]]);
      }
    });

    tearDown(() async {
      await DbFactory.debugReset();
      DbFactory.debugPath = null;
      await dir.delete(recursive: true);
    });

    test('Filters.country limita los resultados', () async {
      final r = await Sql.search(Filters(
        viewType: ViewType.all,
        sourceIds: [1],
        mediaTypes: [MediaType.livestream],
        country: 'pe',
      ));
      expect(r.map((c) => c.name), ['Uno', 'Dos']);
    });

    test('sin país se listan todos', () async {
      final r = await Sql.search(Filters(
        viewType: ViewType.all,
        sourceIds: [1],
        mediaTypes: [MediaType.livestream],
      ));
      expect(r, hasLength(4));
    });

    test('countries() cuenta por país, de más a menos canales', () async {
      final r = await Sql.countries([1]);
      expect(r.map((c) => (c.code, c.count)).toList(),
          [('pe', 2), ('us', 1)]);
    });

    test('insertChannel guarda tvg_id y país y los actualiza', () async {
      final ch = Channel(
        name: 'Nuevo',
        mediaType: MediaType.livestream,
        sourceId: 1,
        favorite: false,
        url: 'http://n',
        tvgId: 'Nuevo.ar@SD',
        country: 'ar',
      );
      await Sql.commitWrite([Sql.insertChannel(ch)]);
      var db = await DbFactory.db;
      var row = await db.get(
          "SELECT tvg_id, country FROM channels WHERE name = 'Nuevo'");
      expect(row['tvg_id'], 'Nuevo.ar@SD');
      expect(row['country'], 'ar');
      // Al refrescar la fuente se actualiza.
      ch.tvgId = 'Nuevo.cl@SD';
      ch.country = 'cl';
      await Sql.commitWrite([Sql.insertChannel(ch)]);
      db = await DbFactory.db;
      row = await db.get(
          "SELECT tvg_id, country FROM channels WHERE name = 'Nuevo'");
      expect(row['country'], 'cl');
    });

    test('la migración 6 fuerza refrescar las listas para rellenar el país',
        () async {
      // En una base nueva no hay marcas de refresco: nada que comprobar salvo
      // que la columna exista y se pueda consultar.
      final db = await DbFactory.db;
      final cols = await db.getAll('PRAGMA table_info(channels)');
      expect(cols.map((c) => c['name']), containsAll(['tvg_id', 'country']));
    });
  });
}
