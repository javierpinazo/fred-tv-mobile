import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:open_tv/backend/adult_filter.dart';
import 'package:open_tv/backend/channel_health_sql.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_http_headers.dart';
import 'package:open_tv/models/channel_preserve.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:sqlite_async/sqlite3.dart';
import 'package:sqlite_async/sqlite_async.dart';

const int pageSize = 36;

/// Nombre de la fuente que guarda los canales agregados manualmente.
const String customSourceName = 'Custom Channels';

class Sql {
  static Future<void> commitWrite(
      List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
          commits) async {
    var db = await DbFactory.db;
    Map<String, String> memory = {};
    await db.writeTransaction((tx) async {
      for (var commit in commits) {
        await commit(tx, memory);
      }
    });
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String> memory)
      insertChannel(Channel channel) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute('''
        INSERT INTO channels (name, image, url, source_id, media_type, series_id, favorite, stream_id, group_name, tvg_id, country)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (name, source_id)
        DO UPDATE SET
          tvg_id = excluded.tvg_id,
          country = excluded.country,
          url = excluded.url,
          group_name = excluded.group_name,
          media_type = excluded.media_type,
          stream_id = excluded.stream_id,
          image = excluded.image,
          series_id = excluded.series_id;
      ''', [
        channel.name,
        channel.image,
        channel.url,
        channel.sourceId == -1
            ? int.parse(memory['sourceId']!)
            : channel.sourceId,
        channel.mediaType.index,
        channel.seriesId,
        channel.favorite,
        channel.streamId,
        channel.group,
        channel.tvgId,
        channel.country
      ]);
      memory['lastChannelId'] =
          (await tx.get("SELECT last_insert_rowid()")).columnAt(0).toString();
    };
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      updateGroups() {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      var sourceId = int.parse(memory['sourceId']!);
      await tx.execute('''
      INSERT INTO groups (name, image, source_id, media_type)
      SELECT group_name, image, ?, media_type
      FROM channels
      WHERE source_id = ?
      GROUP BY group_name
      ON CONFLICT(name, source_id)
      DO UPDATE SET media_type = excluded.media_type
    ''', [sourceId, sourceId]);
      await tx.execute('''
      UPDATE channels
      SET group_id = (
        SELECT id FROM groups
        WHERE groups.name = channels.group_name
        AND groups.source_id = channels.source_id
        LIMIT 1)
      WHERE source_id = ?
    ''', [sourceId]);
    };
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      insertChannelHeaders(ChannelHttpHeaders headers) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute('''
          INSERT OR IGNORE INTO channel_http_headers (channel_id, referrer, user_agent, http_origin, ignore_ssl)
          VALUES (?, ?, ?, ?, ?)
        ''', [
        int.parse(memory['lastChannelId']!),
        headers.referrer,
        headers.userAgent,
        headers.httpOrigin,
        headers.ignoreSSL
      ]);
    };
  }

  static Future<ChannelHttpHeaders?> getChannelHeaders(int channelId) async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
        SELECT * FROM channel_http_headers
        WHERE channel_id = ?
        LIMIT 1
    ''', [channelId]);
    return result != null ? _rowToHeaders(result) : null;
  }

  static ChannelHttpHeaders _rowToHeaders(Row row) {
    return ChannelHttpHeaders(
        id: row.columnAt(0),
        channelId: row.columnAt(1),
        referrer: row.columnAt(2),
        userAgent: row.columnAt(3),
        httpOrigin: row.columnAt(4),
        ignoreSSL: row.columnAt(5));
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      getOrCreateSourceByName(Source source) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      var sourceId = (await tx.getOptional(
              "SELECT id FROM sources WHERE name = ?", [source.name]))
          ?.columnAt(0);
      if (sourceId != null) {
        memory['sourceId'] = sourceId.toString();
        return;
      }
      await tx.execute('''
            INSERT INTO sources (name, source_type, url, username, password) VALUES (?, ?, ?, ?, ?);
          ''', [
        source.name,
        source.sourceType.index,
        source.url,
        source.username,
        source.password,
      ]);
      memory['sourceId'] =
          (await tx.get("SELECT last_insert_rowid();")).columnAt(0).toString();
    };
  }

  static Future<List<Channel>> search(Filters filters) async {
    if (filters.viewType == ViewType.categories &&
        filters.groupId == null &&
        filters.seriesId == null) {
      return searchGroup(filters);
    }
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var mediaTypes = filters.seriesId == null
        ? filters.mediaTypes!.map((x) => x.index)
        : [1];
    var query = filters.query ?? "";
    var keywords = filters.useKeywords
        ? query.split(" ").map((f) => "%$f%").toList()
        : ["%$query%"];
    var sqlQuery = '''
        SELECT *, ${ChannelHealthSql.deadSql()} AS dead FROM channels 
        WHERE (${getKeywordsSql(keywords.length)})
        AND media_type IN (${generatePlaceholders(mediaTypes.length)})
        AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
        AND url IS NOT NULL
    ''';
    List<Object> params = [];
    if (filters.hideDead) {
      sqlQuery += "\nAND NOT ${ChannelHealthSql.deadSql()}";
    }
    if (filters.country != null) {
      sqlQuery += "\nAND country = ?";
    }
    if (filters.hideAdult) {
      sqlQuery += "\nAND ${notAdultSql()}";
    }
    if (filters.viewType == ViewType.favorites && filters.seriesId == null) {
      sqlQuery += "\nAND favorite = 1";
    }
    if (filters.viewType == ViewType.history) {
      sqlQuery += "\nAND last_watched IS NOT NULL";
      sqlQuery += "\nORDER BY last_watched DESC";
    }
    if (filters.seriesId != null) {
      sqlQuery += "\nAND series_id = ?";
    } else if (filters.groupId != null) {
      sqlQuery += "\nAND group_id = ?";
    } else if (filters.groupName != null) {
      sqlQuery += "\nAND group_name = ?";
    }
    sqlQuery += "\nLIMIT ?, ?";
    params.addAll(keywords);
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    if (filters.country != null) params.add(filters.country!);
    if (filters.hideAdult) params.addAll(adultGroupPatterns);
    if (filters.seriesId != null) {
      params.add(filters.seriesId!);
    } else if (filters.groupId != null) {
      params.add(filters.groupId!);
    } else if (filters.groupName != null) {
      params.add(filters.groupName!);
    }
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results.map(rowToChannel).toList();
  }

  /// Países con canales de TV en directo, de más a menos canales.
  static Future<List<({String code, int count})>> countries(
      List<int> sourceIds) async {
    if (sourceIds.isEmpty) return const [];
    final db = await DbFactory.db;
    final rows = await db.getAll('''
      SELECT country, COUNT(*) AS n FROM channels
      WHERE country IS NOT NULL AND url IS NOT NULL AND media_type = ?
        AND source_id IN (${generatePlaceholders(sourceIds.length)})
      GROUP BY country ORDER BY n DESC, country
    ''', [MediaType.livestream.index, ...sourceIds]);
    return rows
        .map((r) => (code: r['country'] as String, count: r['n'] as int))
        .toList();
  }

  /// Grupos fusionados por nombre entre fuentes (para la UI de TV).
  static Future<List<Channel>> searchGroupNames(Filters filters) async {
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var mediaTypes = filters.mediaTypes!.map((x) => x.index).toList();
    var sqlQuery = '''
        SELECT group_name, MIN(image) FROM channels
        WHERE group_name IS NOT NULL AND group_name <> '' AND url IS NOT NULL
          AND media_type IN (${generatePlaceholders(mediaTypes.length)})
          AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
          ${filters.hideAdult ? 'AND ${notAdultSql()}' : ''}
        GROUP BY group_name ORDER BY group_name COLLATE NOCASE
        LIMIT ?, ?
    ''';
    List<Object> params = [];
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    if (filters.hideAdult) params.addAll(adultGroupPatterns);
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results
        .map((row) => Channel(
            name: row.columnAt(0),
            image: row.columnAt(1),
            mediaType: MediaType.group,
            sourceId: -1,
            favorite: false))
        .toList();
  }

  static Channel rowToChannel(Row row) {
    return Channel(
      id: row.columnAt(0),
      name: row.columnAt(1),
      group: row.columnAt(2),
      image: row.columnAt(3),
      url: row.columnAt(4),
      mediaType: MediaType.values[row.columnAt(5)],
      sourceId: row.columnAt(6),
      favorite: row.columnAt(7) == 1,
      seriesId: row.columnAt(8),
      groupId: row.columnAt(9),
      dead: row.containsKey('dead') && row['dead'] == 1,
    );
  }

  static String generatePlaceholders(int size) {
    return List.filled(size, "?").join(",");
  }

  static String getKeywordsSql(int size) {
    return List.generate(size, (_) => "name LIKE ?").join(" AND ");
  }

  static Future<List<Channel>> searchGroup(Filters filters) async {
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var query = filters.query ?? "";
    var keywords = filters.useKeywords
        ? query.split(" ").map((f) => "%$f%").toList()
        : ["%$query%"];
    var mediaTypes = filters.mediaTypes!.map((x) => x.index);
    var sqlQuery = '''
        SELECT * FROM groups 
        WHERE (${getKeywordsSql(keywords.length)})
        AND (media_type IS NULL OR media_type IN (${generatePlaceholders(mediaTypes.length)}))
        AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
        LIMIT ?, ?
    ''';
    List<Object> params = [];
    params.addAll(keywords);
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results.map(groupChannelToRow).toList();
  }

  static Channel groupChannelToRow(Row row) {
    return Channel(
        id: row.columnAt(0),
        name: row.columnAt(1),
        image: row.columnAt(2),
        sourceId: row.columnAt(3),
        favorite: false,
        mediaType: MediaType.group);
  }

  static Future<bool> sourceNameExists(String? name) async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
      SELECT 1
      FROM sources
      WHERE name = ?
    ''', [name]);
    return result?.columnAt(0) == 1;
  }

  static Future<List<Source>> getSources() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT * 
      FROM sources 
    ''');
    return results.map(rowToSource).toList();
  }

  static Source rowToSource(Row row) {
    return Source(
        id: row.columnAt(0),
        name: row.columnAt(1),
        sourceType: SourceType.values[row.columnAt(2)],
        url: row.columnAt(3),
        username: row.columnAt(4),
        password: row.columnAt(5),
        enabled: row.columnAt(6) == 1);
  }

  static Future<List<IdData<SourceType>>> getEnabledSourcesMinimal() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT id, source_type
      FROM sources 
      WHERE enabled = 1
    ''');
    return results.map(rowToSourceMinimal).toList();
  }

  static IdData<SourceType> rowToSourceMinimal(Row row) {
    return IdData(
        id: row.columnAt(0), data: SourceType.values[row.columnAt(1)]);
  }

  /// Id actual de un canal por (fuente, nombre). Los ids cambian cuando una
  /// fuente se refresca, por eso las pantallas TV los resuelven al actuar.
  static Future<int?> channelIdByKey(int sourceId, String name) async {
    var db = await DbFactory.db;
    var row = await db.getOptional(
        'SELECT id FROM channels WHERE source_id = ? AND name = ?',
        [sourceId, name]);
    return row?.columnAt(0);
  }

  static Future<bool> hasSources() async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
      SELECT 1
      FROM sources
      LIMIT 1
    ''');
    return result?.columnAt(0) == 1;
  }

  /// Adds a custom channel to the database and marks it as favorite
  static Future<void> addCustomChannel({
    required String name,
    required String url,
    String? image,
    String group = "Favorites",
    bool favorite = true,
  }) async {
    var db = await DbFactory.db;

    // First, ensure we have a "Custom" source
    var sourceId = (await db.getOptional(
      "SELECT id FROM sources WHERE name = ?", [customSourceName]
    ))?.columnAt(0);

    if (sourceId == null) {
      await db.execute('''
        INSERT INTO sources (name, source_type, url, enabled) VALUES (?, ?, ?, ?)
      ''', [customSourceName, SourceType.m3u.index, "", 1]);
      // `last_insert_rowid()` en una conexión de lectura puede dar 0: se busca
      // por nombre.
      sourceId = (await db.get(
              "SELECT id FROM sources WHERE name = ?", [customSourceName]))
          .columnAt(0);
    }

    // Insert the channel
    await db.execute('''
      INSERT INTO channels (name, image, url, source_id, media_type, favorite, group_name)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (name, source_id)
      DO UPDATE SET url = excluded.url
    ''', [name, image, url, sourceId, 0, favorite ? 1 : 0, group]);
  }

  /// Adds test channels (France24, DW, etc.)
  static Future<void> addTestChannels() async {
    await addCustomChannel(
      name: "France 24 English",
      url: "https://live.france24.com/hls/live/2037218/F24_EN_HI_HLS/master_500.m3u8",
      image: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/France_24_logo.svg/200px-France_24_logo.svg.png",
      group: "News",
      favorite: true,
    );
    await addCustomChannel(
      name: "France 24 Español",
      url: "https://live.france24.com/hls/live/2037220-b/F24_ES_HI_HLS/master_5000.m3u8",
      image: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/France_24_logo.svg/200px-France_24_logo.svg.png",
      group: "News",
      favorite: true,
    );
    debugPrint("Test channels added successfully!");
  }

  static Future<void> favoriteChannel(int channelId, bool favorite) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE channels
      SET favorite = ?
      WHERE id = ?
    ''', [favorite ? 1 : 0, channelId]);
  }

  static Future<String?> getSetting(String key) async {
    var db = await DbFactory.db;
    var row = await db.getOptional(
        'SELECT value FROM settings WHERE key = ?', [key]);
    return row?.columnAt(0);
  }

  static Future<void> setSetting(String key, String value) =>
      updateSettings(HashMap.of({key: value}));

  static Future<HashMap<String, String>> getSettings() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''SELECT key, value FROM Settings''');
    return HashMap.fromEntries(
        results.map((f) => MapEntry(f.columnAt(0), f.columnAt(1))));
  }

  static Future<void> updateSettings(HashMap<String, String> settings) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      for (var entry in settings.entries) {
        await tx.execute('''
        INSERT INTO Settings (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = ?''',
            [entry.key, entry.value, entry.value]);
      }
    });
  }

  static Future<void> deleteSource(int sourceId) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      await tx.execute("DELETE FROM channels WHERE source_id = ?", [sourceId]);
      await tx.execute("DELETE FROM groups WHERE source_id = ?", [sourceId]);
      await tx.execute(
          "DELETE FROM user_playlist_items WHERE source_id = ?", [sourceId]);
      await tx.execute("DELETE FROM sources WHERE id = ?", [sourceId]);
    });
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      wipeSource(int sourceId) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute('''
        DELETE FROM channels 
        WHERE source_id = ? 
      ''', [sourceId]);
      await tx.execute('''
        DELETE FROM groups
        WHERE source_id = ?
      ''', [sourceId]);
    };
  }

  static Future<void> updateSource(Source source) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE sources
      SET url = ?, username = ?, password = ?
      WHERE id = ?
    ''', [source.url, source.username, source.password, source.id]);
  }

  static Future<Source> getSourceFromId(int id) async {
    var db = await DbFactory.db;
    var result = await db.get('''SELECT * FROM sources WHERE id = ?''', [id]);
    return rowToSource(result);
  }

  static Future<void> setSourceEnabled(bool enabled, int sourceId) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE sources 
      SET enabled = ? 
      WHERE id = ?
    ''', [enabled, sourceId]);
  }

  static Future setPosition(int channelId, int seconds) async {
    var db = await DbFactory.db;
    await db.execute('''
      INSERT INTO movie_positions (channel_id, position)
      VALUES (?, ?)
      ON CONFLICT (channel_id)
      DO UPDATE SET
      position = excluded.position;
    ''', [channelId, seconds]);
  }

  static Future<int?> getPosition(int channelId) async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
      SELECT position FROM movie_positions
      WHERE channel_id = ?
    ''', [channelId]);
    return result?.columnAt(0);
  }

  static Future<void> addToHistory(int id) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE channels
      SET last_watched = strftime('%s', 'now')
      WHERE id = ?
    ''', [id]);
    await db.execute('''
      UPDATE channels
      SET last_watched = NULL
      WHERE last_watched IS NOT NULL
		  AND id NOT IN (
				SELECT id 
				FROM channels
				WHERE last_watched IS NOT NULL
				ORDER BY last_watched DESC
				LIMIT 36
		  )
    ''');
  }

  static Future<List<ChannelPreserve>> getChannelsPreserve(int sourceId) async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT name, favorite, last_watched
      FROM channels
      WHERE (favorite = 1 OR last_watched IS NOT NULL) AND source_id = ?
    ''', [sourceId]);
    return results.map(rowToChannelPreserve).toList();
  }

  static ChannelPreserve rowToChannelPreserve(Row row) {
    return ChannelPreserve(
        name: row.columnAt(0),
        favorite: row.columnAt(1),
        lastWatched: row.columnAt(2));
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      restorePreserve(List<ChannelPreserve> preserve) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      final sourceId = int.parse(memory['sourceId']!);
      for (var channel in preserve) {
        await tx.execute('''
          UPDATE channels
          SET favorite = ?, last_watched = ?
          WHERE name = ?
          AND source_id = ?
        ''', [channel.favorite, channel.lastWatched, channel.name, sourceId]);
      }
    };
  }
}
