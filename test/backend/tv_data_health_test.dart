import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/screens/tv/tv_data.dart';

void main() {
  late Directory dir;
  const data = TvData();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_data_health');
    DbFactory.debugPath = '${dir.path}/db.sqlite';
    await DbFactory.debugReset();
    final db = await DbFactory.db;
    await db.execute(
        "INSERT INTO sources (id, name, source_type, enabled) VALUES (1, 'S', 0, 1)");
    for (final n in ['Uno', 'Dos']) {
      await db.execute('''
        INSERT INTO channels (name, group_name, url, media_type, source_id, favorite)
        VALUES (?, 'G', 'http://x/$n', ?, 1, 0)''',
          [n, MediaType.livestream.index]);
    }
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  Filters all() => Filters(
      viewType: ViewType.all,
      sourceIds: [1],
      mediaTypes: [MediaType.livestream]);

  Channel ch(String n) => Channel(
      name: n, mediaType: MediaType.livestream, sourceId: 1, favorite: false);

  test('por defecto los caídos se listan (marcados)', () async {
    await data.markChannelDead(ch('Dos'));
    final r = await data.searchChannels(all());
    expect(r.map((c) => c.name), ['Uno', 'Dos']);
    expect(r.last.dead, isTrue);
    expect(await data.deadChannelCount(), 1);
  });

  test('con "ocultar caídos" desaparecen de Canales y Búsqueda', () async {
    await data.markChannelDead(ch('Dos'));
    await data.setHideDeadSetting(true);
    expect(await data.hideDeadSetting(), isTrue);
    final r = await data.searchChannels(all());
    expect(r.map((c) => c.name), ['Uno']);
  });

  test('Favoritos nunca oculta los caídos', () async {
    await data.markChannelDead(ch('Dos'));
    await data.setHideDeadSetting(true);
    final db = await DbFactory.db;
    await db.execute("UPDATE channels SET favorite = 1 WHERE name = 'Dos'");
    final r = await data.searchChannels(Filters(
        viewType: ViewType.favorites,
        sourceIds: [1],
        mediaTypes: [MediaType.livestream]));
    expect(r.map((c) => c.name), ['Dos']);
  });

  test('reportChannelFailure devuelve true al segundo fallo', () async {
    expect(await data.reportChannelFailure(ch('Uno')), isFalse);
    expect(await data.reportChannelFailure(ch('Uno')), isTrue);
    await data.reportChannelSuccess(ch('Uno'));
    expect(await data.deadChannelCount(), 0);
  });

  test('clearDeadChannels y clearChannelDead', () async {
    await data.markChannelDead(ch('Uno'));
    await data.markChannelDead(ch('Dos'));
    await data.clearChannelDead(ch('Uno'));
    expect(await data.deadChannelCount(), 1);
    await data.clearDeadChannels();
    expect(await data.deadChannelCount(), 0);
  });
}
