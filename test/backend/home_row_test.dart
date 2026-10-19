import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/tv_links.dart';
import 'package:open_tv/screens/tv/tv_platform.dart';

class _Recorder extends TvPlatform {
  final List<List<TvHomeItem>> published = [];

  @override
  Future<void> publishFavorites(List<TvHomeItem> items) async =>
      published.add(items);
}

void main() {
  late Directory dir;
  const data = TvData();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_homerow');
    DbFactory.debugPath = '${dir.path}/db.sqlite';
    await DbFactory.debugReset();
    final db = await DbFactory.db;
    await db.execute(
        "INSERT INTO sources (id, name, source_type, enabled) VALUES (1, 'Lista A', 1, 1)");
    for (final row in [
      ['Uno', 1],
      ['Dos', 0],
      ['Tres', 1],
    ]) {
      await db.execute('''
        INSERT INTO channels (name, group_name, url, image, media_type, source_id, favorite)
        VALUES (?, 'G', 'http://x', 'http://img/x.png', ?, 1, ?)''',
          [row[0], MediaType.livestream.index, row[1]]);
    }
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  test('publica los favoritos con su enlace de reproducción', () async {
    final platform = _Recorder();
    await data.publishHomeRow(platform: platform);
    final items = platform.published.single;
    expect(items.map((i) => i.title), ['Uno', 'Tres']);
    final link = parseTvLink(items.first.link) as TvPlayLink;
    expect(link.name, 'Uno');
    expect(link.source, 'Lista A');
    expect(items.first.image, 'http://img/x.png');
  });

  test('sin favoritos publica una lista vacía (limpia la fila)', () async {
    final db = await DbFactory.db;
    await db.execute('UPDATE channels SET favorite = 0');
    final platform = _Recorder();
    await data.publishHomeRow(platform: platform);
    expect(platform.published.single, isEmpty);
  });

  test('findChannel encuentra por nombre y respeta la lista', () async {
    final c = await data.findChannel('Dos', sourceName: 'Lista A');
    expect(c?.name, 'Dos');
    expect(await data.findChannel('Dos', sourceName: 'Otra'), isNull);
    expect((await data.findChannel('Tres'))?.name, 'Tres');
    expect(await data.findChannel('Nada'), isNull);
  });
}
