import 'dart:convert';

import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/user_playlists_sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/source_type.dart';

const int backupVersion = 1;
const String _backupApp = 'fred-tv';

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackupResult {
  const BackupResult({
    this.sourcesAdded = 0,
    this.favoritesApplied = 0,
    this.favoritesMissing = 0,
    this.playlistsCreated = 0,
    this.playlistItems = 0,
    this.customChannels = 0,
    this.settingsApplied = 0,
  });

  final int sourcesAdded;
  final int favoritesApplied;
  final int favoritesMissing;
  final int playlistsCreated;
  final int playlistItems;
  final int customChannels;
  final int settingsApplied;

  BackupResult copyWith({int? sourcesAdded}) => BackupResult(
        sourcesAdded: sourcesAdded ?? this.sourcesAdded,
        favoritesApplied: favoritesApplied,
        favoritesMissing: favoritesMissing,
        playlistsCreated: playlistsCreated,
        playlistItems: playlistItems,
        customChannels: customChannels,
        settingsApplied: settingsApplied,
      );

  /// Resumen en una línea para mostrar al usuario.
  String get summary {
    final parts = <String>[
      if (sourcesAdded > 0) '$sourcesAdded listas',
      if (favoritesApplied > 0) '$favoritesApplied favoritos',
      if (playlistsCreated > 0) '$playlistsCreated listas propias nuevas',
      if (playlistItems > 0) '$playlistItems canales en listas',
      if (customChannels > 0) '$customChannels canales propios',
      if (settingsApplied > 0) '$settingsApplied ajustes',
    ];
    final base = parts.isEmpty ? 'Nada nuevo que importar' : parts.join(', ');
    return favoritesMissing > 0
        ? '$base ($favoritesMissing favoritos sin canal)'
        : base;
  }
}

/// Copia de seguridad: favoritos, listas propias, canales propios, fuentes M3U
/// por URL y ajustes. Se identifica todo por nombre (los ids cambian entre
/// dispositivos). Nunca incluye el PIN, fuentes Xtream (llevan contraseña) ni
/// marcas de refresco.
abstract final class BackupSql {
  static const List<String> _settingKeys = [
    'tvAutoRefresh',
    'tvBufferSecs',
    'tvEngine',
    'tvTextScale',
    'tvHighContrast',
    'tvHideDead',
    'tvHideAdult',
  ];
  static const String _channelEnginePrefix = 'tvEngine:';

  static bool _isSettingAllowed(String key) =>
      _settingKeys.contains(key) || key.startsWith(_channelEnginePrefix);

  static Future<Map<String, dynamic>> export() async {
    final db = await DbFactory.db;

    final favorites = await db.getAll('''
      SELECT s.name AS source, c.name AS name
      FROM channels c JOIN sources s ON s.id = c.source_id
      WHERE c.favorite = 1 AND s.name <> ?
      ORDER BY s.name, c.name
    ''', [customSourceName]);

    final playlists = <Map<String, dynamic>>[];
    for (final p in await db.getAll(
        'SELECT id, name FROM user_playlists ORDER BY name COLLATE NOCASE')) {
      final items = await db.getAll('''
        SELECT s.name AS source, i.channel_name AS name
        FROM user_playlist_items i JOIN sources s ON s.id = i.source_id
        WHERE i.playlist_id = ? ORDER BY i.position
      ''', [p['id']]);
      playlists.add({
        'name': p['name'],
        'items': items
            .map((r) => {'source': r['source'], 'name': r['name']})
            .toList(),
      });
    }

    final custom = await db.getAll('''
      SELECT c.name, c.url, c.group_name, c.image
      FROM channels c JOIN sources s ON s.id = c.source_id
      WHERE s.name = ? ORDER BY c.name
    ''', [customSourceName]);

    final sources = await db.getAll('''
      SELECT name, url FROM sources
      WHERE source_type = ? AND name <> ? ORDER BY name
    ''', [SourceType.m3uUrl.index, customSourceName]);

    final settings = <String, String>{};
    for (final r in await db.getAll('SELECT key, value FROM settings')) {
      final key = r['key'] as String;
      final value = r['value'] as String?;
      if (value != null && _isSettingAllowed(key)) settings[key] = value;
    }

    return {
      'app': _backupApp,
      'version': backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sources': sources
          .map((r) => {'name': r['name'], 'url': r['url']})
          .toList(),
      'favorites': favorites
          .map((r) => {'source': r['source'], 'name': r['name']})
          .toList(),
      'playlists': playlists,
      'customChannels': custom
          .map((r) => {
                'name': r['name'],
                'url': r['url'],
                'group': r['group_name'],
                'image': r['image'],
              })
          .toList(),
      'settings': settings,
    };
  }

