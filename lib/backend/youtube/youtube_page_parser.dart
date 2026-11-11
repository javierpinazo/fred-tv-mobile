import 'dart:convert';

import 'package:open_tv/backend/youtube/youtube_program.dart';

/// La página no trae los datos con la forma esperada (consentimiento, cambio
/// de formato de YouTube, descarga cortada…).
class YoutubeParseException implements Exception {
  YoutubeParseException(this.message);
  final String message;

  @override
  String toString() => 'YoutubeParseException: $message';
}

const _marker = 'var ytInitialData = ';
final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _duration = RegExp(r'^\d{1,3}(:\d{2}){1,2}$');
// «hace 16 h», «hace 2 sem.», «hace 3 m» (meses), «hace 1 a» (años).
final _ageEs = RegExp(
    r'^hace\s+(\d+)\s*(segundos?|seg|s|minutos?|min|horas?|h|días?|dias?|d|'
    r'semanas?|sem|meses|mes|m|años?|a)\.?$',
    caseSensitive: false);
// «16h ago», «1mo ago», «3 weeks ago».
final _ageEn = RegExp(
    r'^(\d+)\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|'
    r'weeks?|wks?|w|months?|mo|years?|yrs?|y)\s+ago$',
    caseSensitive: false);

/// Programas de una pestaña (`/videos` o `/streams`) de un canal, en el orden
/// de la página y sin los directos programados. No depende del idioma de la
/// página salvo para la antigüedad (español o inglés). Lanza [YoutubeParseException] si no trae `ytInitialData` válido.
List<YoutubeProgram> parseYoutubeTab(String html) {
  final data = _initialData(html);

  final programs = <YoutubeProgram>[];
  for (final lockup in _collect(data, 'lockupViewModel')) {
    final program = _program(lockup);
    if (program != null) programs.add(program);
  }
  return programs;
}

final _playlistId = RegExp(r'^PL[A-Za-z0-9_-]{8,}$');

/// Listas de un canal (pestaña `/playlists`), en el orden de la página y sin
/// repetir. Lanza [YoutubeParseException] si no trae `ytInitialData` válido.
List<({String id, String title})> parseYoutubePlaylists(String html) {
  final data = _initialData(html);
  final seen = <String>{};
  final playlists = <({String id, String title})>[];
  for (final lockup in _collect(data, 'lockupViewModel')) {
    if (lockup is! Map) continue;
    final id = lockup['contentId'];
    if (id is! String || !_playlistId.hasMatch(id)) continue;
    final title = _title(lockup);
    if (title == null || title.isEmpty || !seen.add(id)) continue;
    playlists.add((id: id, title: title));
  }
  return playlists;
}

/// El objeto `ytInitialData` incrustado en la página.
Map _initialData(String html) {
  final start = html.indexOf(_marker);
  if (start < 0) throw YoutubeParseException('la página no trae ytInitialData');
  final from = start + _marker.length;
  final end = html.indexOf(';</script>', from);
  if (end < 0) throw YoutubeParseException('ytInitialData está cortado');
  final Object? data;
  try {
    data = jsonDecode(html.substring(from, end));
  } on FormatException catch (e) {
    throw YoutubeParseException(
        'ytInitialData no es JSON válido: ${e.message}');
  }
  if (data is! Map) {
    throw YoutubeParseException('ytInitialData no es un objeto');
  }
  return data;
}

/// «hace 16 h», «Transmitido hace 1 día», «2 weeks ago»… → antigüedad
/// aproximada; `null` si [text] no es una antigüedad.
Duration? parseYoutubeAge(String text) {
  var t = text.trim();
  final lower = t.toLowerCase();
  for (final prefix in const ['transmitido ', 'streamed ']) {
    if (lower.startsWith(prefix)) t = t.substring(prefix.length).trim();
  }
  final es = _ageEs.firstMatch(t);
  if (es != null) {
    final n = int.parse(es.group(1)!);
    final unit = es.group(2)!.toLowerCase();
    if (unit.startsWith('min')) return Duration(minutes: n);
    if (unit.startsWith('sem')) return Duration(days: 7 * n);
    if (unit.startsWith('s')) return Duration(seconds: n);
    if (unit.startsWith('h')) return Duration(hours: n);
    if (unit.startsWith('d')) return Duration(days: n);
    if (unit.startsWith('m')) return Duration(days: 30 * n);
    return Duration(days: 365 * n);
  }
  final en = _ageEn.firstMatch(t);
  if (en == null) return null;
  final n = int.parse(en.group(1)!);
  final unit = en.group(2)!.toLowerCase();
  if (unit.startsWith('mo')) return Duration(days: 30 * n);
  return switch (unit[0]) {
    's' => Duration(seconds: n),
    'm' => Duration(minutes: n),
    'h' => Duration(hours: n),
    'd' => Duration(days: n),
    'w' => Duration(days: 7 * n),
    _ => Duration(days: 365 * n),
  };
}

YoutubeProgram? _program(Object? lockup) {
  if (lockup is! Map) return null;
  final id = lockup['contentId'];
  if (id is! String || !_videoId.hasMatch(id)) return null;
  final title = _title(lockup);
  if (title == null || title.isEmpty) return null;

  final badges = [
    for (final b in _collect(lockup['contentImage'], 'thumbnailBadgeViewModel'))
      if (b is Map) b
  ];
  final parts = <String>[
    for (final row in _collect(lockup['metadata'], 'metadataParts'))
      if (row is List)
        for (final part in row)
          if (part case {'text': {'content': final String content}}) content
  ];

  // Independiente del idioma: el estilo de la insignia marca el directo y
  // solo los vídeos ya disponibles llevan una insignia con forma de duración.
  final live = badges.any((b) => '${b['badgeStyle']}'.endsWith('_LIVE'));
  if (live) {
    return YoutubeProgram(
        videoId: id, title: title, kind: YoutubeProgramKind.live);
  }

  String? duration;
  for (final b in badges) {
    final text = b['text'];
    if (text is String && _duration.hasMatch(text)) {
      duration = text;
      break;
    }
  }
  // Sin duración: programado («Próximamente») o estreno pendiente.
  if (duration == null) return null;

  Duration? age;
  for (final p in parts) {
    age = parseYoutubeAge(p);
    if (age != null) break;
  }
  return YoutubeProgram(
    videoId: id,
    title: title,
    kind: YoutubeProgramKind.video,
    duration: duration,
    age: age,
  );
}

String? _title(Map lockup) {
  if (lockup['metadata']
      case {
        'lockupMetadataViewModel': {'title': {'content': final String t}}
      }) {
    return t.trim();
  }
  return null;
}

/// Todos los valores de la clave [key], a cualquier profundidad, en orden.
List<Object?> _collect(Object? node, String key) {
  final out = <Object?>[];
  void walk(Object? n) {
    if (n is Map) {
      n.forEach((k, v) {
        if (k == key) {
          out.add(v);
        } else {
          walk(v);
        }
      });
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(node);
  return out;
}
