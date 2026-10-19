import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';

/// Canales y programas de un XMLTV, por id de canal.
class XmltvData {
  XmltvData({Map<String, List<String>>? names, Map<String, List<GuideProgram>>? programs})
      : names = names ?? {},
        programs = programs ?? {};

  final Map<String, List<String>> names;
  final Map<String, List<GuideProgram>> programs;
}

final RegExp _channelRe =
    RegExp(r'<channel\s+id="([^"]*)"[^>]*>(.*?)</channel>', dotAll: true);
final RegExp _displayNameRe =
    RegExp(r'<display-name[^>]*>([^<]*)</display-name>');
final RegExp _programmeRe =
    RegExp(r'<programme\s+([^>]*)>(.*?)</programme>', dotAll: true);
final RegExp _startRe = RegExp(r'start="([^"]*)"');
final RegExp _stopRe = RegExp(r'stop="([^"]*)"');
final RegExp _channelAttrRe = RegExp(r'channel="([^"]*)"');
final RegExp _titleRe = RegExp(r'<title[^>]*>([^<]*)</title>');
final RegExp _descRe = RegExp(r'<desc[^>]*>([^<]*)</desc>');
final RegExp _xmltvTimeRe = RegExp(r'^(\d{14})(?:\s*([+-])(\d{2})(\d{2}))?');

/// `20261019010000 +0000` → instante UTC.
DateTime? _parseXmltvTime(String? raw) {
  final m = raw == null ? null : _xmltvTimeRe.firstMatch(raw.trim());
  if (m == null) return null;
  final t = m.group(1)!;
  var utc = DateTime.utc(
    int.parse(t.substring(0, 4)),
    int.parse(t.substring(4, 6)),
    int.parse(t.substring(6, 8)),
    int.parse(t.substring(8, 10)),
    int.parse(t.substring(10, 12)),
    int.parse(t.substring(12, 14)),
  );
  if (m.group(2) != null) {
    final offset = Duration(
        hours: int.parse(m.group(3)!), minutes: int.parse(m.group(4)!));
    // La hora local es UTC + desfase: para volver a UTC se resta.
    utc = m.group(2) == '+' ? utc.subtract(offset) : utc.add(offset);
  }
  return utc;
}

