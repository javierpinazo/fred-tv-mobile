import 'package:http/http.dart' as http;

final RegExp _codecsAttr = RegExp(r'CODECS="([^"]*)"');
final RegExp _audioCodec =
    RegExp(r'^(mp4a|ac-3|ec-3|ac-4|opus|flac|mp3|dtsc|dtse|dtsh|dtsl)');

/// `true` si ExoPlayer se quedaría sin audio con esta lista maestra HLS.
///
/// Cuando `CODECS` declara solo video (p. ej. `avc1.640029`) y el audio no
/// viene en un grupo `EXT-X-MEDIA`, Media3 no crea la pista de audio aunque el
/// stream sí la lleve. Sin `CODECS` sí sondea el stream y funciona.
bool hlsDropsAudio(String body) {
  if (!body.contains('#EXT-X-STREAM-INF')) return false;
  if (RegExp(r'#EXT-X-MEDIA:[^\n]*TYPE=AUDIO').hasMatch(body)) return false;
  for (final line in body.split('\n')) {
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
    final codecs = _codecsAttr.firstMatch(line)?.group(1);
    if (codecs == null) continue;
    final hasAudio =
        codecs.split(',').any((c) => _audioCodec.hasMatch(c.trim()));
    if (!hasAudio) return true;
  }
  return false;
}

/// Descarga la lista maestra de [url] (solo `.m3u8`) y decide si ExoPlayer
/// perdería el audio. Ante cualquier fallo devuelve `false`: no bloquea a
/// ExoPlayer, que tiene su propio respaldo.
Future<bool> exoWouldDropAudio(
  String url, {
  required String userAgent,
  Map<String, String> headers = const {},
  http.Client? client,
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (!url.toLowerCase().contains('.m3u8')) return false;
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.parse(url), headers: {...headers, 'User-Agent': userAgent})
        .timeout(timeout);
    if (res.statusCode != 200) return false;
    return hlsDropsAudio(res.body);
  } catch (_) {
    return false;
  } finally {
    if (client == null) c.close();
  }
}
