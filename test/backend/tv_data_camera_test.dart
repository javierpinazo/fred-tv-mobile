import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart' show customSourceName;
import 'package:open_tv/screens/tv/player/tv_camera.dart';
import 'package:open_tv/screens/tv/tv_data.dart';

void main() {
  late Directory dir;
  const data = TvData();
  const url = 'rtsp://192.168.1.20/stream1';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_data_camera');
    DbFactory.debugPath = '${dir.path}/db.sqlite';
    await DbFactory.debugReset();
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  Future<List<Map<String, Object?>>> cameraChannels() async {
    final db = await DbFactory.db;
    final rows = await db.getAll('''
      SELECT c.name, c.url, c.favorite FROM channels c
      JOIN sources s ON s.id = c.source_id
      WHERE s.name = ? AND c.name = ?''', [customSourceName, tvCameraChannelName]);
    return rows
        .map((r) => {'name': r['name'], 'url': r['url'], 'favorite': r['favorite']})
        .toList();
  }

  test('sin configurar no hay cámara ni canal', () async {
    expect(await data.cameraUrlSetting(), isNull);
    expect(await cameraChannels(), isEmpty);
  });

  test('guardar la URL crea el canal «Cámara» como favorito', () async {
    await data.setCameraUrlSetting('  $url  ');
    expect(await data.cameraUrlSetting(), url);
    expect(await cameraChannels(), [
      {'name': tvCameraChannelName, 'url': url, 'favorite': 1},
    ]);
  });

  test('cambiar la URL actualiza el canal sin duplicarlo ni tocar el favorito',
      () async {
    await data.setCameraUrlSetting(url);
    final db = await DbFactory.db;
    await db.execute(
        "UPDATE channels SET favorite = 0 WHERE name = '$tvCameraChannelName'");
    await data.setCameraUrlSetting('rtsp://10.0.0.5/live');
    expect(await cameraChannels(), [
      {'name': tvCameraChannelName, 'url': 'rtsp://10.0.0.5/live', 'favorite': 0},
    ]);
  });

  test('quitar la URL borra el canal', () async {
    await data.setCameraUrlSetting(url);
    await data.setCameraUrlSetting(null);
    expect(await data.cameraUrlSetting(), isNull);
    expect(await cameraChannels(), isEmpty);
  });
}
