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
    if (!_hasAudioCodec(codecs)) return true;
  }
  return false;
}

bool _hasAudioCodec(String codecs) =>
    codecs.split(',').any((c) => _audioCodec.hasMatch(c.trim()));

/// Códec de audio que se añade al `CODECS` para que ExoPlayer cree la pista.
/// Solo importa que haya audio declarado: el formato real lo detecta el
/// extractor al leer los segmentos.
const String hlsFallbackAudioCodec = 'mp4a.40.2';

/// Reescribe una lista maestra HLS: añade el códec de audio a las variantes que
/// solo declaran video y vuelve absolutas las URI (relativas a [base]) para que
/// ExoPlayer pida el video directamente al servidor original.
String hlsAddAudioCodec(String body, Uri base) {
  final out = <String>[];
  var nextIsUri = false;
  for (final raw in body.split('\n')) {
    final cr = raw.endsWith('\r');
    var line = cr ? raw.substring(0, raw.length - 1) : raw;
    if (line.startsWith('#EXT-X-STREAM-INF')) {
      line = line.replaceAllMapped(_codecsAttr, (m) {
        final codecs = m.group(1)!;
        return _hasAudioCodec(codecs)
            ? m.group(0)!
            : 'CODECS="$codecs,$hlsFallbackAudioCodec"';
      });
      nextIsUri = true;
    } else if (line.startsWith('#')) {
      line = _absolutizeUriAttrs(line, base);
    } else if (nextIsUri && line.trim().isNotEmpty) {
      line = base.resolve(line.trim()).toString();
      nextIsUri = false;
    }
    out.add(cr ? '$line\r' : line);
  }
  return out.join('\n');
}

String _absolutizeUriAttrs(String line, Uri base) =>
    line.replaceAllMapped(RegExp(r'URI="([^"]*)"'),
        (m) => 'URI="${base.resolve(m.group(1)!)}"');

/// Descarga la lista de [url] (solo `.m3u8`). Devuelve `null` ante cualquier
/// fallo: quien la pide decide qué hacer sin ella.
Future<String?> fetchHlsMaster(
  String url, {
  required String userAgent,
  Map<String, String> headers = const {},
  http.Client? client,
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (!url.toLowerCase().contains('.m3u8')) return null;
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.parse(url), headers: {...headers, 'User-Agent': userAgent})
        .timeout(timeout);
    return res.statusCode == 200 ? res.body : null;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