  /// Valida el texto de una copia; lanza [BackupFormatException] si no sirve.
  static Map<String, dynamic> parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw BackupFormatException('El archivo no es una copia válida');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != _backupApp) {
      throw BackupFormatException('El archivo no es una copia de Fred TV');
    }
    final version = decoded['version'];
    if (version is! int || version < 1) {
      throw BackupFormatException('La copia no indica su versión');
    }
    if (version > backupVersion) {
      throw BackupFormatException(
          'La copia es de una versión más nueva de la app');
    }
    return decoded;
  }

  /// Fuentes de la copia que aún no existen aquí (por nombre).
  static Future<List<Map<String, dynamic>>> sourcesToAdd(
      Map<String, dynamic> data) async {
    final db = await DbFactory.db;
    final existing = (await db.getAll('SELECT name FROM sources'))
        .map((r) => r['name'] as String)
        .toSet();
    return [
      for (final s in (data['sources'] as List? ?? const []))
        if (s is Map &&
            s['name'] is String &&
            s['url'] is String &&
            !existing.contains(s['name']))
          Map<String, dynamic>.from(s)
    ];
  }

  static Future<int?> _sourceId(String name) async {
    final db = await DbFactory.db;
    final row =
        await db.getOptional('SELECT id FROM sources WHERE name = ?', [name]);
    return row?.columnAt(0) as int?;
  }

  /// Aplica favoritos, listas propias, canales propios y ajustes. Las fuentes
  /// y la descarga de sus canales las hace quien llama antes (necesitan red).
  static Future<BackupResult> restore(Map<String, dynamic> data) async {
    final db = await DbFactory.db;
    var applied = 0, missing = 0;
    for (final f in (data['favorites'] as List? ?? const [])) {
      if (f is! Map || f['source'] is! String || f['name'] is! String) continue;
      final sid = await _sourceId(f['source']);
      var ok = false;
      if (sid != null) {
        final n = await db.getOptional(
            'SELECT 1 FROM channels WHERE source_id = ? AND name = ?',
            [sid, f['name']]);
        if (n != null) {
          await db.execute(
              'UPDATE channels SET favorite = 1 WHERE source_id = ? AND name = ?',
              [sid, f['name']]);
          ok = true;
        }
      }
      ok ? applied++ : missing++;
    }

    var custom = 0;
    for (final c in (data['customChannels'] as List? ?? const [])) {
      if (c is! Map || c['name'] is! String || c['url'] is! String) continue;
      await Sql.addCustomChannel(
        name: c['name'],
        url: c['url'],
        image: c['image'] as String?,
        group: (c['group'] as String?) ?? 'Favorites',
        favorite: false,
      );
      custom++;
    }

    var created = 0, items = 0;
    final existing = {
      for (final p in await UserPlaylistsSql.all()) p.name.toLowerCase(): p.id
    };
    for (final p in (data['playlists'] as List? ?? const [])) {
      if (p is! Map || p['name'] is! String) continue;
      final name = p['name'] as String;
      var id = existing[name.toLowerCase()];
      if (id == null) {
        id = await UserPlaylistsSql.create(name);
        existing[name.toLowerCase()] = id;
        created++;
      }
      for (final i in (p['items'] as List? ?? const [])) {
        if (i is! Map || i['source'] is! String || i['name'] is! String) continue;
        final sid = await _sourceId(i['source']);
        if (sid == null) continue;
        final added = await UserPlaylistsSql.add(
            id,
            Channel(
                name: i['name'],
                mediaType: MediaType.livestream,
                sourceId: sid,
                favorite: false));
        if (added) items++;
      }
    }

    var settings = 0;
    final raw = data['settings'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.key is String && e.value is String && _isSettingAllowed(e.key)) {
          await Sql.setSetting(e.key, e.value);
          settings++;
        }
      }
    }

    return BackupResult(
      favoritesApplied: applied,
      favoritesMissing: missing,
      playlistsCreated: created,
      playlistItems: items,
      customChannels: custom,
      settingsApplied: settings,
    );
  }
}
