import 'package:open_tv/backend/db_factory.dart';

/// Estado de los canales: un canal se considera caído tras 2 fallos seguidos
/// (o si se marca a mano) y deja de contar a los 7 días. Se guarda por
/// `(source_id, nombre)` para sobrevivir a las actualizaciones de las fuentes.
abstract final class ChannelHealthSql {
  static const int deadAfterFailures = 2;
  static const Duration ttl = Duration(days: 7);

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// Segundos de época a partir de los cuales un registro ya caducó.
  static int cutoff() => _now() - ttl.inSeconds;

  /// Condición SQL "el canal `channels` está caído".
  static String deadSql() => '''
    EXISTS (SELECT 1 FROM channel_health h
            WHERE h.source_id = channels.source_id AND h.name = channels.name
              AND h.failed_at > ${cutoff()}
              AND (h.manual = 1 OR h.fail_count >= $deadAfterFailures))''';

  /// Cuenta un fallo (reinicia la cuenta si el anterior ya caducó).
  static Future<void> recordFailure(int sourceId, String name) async {
    final db = await DbFactory.db;
    final now = _now();
    await db.execute('''
      INSERT INTO channel_health (source_id, name, failed_at, fail_count, manual)
      VALUES (?, ?, ?, 1, 0)
      ON CONFLICT(source_id, name) DO UPDATE SET
        fail_count = CASE WHEN failed_at > ? THEN fail_count + 1 ELSE 1 END,
        failed_at = excluded.failed_at
    ''', [sourceId, name, now, cutoff()]);
  }

  /// El canal reprodujo bien: se olvida cualquier fallo, incluso el manual.
  static Future<void> recordSuccess(int sourceId, String name) => clear(sourceId, name);

  /// Marca a mano un canal como caído.
  static Future<void> markDead(int sourceId, String name) async {
    final db = await DbFactory.db;
    await db.execute('''
      INSERT INTO channel_health (source_id, name, failed_at, fail_count, manual)
      VALUES (?, ?, ?, $deadAfterFailures, 1)
      ON CONFLICT(source_id, name) DO UPDATE SET
        failed_at = excluded.failed_at, fail_count = $deadAfterFailures, manual = 1
    ''', [sourceId, name, _now()]);
  }

  static Future<void> clear(int sourceId, String name) async {
    final db = await DbFactory.db;
    await db.execute(
        'DELETE FROM channel_health WHERE source_id = ? AND name = ?',
        [sourceId, name]);
  }

  static Future<void> clearAll() async {
    final db = await DbFactory.db;
    await db.execute('DELETE FROM channel_health');
  }

  static Future<bool> isDead(int sourceId, String name) async {
    final db = await DbFactory.db;
    final row = await db.getOptional('''
      SELECT 1 FROM channel_health
      WHERE source_id = ? AND name = ? AND failed_at > ${cutoff()}
        AND (manual = 1 OR fail_count >= $deadAfterFailures)
    ''', [sourceId, name]);
    return row != null;
  }

  static Future<int> deadCount() async {
    final db = await DbFactory.db;
    final row = await db.get('''
      SELECT COUNT(*) FROM channel_health
      WHERE failed_at > ${cutoff()} AND (manual = 1 OR fail_count >= $deadAfterFailures)
    ''');
    return row.columnAt(0) as int;
  }
}
