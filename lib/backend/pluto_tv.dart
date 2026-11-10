import 'dart:convert';

/// Catálogo de canales en vivo de Pluto TV. La API responde con los canales de
/// la región de quien pregunta (Latinoamérica desde Perú, México, etc.).
const String plutoTvChannelsUrl = 'https://api.pluto.tv/v2/channels';

const String plutoTvSourceName = 'Pluto TV Latinoamérica';

/// Redirector que resuelve la sesión de cada canal; es el mismo que usan las
/// listas de iptv-org para Pluto TV.
const String _streamBase = 'https://jmp2.uk/plu-';

bool isPlutoTvChannelsUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null &&
      uri.host.toLowerCase() == 'api.pluto.tv' &&
      uri.path.replaceFirst(RegExp(r'/+$'), '') == '/v2/channels';
}

String _attr(String value) =>
    value.replaceAll('"', "'").replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

/// Convierte la respuesta de [plutoTvChannelsUrl] en una lista M3U, ordenada
/// por número de canal y agrupada por la categoría de Pluto TV.
String plutoTvChannelsToM3u(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    throw const FormatException('Respuesta inesperada de Pluto TV');
  }
  final channels = decoded
      .whereType<Map<String, dynamic>>()
      .where((c) =>
          c['_id'] is String &&
          c['name'] is String &&
          c['isStitched'] != false &&
          // El número 0 son duplicados ocultos de canales que ya tienen número.
          c['number'] is num &&
          (c['number'] as num) > 0)
      .toList()
    ..sort((a, b) => (a['number'] as num).compareTo(b['number'] as num));
  if (channels.isEmpty) {
    throw const FormatException('Pluto TV no devolvió canales');
  }
  final out = StringBuffer('#EXTM3U\n');
  for (final c in channels) {
    final name = _attr(c['name'] as String);
    final category = c['category'];
    final group = category is String && category.trim().isNotEmpty
        ? _attr(category)
        : 'Pluto TV';
    final logo = c['colorLogoPNG'] ?? c['logo'];
    final logoPath = logo is Map && logo['path'] is String
        ? _attr(logo['path'] as String)
        : '';
    out
      ..write('#EXTINF:-1 tvg-name="$name" tvg-logo="$logoPath" ')
      ..write('group-title="$group",$name\n')
      ..write('$_streamBase${c['_id']}.m3u8\n');
  }
  return out.toString();
}
