import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/backup_sql.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/user_playlists_sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/source_type.dart';

Future<void> _newDb(Directory dir, String file) async {
  await DbFactory.debugReset();
  DbFactory.debugPath = '${dir.path}/$file';
  await DbFactory.db;
}

Future<int> _source(String name, SourceType type, String? url,
    {String? user, String? pass}) async {
  final db = await DbFactory.db;
  await db.execute('''
    INSERT INTO sources (name, source_type, url, username, password, enabled)
    VALUES (?, ?, ?, ?, ?, 1)''', [name, type.index, url, user, pass]);
  return (await db.get('SELECT id FROM sources WHERE name = ?', [name]))
      .columnAt(0) as int;
}

Future<void> _channel(int sourceId, String name,
    {bool favorite = false, String? url}) async {
  final db = await DbFactory.db;
  await db.execute('''
    INSERT INTO channels (name, group_name, url, media_type, source_id, favorite)
    VALUES (?, 'G', ?, ?, ?, ?)''',
      [name, url ?? 'http://x/$name', MediaType.livestream.index, sourceId, favorite ? 1 : 0]);
}

Channel _ref(int sourceId, String name) => Channel(
    name: name,
    mediaType: MediaType.livestream,
    sourceId: sourceId,
    favorite: false);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_backup');
    await _newDb(dir, 'a.sqlite');
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  Future<void> seedDeviceA() async {
    final s1 = await _source('IPTV Español', SourceType.m3uUrl, 'http://lista/es.m3u');
    await _source('Mi Xtream', SourceType.xtream, 'http://srv', user: 'u', pass: 'secreto');
    await _channel(s1, 'TV Peru', favorite: true);
    await _channel(s1, 'HBO 2');
    await _channel(s1, 'Cocina', favorite: true);
    await Sql.addCustomChannel(
        name: 'Mi canal', url: 'http://mi/canal.m3u8', group: 'Propios', favorite: false);
    final pid = await UserPlaylistsSql.create('Noticias');
    await UserPlaylistsSql.add(pid, _ref(s1, 'TV Peru'));
    await UserPlaylistsSql.add(pid, _ref(s1, 'HBO 2'));
    await Sql.setSetting('tvBufferSecs', '5');
    await Sql.setSetting('tvEngine', 'mpv');
    await Sql.setSetting('tvEngine:http://x/HBO 2', 'mpv');
    await Sql.setSetting('tvParentalPin', 'sal\$hashsecreto');
    await Sql.setSetting('lastRefresh_1', '123');
  }

  test('exporta favoritos, listas, canales propios, fuentes M3U y ajustes',
      () async {
    await seedDeviceA();
    final data = await BackupSql.export();
    expect(data['app'], 'fred-tv');
    expect(data['version'], backupVersion);
    expect((data['favorites'] as List).map((f) => f['name']),
        unorderedEquals(['TV Peru', 'Cocina']));
    expect((data['favorites'] as List).first['source'], 'IPTV Español');
    final playlists = data['playlists'] as List;
    expect(playlists.single['name'], 'Noticias');
    expect((playlists.single['items'] as List).map((i) => i['name']),
        ['TV Peru', 'HBO 2']);
    expect((data['customChannels'] as List).single['name'], 'Mi canal');
    expect((data['sources'] as List).map((s) => s['name']), ['IPTV Español']);
    final settings = data['settings'] as Map;
    expect(settings['tvBufferSecs'], '5');
    expect(settings['tvEngine:http://x/HBO 2'], 'mpv');
  });

  test('nunca exporta el PIN, contraseñas Xtream ni marcas de refresco',
      () async {
    await seedDeviceA();
    final json = jsonEncode(await BackupSql.export());
    expect(json, isNot(contains('secreto')));
    expect(json, isNot(contains('Mi Xtream')));
    expect(json, isNot(contains('tvParentalPin')));
    expect(json, isNot(contains('lastRefresh_')));
  });

  test('ida y vuelta: restaurar en otro dispositivo recompone todo', () async {
    await seedDeviceA();
    final exported = jsonDecode(jsonEncode(await BackupSql.export()))
        as Map<String, dynamic>;

    // Dispositivo B: solo tiene las fuentes y canales (ya refrescados).
    await _newDb(dir, 'b.sqlite');
    final s1 = await _source('IPTV Español', SourceType.m3uUrl, 'http://lista/es.m3u');
    await _channel(s1, 'TV Peru');
    await _channel(s1, 'HBO 2');
    await _channel(s1, 'Cocina');

    final result = await BackupSql.restore(exported);
    expect(result.favoritesApplied, 2);
    expect(result.favoritesMissing, 0);
    expect(result.playlistsCreated, 1);
    expect(result.playlistItems, 2);
    expect(result.customChannels, 1);

    final db = await DbFactory.db;
    final favs = await db.getAll('SELECT name FROM channels WHERE favorite = 1 ORDER BY name');
    expect(favs.map((r) => r['name']), ['Cocina', 'TV Peru']);
    final lists = await UserPlaylistsSql.all();
    expect(lists.single.name, 'Noticias');
    expect(lists.single.channelCount, 2);
    expect(await Sql.getSetting('tvBufferSecs'), '5');
    expect(await Sql.getSetting('tvEngine'), 'mpv');
    final custom = await db.getAll("SELECT name FROM channels WHERE name = 'Mi canal'");
    expect(custom, hasLength(1));
  });

  test('un favorito cuyo canal no existe se cuenta como no encontrado',
      () async {
    await seedDeviceA();
    final exported = jsonDecode(jsonEncode(await BackupSql.export()))
        as Map<String, dynamic>;
    await _newDb(dir, 'c.sqlite');
    final s1 = await _source('IPTV Español', SourceType.m3uUrl, 'http://lista/es.m3u');
    await _channel(s1, 'TV Peru'); // 'Cocina' ya no existe
    final result = await BackupSql.restore(exported);
    expect(result.favoritesApplied, 1);
    expect(result.favoritesMissing, 1);
  });

  test('restaurar dos veces no duplica listas ni elementos', () async {
    await seedDeviceA();
    final exported = jsonDecode(jsonEncode(await BackupSql.export()))
        as Map<String, dynamic>;
    final first = await BackupSql.restore(exported);
    final second = await BackupSql.restore(exported);
    expect(first.playlistsCreated, 0); // ya existía en este dispositivo
    expect(second.playlistsCreated, 0);
    expect((await UserPlaylistsSql.all()).single.channelCount, 2);
  });

  test('sourcesToAdd devuelve solo las fuentes que faltan', () async {
    await seedDeviceA();
    final exported = jsonDecode(jsonEncode(await BackupSql.export()))
        as Map<String, dynamic>;
    expect(await BackupSql.sourcesToAdd(exported), isEmpty);
    await _newDb(dir, 'd.sqlite');
    final missing = await BackupSql.sourcesToAdd(exported);
    expect(missing.single['name'], 'IPTV Español');
    expect(missing.single['url'], 'http://lista/es.m3u');
  });

  test('ajustes desconocidos o peligrosos se ignoran al restaurar', () async {
    await _newDb(dir, 'e.sqlite');
    final result = await BackupSql.restore({
      'app': 'fred-tv',
      'version': 1,
      'settings': {
        'tvBufferSecs': '2',
        'tvParentalPin': 'sal\$hash',
        'algoRaro': 'x',
      },
    });
    expect(result.settingsApplied, 1);
    expect(await Sql.getSetting('tvBufferSecs'), '2');
    expect(await Sql.getSetting('tvParentalPin'), isNull);
    expect(await Sql.getSetting('algoRaro'), isNull);
  });

  group('parse', () {
    test('acepta una copia válida', () {
      final m = BackupSql.parse('{"app":"fred-tv","version":1}');
      expect(m['version'], 1);
    });

    test('rechaza JSON roto, otra app y versiones futuras', () {
      expect(() => BackupSql.parse('no es json'),
          throwsA(isA<BackupFormatException>()));
      expect(() => BackupSql.parse('[1,2]'),
          throwsA(isA<BackupFormatException>()));
      expect(() => BackupSql.parse('{"app":"otra","version":1}'),
          throwsA(isA<BackupFormatException>()));
      expect(() => BackupSql.parse('{"app":"fred-tv","version":99}'),
          throwsA(isA<BackupFormatException>()));
      expect(() => BackupSql.parse('{"app":"fred-tv"}'),
          throwsA(isA<BackupFormatException>()));
    });
  });
}