/// Lee un XMLTV (sin dependencias de XML: las listas son regulares y pueden ser
/// grandes, así que se recorren con expresiones regulares).
XmltvData parseXmltv(String xml) {
  final data = XmltvData();
  for (final m in _channelRe.allMatches(xml)) {
    final id = cleanHtmlText(m.group(1)!);
    final names = [
      for (final n in _displayNameRe.allMatches(m.group(2)!))
        if (cleanHtmlText(n.group(1)!).isNotEmpty) cleanHtmlText(n.group(1)!)
    ];
    if (names.isNotEmpty) data.names[id] = names;
  }
  for (final m in _programmeRe.allMatches(xml)) {
    final attrs = m.group(1)!;
    final start = _parseXmltvTime(_startRe.firstMatch(attrs)?.group(1));
    final channel = _channelAttrRe.firstMatch(attrs)?.group(1);
    final body = m.group(2)!;
    final title = _titleRe.firstMatch(body)?.group(1);
    if (start == null || channel == null || title == null) continue;
    final titleText = cleanHtmlText(title);
    if (titleText.isEmpty) continue;
    final desc = cleanHtmlText(_descRe.firstMatch(body)?.group(1) ?? '');
    (data.programs[cleanHtmlText(channel)] ??= []).add(GuideProgram(
      start: start,
      end: _parseXmltvTime(_stopRe.firstMatch(attrs)?.group(1)),
      title: titleText,
      description: desc.isEmpty ? null : desc,
    ));
  }
  for (final list in data.programs.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return data;
}

/// Palabras que pueden sobrar en el nombre de un canal de iptv-org sin que sea
/// otra versión del canal (la guía es de Perú / Latinoamérica).
const Set<String> _fillerTokens = {
  'latin', 'america', 'latinoamerica', 'latam', 'tv', 'television', 'channel',
  'canal', 'peru', 'pe', 'hd', 'sd', 'fhd', 'uhd',
};

final RegExp _qualityRe = RegExp(r'^\s*\d{3,4}p\s*$|^\s*not 24/7\s*$|^\s*geo-blocked\s*$', caseSensitive: false);

/// `false` si algún paréntesis del nombre indica otra región (por ejemplo
/// "(United States)"); la calidad "(1080p)" y "(Peru)" no cuentan.
bool _parenthesesAreCompatible(String name) {
  for (final m in RegExp(r'\(([^)]*)\)').allMatches(name)) {
    final text = m.group(1)!;
    if (_qualityRe.hasMatch(text)) continue;
    final tokens = normalizeChannelName(text).split(' ').where((t) => t.isNotEmpty);
    if (!tokens.every(_fillerTokens.contains)) return false;
  }
  return true;
}

/// Empareja nombres de canal de iptv-org con los de un XMLTV.
class XmltvIndex {
  /// [onlyIds] limita el índice a los canales que tienen datos (no tiene
  /// sentido ofrecer una guía vacía).
  XmltvIndex(Map<String, List<String>> names, {Set<String>? onlyIds}) {
    names.forEach((id, list) {
      if (onlyIds != null && !onlyIds.contains(id)) return;
      for (final name in list) {
        // "NOMBRE (ALIAS)": se prueban las dos partes.
        final outer = name.replaceAll(RegExp(r'\([^)]*\)'), ' ');
        final inner = RegExp(r'\(([^)]*)\)').firstMatch(name)?.group(1);
        for (final variant in [outer, if (inner != null) inner]) {
          final norm = normalizeChannelName(variant);
          if (norm.isEmpty) continue;
          _entries.add((id: id, norm: norm, tokens: norm.split(' ').toSet()));
        }
      }
    });
  }

  final List<({String id, String norm, Set<String> tokens})> _entries = [];

  /// Id del XMLTV para [channelName], o `null`. Idéntico gana siempre; si no,
  /// vale un nombre de al menos 2 palabras contenido en el del canal (el más
  /// largo gana).
  String? match(String channelName) {
    final norm = normalizeChannelName(channelName);
    if (norm.isEmpty || !_parenthesesAreCompatible(channelName)) return null;
    final tokens = norm.split(' ').toSet();
    String? best;
    var bestScore = 0;
    for (final e in _entries) {
      int score;
      if (e.norm == norm) {
        score = 1000;
      } else if (e.tokens.length >= 2 &&
          e.tokens.every(tokens.contains) &&
          tokens.difference(e.tokens).every(_fillerTokens.contains)) {
        // Solo sobran palabras de relleno: es el mismo canal.
        score = e.tokens.length;
      } else {
        continue;
      }
      if (score > bestScore) {
        bestScore = score;
        best = e.id;
      }
    }
    return best;
  }
}

typedef XmltvParser = Future<XmltvData> Function(String text);

/// Guía desde uno o varios XMLTV (por ejemplo los de epgshare01 por país).
/// La lista se descarga y se indexa con [load]; hasta entonces no reconoce
/// ningún canal.
class XmltvGuide implements GuideProvider {
  XmltvGuide({
    required this.urls,
    http.Client? client,
    XmltvParser? parser,
    this.ttl = const Duration(hours: 6),
    this.maxBytes = 25 * 1024 * 1024,
  })  : _client = client,
        _parser = parser ?? ((text) => compute(parseXmltv, text));

  /// Direcciones a descargar (se consultan en cada recarga).
  final Future<List<String>> Function() urls;
  final http.Client? _client;
  final XmltvParser _parser;
  final Duration ttl;

  /// Tamaño máximo (comprimido) de cada XMLTV.
  final int maxBytes;

  XmltvData _data = XmltvData();
  XmltvIndex? _index;
  DateTime? _loadedAt;
  Future<void>? _loading;
  final Map<String, String?> _matchCache = {};

  bool get isLoaded => _index != null;

  Future<void> load({bool force = false}) {
    final at = _loadedAt;
    if (!force && at != null && DateTime.now().difference(at) < ttl) {
      return Future.value();
    }
    return _loading ??= _doLoad().whenComplete(() => _loading = null);
  }

  Future<void> _doLoad() async {
    final merged = XmltvData();
    var anyOk = false;
    final list = await urls();
    final client = _client ?? http.Client();
    try {
      for (final url in list) {
        try {
          final streamed = await client
              .send(http.Request('GET', Uri.parse(url)))
              .timeout(const Duration(seconds: 60));
          if (streamed.statusCode != 200) continue;
          if ((streamed.contentLength ?? 0) > maxBytes) {
            debugPrint('XmltvGuide: $url pesa demasiado, se omite');
            continue;
          }
          var bytes = await streamed.stream.toBytes();
          if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
            bytes = Uint8List.fromList(gzip.decode(bytes));
          }
          final data = await _parser(utf8.decode(bytes, allowMalformed: true));
          merged.names.addAll(data.names);
          merged.programs.addAll(data.programs);
          anyOk = true;
        } catch (e) {
          debugPrint('XmltvGuide: no se pudo cargar $url: $e');
        }
      }
    } finally {
      if (_client == null) client.close();
    }
    if (list.isEmpty || anyOk) {
      _data = merged;
      _index = XmltvIndex(merged.names, onlyIds: merged.programs.keys.toSet());
      _matchCache.clear();
      _loadedAt = DateTime.now();
    }
  }

  String? _idFor(Channel channel) =>
      _matchCache.putIfAbsent(channel.name, () => _index?.match(channel.name));

  @override
  bool matches(Channel channel) => _idFor(channel) != null;

  @override
  Future<List<GuideProgram>> day(Channel channel, DateTime limaDay) async {
    await load();
    final id = _idFor(channel);
    final all = id == null ? null : _data.programs[id];
    if (all == null) throw GuideException('Sin guía para ${channel.name}');
    // El día de Lima va de las 05:00 UTC a las 05:00 UTC siguientes.
    final from = DateTime.utc(limaDay.year, limaDay.month, limaDay.day, 5);
    final to = from.add(const Duration(days: 1));
    final result = <GuideProgram>[];
    GuideProgram? carryOver;
    for (final p in all) {
      if (p.start.isBefore(from)) {
        if (p.end != null && p.end!.isAfter(from)) carryOver = p;
      } else if (p.start.isBefore(to)) {
        result.add(p);
      }
    }
    return [if (carryOver != null) carryOver, ...result];
  }
}
