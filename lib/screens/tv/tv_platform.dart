import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Un elemento de la fila "Favoritos" de la pantalla de inicio de Android TV.
class TvHomeItem {
  const TvHomeItem({required this.title, required this.link, this.image});

  final String title;
  final String? image;

  /// Enlace `fredtv://play?…` que abre el canal.
  final String link;

  Map<String, String?> toMap() =>
      {'title': title, 'image': image, 'link': link};
}

/// Puente con la parte nativa de Android TV: enlaces entrantes (pantalla de
/// inicio, búsqueda del sistema) y publicación de la fila de favoritos. Todo
/// falla en silencio fuera de Android TV.
class TvPlatform {
  const TvPlatform();

  static const MethodChannel _channel = MethodChannel('dev.fredol.open_tv/tv');
  static final StreamController<String> _links = StreamController.broadcast();
  static bool _handlerInstalled = false;

  static void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        _links.add(call.arguments as String);
      }
    });
  }

  /// Enlace con el que se abrió la app, si lo hubo.
  Future<String?> initialLink() async {
    _installHandler();
    try {
      return await _channel.invokeMethod<String>('initialLink');
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('TvPlatform: error leyendo el enlace inicial: $e');
      return null;
    }
  }

  /// Enlaces recibidos con la app ya abierta.
  Stream<String> get links {
    _installHandler();
    return _links.stream;
  }

  /// Publica [items] como fila de la pantalla de inicio (lista vacía = la
  /// limpia).
  Future<void> publishFavorites(List<TvHomeItem> items) async {
    try {
      await _channel.invokeMethod<void>(
          'publishFavorites', items.map((i) => i.toMap()).toList());
    } on MissingPluginException {
      // Sin parte nativa (pruebas o plataforma no TV).
    } catch (e) {
      debugPrint('TvPlatform: no se pudo publicar la fila de inicio: $e');
    }
  }
}
