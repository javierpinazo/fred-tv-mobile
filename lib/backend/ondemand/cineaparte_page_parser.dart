import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

final _vimeo = RegExp(r'player\.vimeo\.com/video/(\d+)');
final _youtube =
    RegExp(r'(?:www\.)?youtube\.com/embed/([A-Za-z0-9_-]{11})');
final _iframeSrc = RegExp(r'''src=['"]([^'"]+)['"]''');
final _unicode = RegExp(r'\\u([0-9a-fA-F]{4})');
final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|quot|apos|lt|gt|nbsp);');

/// Entidades HTML que trae la portada dentro de los textos (`&amp;`, `&#039;`).
String _decodeEntities(String text) => text.replaceAllMapped(_entity, (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x')) {
        return String.fromCharCode(int.parse(e.substring(2), radix: 16));
      }
      if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
      return const {
        'amp': '&',
        'quot': '"',
        'apos': "'",
        'lt': '<',
        'gt': '>',
        'nbsp': ' ',
      }[e]!;
    });

/// Valor de cada `aTodo<nombre>.push(...)` de la portada, en orden. Los
/// valores son literales JS entre comillas dobles o números; la portada no
/// cierra todas las líneas con `;`, así que no se depende de eso.
List<String> _column(String html, String name) {
  final re = RegExp(
      'aTodo$name\\.push\\(\\s*("(?:[^"\\\\]|\\\\.)*"|-?\\d+)\\s*\\)');
  return [
    for (final m in re.allMatches(html)) _unescape(m.group(1)!),
  ];
}

String _unescape(String raw) {
  if (!raw.startsWith('"')) return raw;
  final body = raw.substring(1, raw.length - 1);
  return body
      .replaceAllMapped(_unicode,
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
      .replaceAllMapped(RegExp(r'\\(.)'), (m) {
    final c = m.group(1)!;
    return switch (c) {
      'n' => '\n',
      't' => '\t',
      _ => c, // \" \' \\ \/
    };
  });
}

OnDemandSource? _sourceOf(String embed) {
  final src = _iframeSrc.firstMatch(embed)?.group(1);
  if (src == null) return null;
  final v = _vimeo.firstMatch(src)?.group(1);
  if (v != null) return VimeoSource(v);
  final y = _youtube.firstMatch(src)?.group(1);
  if (y != null) return YoutubeSource(y);
  return null;
}

/// Se excluye solo «Disponible en todo el mundo excepto …» que nombre PE.
bool _availableInPeru(String text) {
  final m = RegExp('todo el mundo excepto(.*)', caseSensitive: false)
      .firstMatch(text);
  if (m == null) return true;
  return !RegExp(r'\bPE\b').hasMatch(m.group(1)!);
}

/// Películas gratuitas de la portada de Cineaparte: las de acceso libre
/// (`aTodoAccesoVOD == 1`) cuyo vídeo está en Vimeo o YouTube. Las alojadas
/// en el propio Cineaparte piden sesión y se descartan.
///
/// Lanza [OnDemandUnavailableException] si la página no trae el catálogo.
List<OnDemandTitle> parseCineapartePage(String html) {
  final ids = _column(html, 'Ids');
  final titles = _column(html, 'Titulo');
  if (ids.isEmpty || titles.isEmpty) {
    throw OnDemandUnavailableException(
        'La portada de Cineaparte no trae el catálogo.');
  }
  final posters = _column(html, 'AficheURL');
  final frames = _column(html, 'FotogramaURL');
  final synopses = _column(html, 'SinopsisCortada');
  final details = _column(html, 'Tipo');
  final available = _column(html, 'Disponible');
  final vod = _column(html, 'AccesoVOD');
  final embeds = _column(html, 'VideoEmbedURL');
  if (vod.isEmpty || embeds.isEmpty) {
    throw OnDemandUnavailableException(
        'La portada de Cineaparte cambió: faltan los vídeos.');
  }

  final n = [
    ids.length,
    titles.length,
    posters.length,
    synopses.length,
    details.length,
    available.length,
    vod.length,
    embeds.length,
  ].reduce((a, b) => a < b ? a : b);

  final out = <OnDemandTitle>[];
  for (var i = 0; i < n; i++) {
    if (vod[i] != '1' || !_availableInPeru(available[i])) continue;
    final source = _sourceOf(embeds[i]);
    if (source == null) continue;
    out.add(OnDemandTitle(
      id: ids[i],
      title: _decodeEntities(titles[i]),
      synopsis: _decodeEntities(synopses[i]),
      // El fotograma es opcional: sin cartel se usa si la portada lo trae.
      posterUrl: posters[i].isNotEmpty
          ? posters[i]
          : (i < frames.length ? frames[i] : ''),
      details: _decodeEntities(details[i]),
      source: source,
    ));
  }
  return out;
}
