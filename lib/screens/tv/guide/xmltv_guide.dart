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
///
/// Con [onlyIds] solo se conservan esos canales (para tomar uno o dos de un
/// archivo grande sin guardar el resto).
XmltvData parseXmltv(String xml, {Set<String>? onlyIds}) {
  final data = XmltvData();
  for (final m in _channelRe.allMatches(xml)) {
    final id = cleanHtmlText(m.group(1)!);
    if (onlyIds != null && !onlyIds.contains(id)) continue;
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
    if (onlyIds != null && !onlyIds.contains(cleanHtmlText(channel))) continue;
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

/// Descomprime (si es gzip), decodifica y lee un XMLTV. Pensada para
/// ejecutarse en otro isolate: los archivos grandes tardan.
XmltvData parseXmltvBytes(({Uint8List bytes, Set<String>? onlyIds}) input) {
  var bytes = input.bytes;
  if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    bytes = Uint8List.fromList(gzip.decode(bytes));
  }
  return parseXmltv(utf8.decode(bytes, allowMalformed: true),
      onlyIds: input.onlyIds);
}

typedef XmltvParser = Future<XmltvData> Function(
    Uint8List bytes, Set<String>? onlyIds);

/// Guía de un canal concreto tomada de un XMLTV que no es el de su país (por
/// ejemplo DW en español: el XMLTV de Alemania solo trae la señal en inglés).
class XmltvExtra {
  const XmltvExtra({
    required this.url,
    required this.xmltvId,
    this.tvgIds = const [],
    this.names = const [],
  });

  final String url;

  /// Id del canal dentro de ese XMLTV.
  final String xmltvId;

  /// `tvg-id` de iptv-org que identifican el canal.
  final List<String> tvgIds;

  /// Grupos de palabras: el canal vale si su nombre contiene todas las de
  /// alguno (sin tildes ni ñ: `{'dw', 'espanol'}`).
  final List<Set<String>> names;

  bool matches(Channel channel) {
    final tvgId = channel.tvgId?.toLowerCase();
    if (tvgId != null && tvgIds.any((t) => t.toLowerCase() == tvgId)) {
      return true;
    }
    final tokens = normalizeChannelName(channel.name)
        .replaceAll('ñ', 'n')
        .split(' ')
        .toSet();
    return names.any(tokens.containsAll);
  }
}

const String _epgUruguay =
    'https://epgshare01.online/epgshare01/epg_ripper_UY1.xml.gz';

/// Canales internacionales en español cuya guía solo viene bien en el XMLTV de
/// Uruguay.
const List<XmltvExtra> defaultXmltvExtras = [
  XmltvExtra(
    url: _epgUruguay,
    xmltvId: 'DW.ESPAÑOL.HD.uy',
    tvgIds: ['DW.de@Espanol'],
    names: [
      {'dw', 'espanol'},
      {'dw', 'spanish'},
      {'dw', 'latinoamerica'},
    ],
  ),
  XmltvExtra(
    url: _epgUruguay,
    xmltvId: 'FRANCE.24.ESPAÑOL.HD.uy',
    tvgIds: ['France24.fr@Spanish'],
    names: [
      {'france', '24', 'espanol'},
      {'france', '24', 'spanish'},
      {'france24', 'espanol'},
      {'france24', 'spanish'},
    ],
  ),
];

/// Guía desde uno o varios XMLTV (por ejemplo los de epgshare01 por país).
/// La lista se descarga y se indexa con [load]; hasta entonces no reconoce
/// ningún canal.
class XmltvGuide implements GuideProvider {
  XmltvGuide({
    required this.urls,
    this.extras = const [],
    http.Client? client,
    XmltvParser? parser,
    this.ttl = const Duration(hours: 6),
    this.maxBytes = 25 * 1024 * 1024,
  })  : _client = client,
        _parser = parser ??
            ((bytes, onlyIds) => compute(
                parseXmltvBytes, (bytes: bytes, onlyIds: onlyIds)));

  /// Direcciones a descargar (se consultan en cada recarga).
  final Future<List<String>> Function() urls;

  /// Guías de canales sueltos que se toman de otros XMLTV.
  final List<XmltvExtra> extras;
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
    // De un XMLTV que solo se baja por las guías extra se toman esos canales
    // y nada más (`null` = el archivo entero).
    final jobs = <String, Set<String>?>{for (final url in list) url: null};
    for (final e in extras) {
      if (list.contains(e.url)) continue;
      (jobs[e.url] ??= <String>{}).add(e.xmltvId);
    }
    final client = _client ?? http.Client();
    try {
      for (final MapEntry(key: url, value: onlyIds) in jobs.entries) {
        try {
          final streamed = await client
              .send(http.Request('GET', Uri.parse(url)))
              .timeout(const Duration(seconds: 60));
          if (streamed.statusCode != 200) continue;
          if ((streamed.contentLength ?? 0) > maxBytes) {
            debugPrint('XmltvGuide: $url pesa demasiado, se omite');
            continue;
          }
          final data =
              await _parser(await streamed.stream.toBytes(), onlyIds);
          // Los canales de las guías extra no entran en el índice por nombre.
          if (onlyIds == null) merged.names.addAll(data.names);
          merged.programs.addAll(data.programs);
          anyOk = true;
        } catch (e) {
          debugPrint('XmltvGuide: no se pudo cargar $url: $e');
        }
      }
    } finally {
      if (_client == null) client.close();
    }
    if (jobs.isEmpty || anyOk) {
      _data = merged;
      _index = XmltvIndex(merged.names, onlyIds: merged.programs.keys.toSet());
      _matchCache.clear();
      _loadedAt = DateTime.now();
    }
  }

  String? _idFor(Channel channel) => _matchCache.putIfAbsent(
      '${channel.tvgId ?? ''}|${channel.name}', () {
        if (_index == null) return null;
        for (final e in extras) {
          if (_data.programs.containsKey(e.xmltvId) && e.matches(channel)) {
            return e.xmltvId;
          }
        }
        return _index!.match(channel.name);
      });

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
