import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';

final RegExp _plutoUrlRe = RegExp(
    r'^https?://(?:jmp2\.uk/plu-|[^/]*\.pluto\.tv/.*?/channel/)([0-9a-f]{24})\b',
    caseSensitive: false);

/// Id de Pluto TV del canal al que apunta [url] (el redirector `jmp2.uk/plu-…`
/// de las listas o una dirección directa de Pluto), o `null`.
String? plutoChannelId(String? url) =>
    url == null ? null : _plutoUrlRe.firstMatch(url.trim())?.group(1)?.toLowerCase();

String? _text(Object? v) {
  if (v is! String) return null;
  final s = v.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? null : s;
}

int? _positive(Object? v) => v is num && v > 0 ? v.toInt() : null;

List<String> _names(Object? v) =>
    v is List ? [for (final e in v) if (_text(e) != null) _text(e)!] : const [];

/// Programas de la respuesta de `api.pluto.tv/v2/channels/<id>?start=…&stop=…`,
/// ordenados por hora. Lanza [FormatException] si no es un canal.
List<GuideProgram> parsePlutoTimelines(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map || decoded['timelines'] is! List) {
    throw const FormatException('Respuesta inesperada de Pluto TV');
  }
  final programs = <GuideProgram>[];
  for (final t in (decoded['timelines'] as List).whereType<Map>()) {
    final start = DateTime.tryParse('${t['start']}')?.toUtc();
    final episode = t['episode'] is Map ? t['episode'] as Map : const {};
    final title = _text(t['title']) ?? _text(episode['name']);
    if (start == null || title == null) continue;
    final series = episode['series'] is Map ? episode['series'] as Map : const {};
    final clip = episode['clip'] is Map ? episode['clip'] as Map : const {};
    final type = series['type'];
    final episodeName = _text(episode['name']);
    // Los directos ("live") son series cuando el capítulo tiene título propio.
    final isSeries = type == 'tv' ||
        (type == 'live' && episodeName != null && episodeName != title);
    final kind = type == 'film'
        ? GuideProgramKind.movie
        : isSeries
            ? GuideProgramKind.series
            : null;
    final year = DateTime.tryParse('${clip['originalReleaseDate']}')?.toUtc().year;
    final rating = _text(episode['rating']);
    final poster = episode['poster'];
    programs.add(GuideProgram(
      start: start,
      end: DateTime.tryParse('${t['stop']}')?.toUtc(),
      title: title,
      description: _text(episode['description']),
      kind: kind,
      season: isSeries ? _positive(episode['season']) : null,
      episode: isSeries ? _positive(episode['number']) : null,
      episodeTitle: isSeries && episodeName != title ? episodeName : null,
      genre: _text(episode['genre']),
      rating: rating == null || rating.toLowerCase() == 'not rated' ? null : rating,
      // Pluto pone 1970 cuando no conoce la fecha.
      year: year != null && year > 1970 ? year : null,
      directors: _names(clip['directors']),
      actors: _names(clip['actors']),
      poster: poster is Map ? _text(poster['path']) : null,
    ));
  }
  programs.sort((a, b) => a.start.compareTo(b.start));
  return programs;
}

/// Guía de los canales de Pluto TV desde su propia API: se pide el día de cada
/// canal cuando hace falta (unos 20-40 KB) y se guarda una hora.
class PlutoGuide implements GuideProvider {
  PlutoGuide({http.Client? client}) : _client = client;

  final http.Client? _client;
  final Map<String, ({DateTime fetched, List<GuideProgram> programs})> _cache =
      {};

  static const Duration _ttl = Duration(hours: 1);
  static const int _maxCached = 60;

  @override
  bool matches(Channel channel) => plutoChannelId(channel.url) != null;

  @override
  Future<List<GuideProgram>> day(Channel channel, DateTime limaDay) async {
    final id = plutoChannelId(channel.url);
    if (id == null) throw GuideException('Sin guía para ${channel.name}');
    // El día de Lima va de las 05:00 UTC a las 05:00 UTC siguientes.
    final from = DateTime.utc(limaDay.year, limaDay.month, limaDay.day, 5);
    final to = from.add(const Duration(days: 1));
    final key = '$id|${from.toIso8601String()}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.fetched) < _ttl) {
      return cached.programs;
    }
    final client = _client ?? http.Client();
    try {
      final res = await client
          .get(Uri.https('api.pluto.tv', '/v2/channels/$id', {
            'start': from.toIso8601String(),
            'stop': to.toIso8601String(),
          }))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw GuideException('HTTP ${res.statusCode}');
      }
      final programs = parsePlutoTimelines(utf8.decode(res.bodyBytes))
          .where((p) => p.start.isBefore(to))
          .toList();
      if (programs.isNotEmpty) {
        if (_cache.length >= _maxCached) _cache.clear();
        _cache[key] = (fetched: DateTime.now(), programs: programs);
      }
      return programs;
    } on GuideException {
      rethrow;
    } catch (e) {
      throw GuideException('$e');
    } finally {
      if (_client == null) client.close();
    }
  }
}
