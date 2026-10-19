import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/user_playlist.dart';

/// SQL de las listas propias. Los canales se guardan como
/// `(source_id, nombre del canal)`, así siguen existiendo cuando una fuente se
/// actualiza y cambian los enlaces.
abstract final class UserPlaylistsSql {
  static Future<List<UserPlaylist>> all() async {
    final db = await DbFactory.db;
    final rows = await db.getAll('''
      SELECT p.id, p.name, COUNT(c.id)
      FROM user_playlists p
      LEFT JOIN user_playlist_items i ON i.playlist_id = p.id
      LEFT JOIN channels c ON c.source_id = i.source_id AND c.name = i.channel_name
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE
    ''');
    return rows
        .map((r) => UserPlaylist(
            id: r.columnAt(0), name: r.columnAt(1), channelCount: r.columnAt(2)))
        .toList();
  }

  /// Crea una lista; lanza `StateError('duplicate')` si el nombre ya existe
  /// (sin distinguir mayúsculas).
  static Future<int> create(String name) async {
    final db = await DbFactory.db;
    return db.writeTransaction((tx) async {
      final dup = await tx.getOptional(
          'SELECT 1 FROM user_playlists WHERE name = ? COLLATE NOCASE', [name]);
      if (dup != null) throw StateError('duplicate');
      await tx.execute(
          'INSERT INTO user_playlists (name, created_at) VALUES (?, ?)',
          [name, DateTime.now().millisecondsSinceEpoch ~/ 1000]);
      return (await tx.get('SELECT last_insert_rowid()')).columnAt(0) as int;
    });
  }

  static Future<void> rename(int id, String name) async {
    final db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      final dup = await tx.getOptional(
          'SELECT 1 FROM user_playlists WHERE name = ? COLLATE NOCASE AND id <> ?',
          [name, id]);
      if (dup != null) throw StateError('duplicate');
      await tx.execute('UPDATE user_playlists SET name = ? WHERE id = ?', [name, id]);
    });
  }

  static Future<void> delete(int id) async {
    final db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      await tx.execute('DELETE FROM user_playlist_items WHERE playlist_id = ?', [id]);
      await tx.execute('DELETE FROM user_playlists WHERE id = ?', [id]);
    });
  }

  /// Agrega un canal al final; `false` si ya estaba en la lista.
  static Future<bool> add(int playlistId, Channel c) async {
    final db = await DbFactory.db;
    return db.writeTransaction((tx) async {
      await tx.execute('''
        INSERT OR IGNORE INTO user_playlist_items (playlist_id, source_id, channel_name, position)
        VALUES (?, ?, ?, (SELECT COALESCE(MAX(position), -1) + 1 FROM user_playlist_items WHERE playlist_id = ?))
      ''', [playlistId, c.sourceId, c.name, playlistId]);
      return (await tx.get('SELECT changes()')).columnAt(0) > 0;
    });
  }

  static Future<void> remove(int playlistId, Channel c) async {
    final db = await DbFactory.db;
    await db.execute('''
      DELETE FROM user_playlist_items
      WHERE playlist_id = ? AND source_id = ? AND channel_name = ?
    ''', [playlistId, c.sourceId, c.name]);
  }

  /// Intercambia la posición con el vecino inmediato (`delta` = -1 o +1).
  static Future<void> move(int playlistId, Channel c, int delta) async {
    final db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      final current = await tx.getOptional('''
        SELECT id, position FROM user_playlist_items
        WHERE playlist_id = ? AND source_id = ? AND channel_name = ?
      ''', [playlistId, c.sourceId, c.name]);
      if (current == null) return;
      final neighbor = await tx.getOptional(
        delta < 0
            ? '''SELECT id, position FROM user_playlist_items
                 WHERE playlist_id = ? AND position < ? ORDER BY position DESC LIMIT 1'''
            : '''SELECT id, position FROM user_playlist_items
                 WHERE playlist_id = ? AND position > ? ORDER BY position ASC LIMIT 1''',
        [playlistId, current.columnAt(1)],
      );
      if (neighbor == null) return;
      await tx.execute('UPDATE user_playlist_items SET position = ? WHERE id = ?',
          [neighbor.columnAt(1), current.columnAt(0)]);
      await tx.execute('UPDATE user_playlist_items SET position = ? WHERE id = ?',
          [current.columnAt(1), neighbor.columnAt(0)]);
    });
  }

  static Future<List<Channel>> channels(int playlistId) async {
    final db = await DbFactory.db;
    final rows = await db.getAll('''
      SELECT c.* FROM user_playlist_items i
      JOIN channels c ON c.source_id = i.source_id AND c.name = i.channel_name
      WHERE i.playlist_id = ? AND c.url IS NOT NULL
      ORDER BY i.position
    ''', [playlistId]);
    return rows.map(Sql.rowToChannel).toList();
  }

  /// Id de la fuente `Custom Channels` (o `null` si aún no existe).
  static Future<int?> customSourceId() async {
    final db = await DbFactory.db;
    final row = await db.getOptional(
        'SELECT id FROM sources WHERE name = ?', [customSourceName]);
    return row?.columnAt(0);
  }

  /// Borra un canal manual (solo de la fuente `Custom Channels`) y lo quita de
  /// todas las listas.
  static Future<void> deleteManualChannel(Channel c) async {
    final db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      await tx.execute('''
        DELETE FROM user_playlist_items
        WHERE source_id = ? AND channel_name = ?
          AND source_id IN (SELECT id FROM sources WHERE name = ?)
      ''', [c.sourceId, c.name, customSourceName]);
      await tx.execute('''
        DELETE FROM channels
        WHERE source_id = ? AND name = ?
          AND source_id IN (SELECT id FROM sources WHERE name = ?)
      ''', [c.sourceId, c.name, customSourceName]);
    });
  }

  /// Guarda un canal manual en la fuente `Custom Channels` y lo devuelve.
  static Future<Channel> addManualChannel({
    required String name,
    required String url,
  }) async {
    await Sql.addCustomChannel(
        name: name, url: url, group: 'Mis canales', favorite: false);
    final db = await DbFactory.db;
    final row = await db.get('''
      SELECT c.* FROM channels c
      JOIN sources s ON s.id = c.source_id
      WHERE s.name = ? AND c.name = ?
    ''', [customSourceName, name]);
    return Sql.rowToChannel(row);
  }
}
