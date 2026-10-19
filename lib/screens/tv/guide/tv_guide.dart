import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/models/channel.dart';

/// Lima no tiene horario de verano: siempre UTC-5.
const Duration _limaOffset = Duration(hours: 5);

class GuideException implements Exception {
  GuideException(this.message);
  final String message;

  @override
  String toString() => 'GuideException: $message';
}

/// Un programa de la guía. [start] es un instante UTC.
class GuideProgram {
  const GuideProgram({
    required this.start,
    required this.title,
    this.description,
  });

  final DateTime start;
  final String title;
  final String? description;

  /// Hora de inicio en Lima como `02:00 PM`.
  String get timeLabel => formatLimaTime(start);
}

/// Lo que se emite ahora y lo que viene después.
class GuideNowNext {
  const GuideNowNext({this.now, this.next});
  final GuideProgram? now;
  final GuideProgram? next;
}

/// `02:00 PM` para un instante, en hora de Lima.
String formatLimaTime(DateTime instant) {
  final l = instant.toUtc().subtract(_limaOffset);
  final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final mm = l.minute.toString().padLeft(2, '0');
  return '${h12.toString().padLeft(2, '0')}:$mm ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// Fecha (sin hora) de Lima para un instante UTC.
DateTime limaDay(DateTime nowUtc) {
  final l = nowUtc.toUtc().subtract(_limaOffset);
  return DateTime(l.year, l.month, l.day);
}

/// Programa actual y siguiente dentro de [day] (ordenado por hora de inicio).
GuideNowNext guideNowNext(List<GuideProgram> day, DateTime nowUtc) {
  GuideProgram? now;
  GuideProgram? next;
  for (final p in day) {
    if (!p.start.isAfter(nowUtc)) {
      now = p;
    } else {
      next = p;
      break;
    }
  }
  return GuideNowNext(now: now, next: next);
}

/// Fuente de guía para uno o varios canales.
abstract class GuideProvider {
  bool matches(Channel channel);

  /// Programas del día [limaDay] (fecha de Lima, sin hora). Lanza
  /// [GuideException] si no se pudo obtener.
  Future<List<GuideProgram>> day(DateTime limaDay);
}

/// Guía de varias fuentes: devuelve la del proveedor que reconoce el canal.
class TvGuide {
  TvGuide({List<GuideProvider>? providers})
      : providers = providers ?? [TvPeruGuide()];

  final List<GuideProvider> providers;

  GuideProvider? providerFor(Channel channel) {
    for (final p in providers) {
      if (p.matches(channel)) return p;
    }
    return null;
  }

  /// `null` si el canal no tiene guía o no se pudo cargar.
  Future<GuideNowNext?> nowNext(Channel channel, {DateTime? now}) async {
    final provider = providerFor(channel);
    if (provider == null) return null;
    final instant = (now ?? DateTime.now()).toUtc();
    try {
      return guideNowNext(await provider.day(limaDay(instant)), instant);
    } catch (e) {
      debugPrint('TvGuide: no se pudo cargar la guía de ${channel.name}: $e');
      return null;
    }
  }
}

// --- TV Perú ----------------------------------------------------------------

final RegExp _timeRe =
    RegExp(r'<h3>\s*(\d{1,2}):(\d{2})\s*(AM|PM)\.?\s*</h3>', caseSensitive: false);
final RegExp _titleRe =
    RegExp(r'<h3>(?:<a[^>]*>)?(.*?)(?:</a>)?</h3>', dotAll: true);
final RegExp _descRe = RegExp(r'<p>(.*?)(?:</br>|</p>|<a\s)', dotAll: true);

String _clean(String raw) {
  var s = raw.replaceAll(RegExp(r'<[^>]*>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('­', '')
      .replaceAllMapped(RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)))
      .replaceAll('&amp;', '&');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Lee la tabla de programación de https://www.tvperu.gob.pe/programacion para
/// el día [limaDay] (fecha de Lima, sin hora).
List<GuideProgram> parseTvPeruDay(String html, DateTime limaDay) {
  final start = html.indexOf('table-programacion');
  if (start < 0) return const [];
  final programs = <GuideProgram>[];
  for (final row in html.substring(start).split('<tr ').skip(1)) {
    final time = _timeRe.firstMatch(row);
    if (time == null) continue;
    final afterTime = row.substring(time.end);
    final title = _titleRe.firstMatch(afterTime);
    if (title == null) continue;
    final titleText = _clean(title.group(1)!);
    if (titleText.isEmpty) continue;
    final desc = _descRe.firstMatch(afterTime.substring(title.end));
    final descText = desc == null ? '' : _clean(desc.group(1)!);

    var hour = int.parse(time.group(1)!) % 12;
    if (time.group(3)!.toUpperCase() == 'PM') hour += 12;
    programs.add(GuideProgram(
      start: DateTime.utc(limaDay.year, limaDay.month, limaDay.day, hour,
              int.parse(time.group(2)!))
          .add(_limaOffset),
      title: titleText,
      description: descText.isEmpty ? null : descText,
    ));
  }
  programs.sort((a, b) => a.start.compareTo(b.start));
  return programs;
}

/// Nombre sin calidad, tildes ni signos, para comparar canales.
String _normalizeName(String name) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  var s = name.toLowerCase();
  s = s.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
  accents.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'[^a-z0-9ñ]+'), ' ');
  s = s.replaceAll(RegExp(r'\b(hd|sd|fhd|uhd)\b'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Guía de TV Perú desde la web oficial (semana completa, servida en el HTML).
class TvPeruGuide implements GuideProvider {
  TvPeruGuide({http.Client? client}) : _client = client;

  final http.Client? _client;
  final Map<String, ({DateTime fetched, List<GuideProgram> programs})> _cache =
      {};

  static const Duration _ttl = Duration(hours: 1);

  /// El sitio rechaza (403) los User-Agent que no parecen de navegador.
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 11; SmartTV) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  @override
  bool matches(Channel channel) {
    final n = _normalizeName(channel.name);
    return n == 'tv peru' || n == 'tvperu';
  }

  @override
  Future<List<GuideProgram>> day(DateTime limaDay) async {
    final key = '${limaDay.day.toString().padLeft(2, '0')}-'
        '${limaDay.month.toString().padLeft(2, '0')}-${limaDay.year}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.fetched) < _ttl) {
      return cached.programs;
    }
    final client = _client ?? http.Client();
    try {
      final res = await client
          .get(
            Uri.parse('https://www.tvperu.gob.pe/programacion?fecha=$key'),
            headers: const {
              'User-Agent': _userAgent,
              'Accept-Language': 'es-PE,es;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw GuideException('HTTP ${res.statusCode}');
      }
      final programs = parseTvPeruDay(res.body, limaDay);
      if (programs.isNotEmpty) {
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
