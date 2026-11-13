import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/screens/tv/player/hls_probe.dart';

/// Servidor local mínimo que sirve a ExoPlayer la lista maestra HLS corregida
/// de un canal cuyo `CODECS` declara solo video (ExoPlayer no crea entonces la
/// pista de audio). Solo se proxifica la lista maestra: las variantes y los
/// segmentos los pide ExoPlayer directamente al servidor original.
class HlsAudioFix {
  HlsAudioFix._(this._server, this.url);

  final HttpServer _server;

  /// URL local que debe abrir ExoPlayer.
  final String url;

  /// Cuánto se recuerda que un manifiesto no necesita la corrección. Caduca
  /// porque un canal puede cambiar su `CODECS` con el tiempo.
  static const Duration verdictTtl = Duration(minutes: 30);
  static const int _maxVerdicts = 500;

  // URL -> momento en que se comprobó que NO necesita corrección. Solo se
  // guarda tras una descarga correcta: un fallo de red nunca se recuerda.
  static final Map<String, DateTime> _noFixNeeded = {};

  @visibleForTesting
  static void debugClearVerdicts() => _noFixNeeded.clear();

  /// Devuelve `null` si el canal no necesita la corrección (o no se pudo
  /// descargar su lista): entonces se abre la URL original.
  static Future<HlsAudioFix?> prepare(
    String originUrl, {
    required String userAgent,
    Map<String, String> headers = const {},
    http.Client? client,
    DateTime Function() now = DateTime.now,
  }) async {
    final checked = _noFixNeeded[originUrl];
    if (checked != null && now().difference(checked) < verdictTtl) return null;
    final body = await fetchHlsMaster(originUrl,
        userAgent: userAgent, headers: headers, client: client);
    if (body == null) return null;
    if (!hlsDropsAudio(body)) {
      if (_noFixNeeded.length >= _maxVerdicts) _noFixNeeded.clear();
      _noFixNeeded[originUrl] = now();
      return null;
    }
    _noFixNeeded.remove(originUrl);

    final base = Uri.parse(originUrl);
    var fixed = hlsAddAudioCodec(body, base);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      // Se vuelve a pedir al origen por si la lista cambió (tokens, etc.); si
      // falla se sirve la última versión corregida.
      final fresh = await fetchHlsMaster(originUrl,
          userAgent: userAgent, headers: headers, client: client);
      if (fresh != null && hlsDropsAudio(fresh)) {
        fixed = hlsAddAudioCodec(fresh, base);
      }
      try {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType =
              ContentType('application', 'vnd.apple.mpegurl')
          ..write(fixed);
        await request.response.close();
      } catch (e) {
        debugPrint('HlsAudioFix: error sirviendo la lista: $e');
      }
    });
    return HlsAudioFix._(
        server, 'http://127.0.0.1:${server.port}/master.m3u8');
  }

  Future<void> close() => _server.close(force: true);
}
