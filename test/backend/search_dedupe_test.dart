import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

/// Un mismo stream en dos listas (p. ej. «IPTV Español» y «Pluto TV»).
void main() {
  late Directory dir;

  Future<void> add(int source, String name, String group, String url,
      {bool favorite = false, int? watched}) async {
    final db = await DbFactory.db;
    await db.execute('''
      INSERT INTO channels (name, group_name, url, media_type, source_id, favorite, last_watched)
      VALUES (?, ?, ?, ?, ?, ?, ?)''', [
      name,
      group,
      url,
      MediaType.livestream.index,
      source,
      favorite ? 1 : 0,
      watched,
    ]);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_dedupe');
    DbFactory.debugPath = '${dir.path}/db.sqlite';
    await DbFactory.debugReset();
    final db = await DbFactory.db;
    await db.execute(
        "INSERT INTO sources (id, name, source_type, enabled) VALUES (1, 'IPTV', 0, 1)");
    await db.execute(
        "INSERT INTO sources (id, name, source_type, enabled) VALUES (2, 'Pluto', 0, 1)");
    await add(1, 'Bob Esponja (720p)', 'Animation', 'http://p/bob');
    await add(1, 'DW Español', 'News', 'http://dw');
    await add(1, 'Repetido A', 'News', 'http://same');
    await add(1, 'Repetido B', 'News', 'http://same');
    await add(2, 'Bob Esponja Pantalones Cuadrados', 'Kids', 'http://p/bob');
    await add(2, 'Pokémon', 'Anime', 'http://p/pokemon');
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  Filters f(List<int> sources,
          {String? query, String? group, ViewType view = ViewType.all}) =>
      Filters(
        viewType: view,
        sourceIds: sources,
        mediaTypes: [MediaType.livestream],
        query: query,
        groupName: group,
      );

  Future<List<String>> names(Filters filters) async =>
      (await Sql.search(filters)).map((c) => c.name).toList();

  test('con las dos listas el stream repetido sale una sola vez', () async {
    expect(await names(f([1, 2])), [
      'Bob Esponja (720p)',
      'DW Español',
      'Repetido A',
      'Repetido B',
      'Pokémon',
    ]);
    expect(await names(f([1, 2], query: 'bob')), ['Bob Esponja (720p)']);
  });

  test('cada lista por separado conserva su copia', () async {
    expect(await names(f([1])), contains('Bob Esponja (720p)'));
    expect(await names(f([2])),
        ['Bob Esponja Pantalones Cuadrados', 'Pokémon']);
  });

  test('cada grupo conserva su copia', () async {
    expect(await names(f([1, 2], group: 'Animation')), ['Bob Esponja (720p)']);
    expect(await names(f([1, 2], group: 'Kids')),
        ['Bob Esponja Pantalones Cuadrados']);
  });

  test('la búsqueda encuentra la copia que coincide con el texto', () async {
    expect(await names(f([1, 2], query: 'pantalones')),
        ['Bob Esponja Pantalones Cuadrados']);
  });

  test('gana la copia favorita', () async {
    final db = await DbFactory.db;
    await db.execute(
        "UPDATE channels SET favorite = 1 WHERE name LIKE '%Pantalones%'");
    expect(await names(f([1, 2], query: 'bob')),
        ['Bob Esponja Pantalones Cuadrados']);
    expect(await names(f([1, 2], view: ViewType.favorites)),
        ['Bob Esponja Pantalones Cuadrados']);
  });

  test('el historial sigue ordenado por lo último visto', () async {
    final db = await DbFactory.db;
    await db.execute(
        "UPDATE channels SET last_watched = 10 WHERE name = 'DW Español'");
    await db.execute(
        "UPDATE channels SET last_watched = 20 WHERE name LIKE '%Pantalones%'");
    await db.execute(
        "UPDATE channels SET last_watched = 30 WHERE name = 'Pokémon'");
    expect(await names(f([1, 2], view: ViewType.history)),
        ['Pokémon', 'Bob Esponja Pantalones Cuadrados', 'DW Español']);
  });
}
