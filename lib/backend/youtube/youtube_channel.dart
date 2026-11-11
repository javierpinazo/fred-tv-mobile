/// Pestañas de un canal de YouTube de las que se leen programas.
enum YoutubeTab { videos, streams }

const _hosts = {'youtube.com', 'www.youtube.com', 'm.youtube.com'};

/// Ruta del canal (`/channel/UC…` o `/@handle`), o `null` si [url] no es la
/// dirección de un canal de YouTube.
String? _channelPath(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  if (!_hosts.contains(uri.host.toLowerCase())) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final first = segments.first;
  if (first.startsWith('@')) {
    return first.length > 1 ? '/$first' : null;
  }
  if (first == 'channel' &&
      segments.length > 1 &&
      segments[1].startsWith('UC') &&
      segments[1].length > 2) {
    return '/channel/${segments[1]}';
  }
  return null;
}

/// Si [url] es la dirección de un canal de YouTube (no la de un vídeo suelto).
bool isYoutubeChannelUrl(String? url) => _channelPath(url) != null;

/// Dirección de la pestaña [tab] del canal, pedida en español: en inglés
/// YouTube traduce los títulos de los vídeos.
Uri youtubeTabUri(String channelUrl, YoutubeTab tab) {
  final path = _channelPath(channelUrl);
  if (path == null) {
    throw ArgumentError.value(
        channelUrl, 'channelUrl', 'no es un canal de YouTube');
  }
  return Uri.https('www.youtube.com', '$path/${tab.name}', {'hl': 'es'});
}
