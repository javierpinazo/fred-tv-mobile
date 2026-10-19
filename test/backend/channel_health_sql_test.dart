import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/channel_health_sql.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

Future<void> _seed() async {
  final db = await DbFactory.db;
  await db.execute(
      "INSERT INTO sources (id, name, source_type, enabled) VALUES (1, 'S', 0, 1)");
  for (final n in ['Uno', 'Dos', 'Tres']) {
    await db.execute('''
      INSERT INTO channels (name, group_name, url, media_type, source_id, favorite)
      VALUES (?, 'G', 'http://x/$n', ?, 1, 0)''', [n, MediaType.livestream.index]);
  }
}

Filters _all({bool hideDead = false}) => Filters(
      viewType: ViewType.all,
      sourceIds: [1],
      mediaTypes: [MediaType.livestream],
      hideDead: hideDead,
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_health');
    DbFactory.debugPath = '${dir.path}/db.sqlite';
    await DbFactory.debugReset();
    await _seed();
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  test('un fallo suelto no marca el canal; el segundo sí', () async {
    await ChannelHealthSql.recordFailure(1, 'Uno');
    var r = await Sql.search(_all());
    expect(r.firstWhere((c) => c.name == 'Uno').dead, isFalse);
    await ChannelHealthSql.recordFailure(1, 'Uno');
    r = await Sql.search(_all());
    expect(r.firstWhere((c) => c.name == 'Uno').dead, isTrue);
    expect(r.firstWhere((c) => c.name == 'Dos').dead, isFalse);
  });

  test('hideDead oculta los caídos y sin él se listan marcados', () async {
    await ChannelHealthSql.markDead(1, 'Dos');
    final shown = await Sql.search(_all());
    expect(shown.map((c) => c.name), containsAll(['Uno', 'Dos', 'Tres']));
    final hidden = await Sql.search(_all(hideDead: true));
    expect(hidden.map((c) => c.name), ['Uno', 'Tres']);
  });

  test('un éxito limpia el estado, incluso el marcado a mano', () async {
    await ChannelHealthSql.markDead(1, 'Dos');
    await ChannelHealthSql.recordSuccess(1, 'Dos');
    final r = await Sql.search(_all(hideDead: true));
    expect(r.map((c) => c.name), contains('Dos'));
    expect(await ChannelHealthSql.deadCount(), 0);
  });

  test('los fallos de hace más de 7 días ya no cuentan', () async {
    final db = await DbFactory.db;
    final old = DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch ~/
        1000;
    await db.execute('''
      INSERT INTO channel_health (source_id, name, failed_at, fail_count, manual)
      VALUES (1, 'Tres', ?, 5, 0)''', [old]);
    final r = await Sql.search(_all(hideDead: true));
    expect(r.map((c) => c.name), contains('Tres'));
    expect(await ChannelHealthSql.deadCount(), 0);
  });

  test('un fallo tras caducar empieza la cuenta de nuevo', () async {
    final db = await DbFactory.db;
    final old = DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch ~/
        1000;
    await db.execute('''
      INSERT INTO channel_health (source_id, name, failed_at, fail_count, manual)
      VALUES (1, 'Uno', ?, 5, 0)''', [old]);
    await ChannelHealthSql.recordFailure(1, 'Uno');
    expect(await ChannelHealthSql.deadCount(), 0);
  });

  test('deadCount y clearAll', () async {
    await ChannelHealthSql.markDead(1, 'Uno');
    await ChannelHealthSql.markDead(1, 'Dos');
    expect(await ChannelHealthSql.deadCount(), 2);
    await ChannelHealthSql.clear(1, 'Uno');
    expect(await ChannelHealthSql.deadCount(), 1);
    await ChannelHealthSql.clearAll();
    expect(await ChannelHealthSql.deadCount(), 0);
  });
}
