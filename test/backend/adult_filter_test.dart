import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_adult');
    DbFactory.debugPath = '${dir.path}/db.sqlite';
    await DbFactory.debugReset();
    final db = await DbFactory.db;
    await db.execute(
        "INSERT INTO sources (id, name, source_type, enabled) VALUES (1, 'S', 0, 1)");
    for (final row in [
      ['Canal Cocina', 'Cooking'],
      ['Canal Cine', 'Movies;Series'],
      ['Canal Rojo', 'XXX'],
      ['Canal Adultos', 'Adultos'],
      ['Canal Mixto', 'Movies;Adult'],
      ['Canal +18', '+18'],
      ['Canal Sin Grupo', null],
    ]) {
      await db.execute('''
        INSERT INTO channels (name, group_name, url, media_type, source_id, favorite)
        VALUES (?, ?, 'http://x', ?, 1, 0)''',
          [row[0], row[1], MediaType.livestream.index]);
    }
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  Filters f({bool hideAdult = false, String? group}) => Filters(
        viewType: ViewType.all,
        sourceIds: [1],
        mediaTypes: [MediaType.livestream],
        hideAdult: hideAdult,
        groupName: group,
      );

  test('sin el filtro se ven todos los canales', () async {
    expect(await Sql.search(f()), hasLength(7));
  });

  test('hideAdult oculta los grupos de adultos y deja los demás', () async {
    final r = await Sql.search(f(hideAdult: true));
    expect(r.map((c) => c.name),
        ['Canal Cocina', 'Canal Cine', 'Canal Sin Grupo']);
  });

  test('hideAdult funciona junto a otros filtros (grupo)', () async {
    final r = await Sql.search(f(hideAdult: true, group: 'Cooking'));
    expect(r.map((c) => c.name), ['Canal Cocina']);
  });

  test('los grupos de adultos no aparecen en la lista de grupos', () async {
    final all = await Sql.searchGroupNames(f());
    expect(all.map((g) => g.name),
        containsAll(['Cooking', 'XXX', 'Adultos', '+18']));
    final safe = await Sql.searchGroupNames(f(hideAdult: true));
    expect(safe.map((g) => g.name), ['Cooking', 'Movies;Series']);
  });

  test('el historial y los favoritos también los ocultan', () async {
    final db = await DbFactory.db;
    await db.execute(
        "UPDATE channels SET favorite = 1, last_watched = 5 WHERE group_name IN ('XXX', 'Cooking')");
    for (final v in [ViewType.favorites, ViewType.history]) {
      final r = await Sql.search(Filters(
        viewType: v,
        sourceIds: [1],
        mediaTypes: [MediaType.livestream],
        hideAdult: true,
      ));
      expect(r.map((c) => c.name), ['Canal Cocina'], reason: '$v');
    }
  });
}
