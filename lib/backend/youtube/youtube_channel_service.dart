import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/backend/youtube/youtube_channel.dart';
import 'package:open_tv/backend/youtube/youtube_page_parser.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/backend/youtube/youtube_show.dart';

/// No se pudo leer ninguna de las pestañas del canal.
class YoutubeUnavailableException implements Exception {
  YoutubeUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'YoutubeUnavailableException: $message';
}

/// Une los vídeos subidos y los directos de un canal: los directos en curso
/// primero y después el resto del más reciente al más antiguo (los de
/// antigüedad desconocida, al final). El orden es estable y no repite vídeos.
List<YoutubeProgram> mergeYoutubePrograms(
    List<YoutubeProgram> videos, List<YoutubeProgram> streams) {
  final byId = <String, YoutubeProgram>{};
  for (final p in [...videos, ...streams]) {
    final seen = byId[p.videoId];
    if (seen == null || (p.isLive && !seen.isLive)) byId[p.videoId] = p;
  }
  final all = byId.values.toList();
  final live = [
    for (final p in all)
      if (p.isLive) p
  ];
  final rest = [
    for (final p in all)
      if (!p.isLive) p
  ];
  // `List.sort` no garantiza estabilidad: se desempata por la posición.
  final order = {for (var i = 0; i < rest.length; i++) rest[i]: i};
  rest.sort((a, b) {
    final x = a.age, y = b.age;
    if (x == null && y == null) return order[a]!.compareTo(order[b]!);
    if (x == null) return 1;
    if (y == null) return -1;
    final byAge = x.compareTo(y);
    return byAge != 0 ? byAge : order[a]!.compareTo(order[b]!);
  });
  return [...live, ...rest];
}

/// Lo que se muestra de un canal: todas sus emisiones recientes y las mismas
/// repartidas por programa.
class YoutubeChannelPage {
  const YoutubeChannelPage({required this.programs, required this.shows});

  /// Emisiones recientes mezcladas, ordenadas para mostrar.
  final List<YoutubeProgram> programs;

  /// Programas con al menos una emisión, sin ordenar para mostrar (eso
  /// depende del orden que haya elegido el usuario).
  final List<YoutubeShow> shows;
}

