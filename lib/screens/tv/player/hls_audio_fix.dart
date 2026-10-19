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

  /// Devuelve `null` si el canal no necesita la corrección (o no se pudo
  /// descargar su lista): entonces se abre la URL original.
  static Future<HlsAudioFix?> prepare(
    String originUrl, {
    required String userAgent,
    Map<String, String> headers = const {},
    http.Client? client,
  }) async {
    final body = await fetchHlsMaster(originUrl,
        userAgent: userAgent, headers: headers, client: client);
    if (body == null || !hlsDropsAudio(body)) return null;

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
