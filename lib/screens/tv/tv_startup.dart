import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

const int tvImageCacheBytes = 50 << 20;
const int tvImageCacheCount = 200;

/// La TV tiene poca RAM libre: la caché de imágenes (100 MB por defecto) se
/// acota para no competir con el decodificador de video.
void configureTvImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = tvImageCacheBytes;
  cache.maximumSize = tvImageCacheCount;
}

/// Recuadro discreto en lugar del rectángulo gris de un fallo de pintado.
Widget tvErrorWidget(FlutterErrorDetails details) => ColoredBox(
      color: TvTheme.surface,
      child: Center(
        child: Icon(Icons.error_outline, color: TvTheme.textSecondary, size: 28),
      ),
    );

/// Pinta los fallos de build con [tvErrorWidget] y deja en el log los errores
/// de Flutter y los no capturados.
void installTvErrorGuards() {
  ErrorWidget.builder = tvErrorWidget;
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint('FredTV: error de Flutter: ${details.exceptionAsString()}');
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('FredTV: error no capturado: $error\n$stack');
    return true;
  };
}
