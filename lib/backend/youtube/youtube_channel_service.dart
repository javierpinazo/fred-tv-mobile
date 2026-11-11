import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/backend/youtube/youtube_channel.dart';
import 'package:open_tv/backend/youtube/youtube_page_parser.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';

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

/// Descarga los programas de un canal de YouTube leyendo sus páginas
/// públicas (no hay servicio oficial sin clave para esto).
class YoutubeChannelService {
  YoutubeChannelService({
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  static const cacheTtl = Duration(minutes: 2);

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
  final Map<String, ({DateTime at, List<YoutubeProgram> programs})> _cache =
      {};

  /// Programas del canal, ordenados para mostrar. Guarda el resultado 2
  /// minutos ([force] lo ignora). Lanza [YoutubeUnavailableException] solo si
  /// fallan las dos pestañas.
  Future<List<YoutubeProgram>> programs(String channelUrl,
      {bool force = false}) async {
    final key = youtubeTabUri(channelUrl, YoutubeTab.videos).path;
    final cached = _cache[key];
    if (!force &&
        cached != null &&
        _clock().difference(cached.at) < cacheTtl) {
      return cached.programs;
    }
    final results = await Future.wait([
      _tab(channelUrl, YoutubeTab.videos),
      _tab(channelUrl, YoutubeTab.streams),
    ]);
    final videos = results[0], streams = results[1];
    if (videos == null && streams == null) {
      throw YoutubeUnavailableException('no se pudo leer $channelUrl');
    }
    final merged = mergeYoutubePrograms(videos ?? const [], streams ?? const []);
    _cache[key] = (at: _clock(), programs: merged);
    return merged;
  }

  /// Programas de una pestaña, o `null` si no se pudo leer.
  Future<List<YoutubeProgram>?> _tab(String channelUrl, YoutubeTab tab) async {
    final uri = youtubeTabUri(channelUrl, tab);
    try {
      final res = await _client.get(uri, headers: _headers).timeout(timeout);
      if (res.statusCode != 200) {
        debugPrint('YouTube: $uri respondió HTTP ${res.statusCode}');
        return null;
      }
      return parseYoutubeTab(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (e) {
      debugPrint('YouTube: no se pudo leer $uri: $e');
      return null;
    }
  }
}