/// Descarga los programas de un canal de YouTube leyendo sus páginas
/// públicas (no hay servicio oficial sin clave para esto).
class YoutubeChannelService {
  YoutubeChannelService({
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
    this.retryDelay = const Duration(seconds: 1),
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  static const cacheTtl = Duration(minutes: 2);

  /// Listas que se leen, como mucho, cada vez que se carga un canal.
  static const maxPlaylistPages = 6;

  /// Emisiones que se guardan, como mucho, de cada programa.
  static const maxShowPrograms = 20;

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    'Accept-Language': 'es-419,es;q=0.9',
    // Evita la página de consentimiento de cookies.
    'Cookie': 'SOCS=CAI',
  };

  final http.Client _client;
  final DateTime Function() _clock;
  final Duration timeout;

  /// Espera antes de repetir una página que llegó sin datos.
  final Duration retryDelay;
  final Map<String, ({DateTime at, YoutubeChannelPage page})> _cache = {};

  /// Emisiones recientes del canal, ordenadas para mostrar.
  Future<List<YoutubeProgram>> programs(String channelUrl,
          {bool force = false}) async =>
      (await channelPage(channelUrl, force: force)).programs;

  /// Emisiones y programas del canal. [preferred] son las claves de los
  /// programas que más interesan (los que el usuario ordenó): sus listas se
  /// leen antes que las demás. Guarda el resultado 2 minutos ([force] lo
  /// ignora). Lanza [YoutubeUnavailableException] solo si no se pudo leer ni
  /// la pestaña de vídeos ni la de directos.
  Future<YoutubeChannelPage> channelPage(
    String channelUrl, {
    List<String> preferred = const [],
    bool force = false,
  }) async {
    final key = youtubeChannelKey(channelUrl);
    final cached = _cache[key];
    if (!force && cached != null && _clock().difference(cached.at) < cacheTtl) {
      return cached.page;
    }
    final tabs = Future.wait([
      _read(youtubeTabUri(channelUrl, YoutubeTab.videos), parseYoutubeTab),
      _read(youtubeTabUri(channelUrl, YoutubeTab.streams), parseYoutubeTab),
    ]);
    final playlistsRequest =
        _read(youtubePlaylistsUri(channelUrl), parseYoutubePlaylists);
    final results = await tabs;
    final playlists = await playlistsRequest;
    final videos = results[0], streams = results[1];
    if (videos == null && streams == null) {
      throw YoutubeUnavailableException('no se pudo leer $channelUrl');
    }
    final recent =
        mergeYoutubePrograms(videos ?? const [], streams ?? const []);
    final page = YoutubeChannelPage(
      programs: recent,
      shows: await _shows(
          youtubeShowDefs(key, playlists ?? const []), recent, preferred),
    );
    _cache[key] = (at: _clock(), page: page);
    return page;
  }

  /// Reparte [recent] entre los programas [defs] por el título y completa
  /// cada programa con las emisiones de sus listas.
  Future<List<YoutubeShow>> _shows(List<YoutubeShowDef> defs,
      List<YoutubeProgram> recent, List<String> preferred) async {
    if (defs.isEmpty) return const [];
    final keys = [for (final d in defs) d.key];
    final byTitle = {for (final k in keys) k: <YoutubeProgram>[]};
    final recentKeys = <String>[];
    for (final p in recent) {
      final k = youtubeShowKeyForTitle(p.title, keys);
      if (k == null) continue;
      byTitle[k]!.add(p);
      recentKeys.add(k);
    }

    // Orden de interés: lo que pide el usuario, luego los programas con
    // emisiones recientes (la más reciente primero: `recent` ya viene así) y
    // al final el resto, como los publica el canal.
    final interest = <String>{
      ...preferred.where(byTitle.containsKey),
      ...recentKeys,
      ...keys,
    };
    final byKey = {for (final d in defs) d.key: d};
    final wanted = <({String key, String id})>[];
    for (final k in interest) {
      for (final id in byKey[k]!.playlistIds) {
        if (wanted.length < maxPlaylistPages) wanted.add((key: k, id: id));
      }
    }
    final lists = await Future.wait([
      for (final w in wanted) _read(youtubePlaylistUri(w.id), parseYoutubeTab),
    ]);
    final fromLists = {for (final k in keys) k: <YoutubeProgram>[]};
    for (var i = 0; i < wanted.length; i++) {
      fromLists[wanted[i].key]!.addAll(lists[i] ?? const []);
    }

    // Que una emisión está en directo solo se sabe por las pestañas del
    // canal: si la lista la trae como vídeo, manda lo reciente.
    final live = {
      for (final p in recent)
        if (p.isLive) p.videoId: p
    };
    final shows = <YoutubeShow>[];
    for (final d in defs) {
      final merged = mergeYoutubePrograms(byTitle[d.key]!,
          [for (final p in fromLists[d.key]!) live[p.videoId] ?? p]);
      if (merged.isEmpty) continue;
      shows.add(YoutubeShow(
        key: d.key,
        name: d.name,
        programs: merged.length > maxShowPrograms
            ? merged.sublist(0, maxShowPrograms)
            : merged,
      ));
    }
    return shows;
  }

  /// Lo que [parse] saca de la página [uri], o `null` si no se pudo leer.
  /// YouTube devuelve a veces una página sin datos: se pide una segunda vez.
  Future<T?> _read<T>(Uri uri, T Function(String html) parse) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(retryDelay);
      try {
        final res = await _client.get(uri, headers: _headers).timeout(timeout);
        if (res.statusCode != 200) {
          debugPrint('YouTube: $uri respondió HTTP ${res.statusCode}');
          continue;
        }
        return parse(utf8.decode(res.bodyBytes, allowMalformed: true));
      } on TimeoutException catch (e) {
        // Repetir tras agotar el tiempo duplicaría la espera del usuario.
        debugPrint('YouTube: no se pudo leer $uri: $e');
        return null;
      } catch (e) {
        debugPrint('YouTube: no se pudo leer $uri: $e');
      }
    }
    return null;
  }
}
