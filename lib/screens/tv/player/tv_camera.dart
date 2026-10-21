import 'package:flutter/widgets.dart';

/// Nombre del canal manual que apunta a la cámara.
const String tvCameraChannelName = 'Cámara';

/// Zoom digital de la cámara: nivel de aumento y a qué zona se mira.
@immutable
class TvCameraZoom {
  const TvCameraZoom({this.level = 1, this.panX = 0, this.panY = 0});

  static const List<double> levels = [1, 2, 3, 4];
  static const double panStep = 0.25;
  static const TvCameraZoom none = TvCameraZoom();

  final double level;

  /// Desplazamiento de -1 (borde izquierdo / superior) a 1 (derecho / inferior).
  final double panX;
  final double panY;

  bool get isZoomed => level > 1;

  String get label => '${level.toStringAsFixed(0)}x';

  /// Siguiente nivel; tras el último vuelve a 1x y centra la imagen.
  TvCameraZoom cycle() {
    final i = levels.indexOf(level);
    final next = levels[(i + 1) % levels.length];
    return next == 1 ? none : TvCameraZoom(level: next, panX: panX, panY: panY);
  }

  /// Mueve la zona vista; sin zoom no hay nada que mover.
  TvCameraZoom panBy(double dx, double dy) {
    if (!isZoomed) return this;
    return TvCameraZoom(
      level: level,
      panX: (panX + dx).clamp(-1.0, 1.0),
      panY: (panY + dy).clamp(-1.0, 1.0),
    );
  }

  /// Transformación sobre un área de [width] × [height], aplicada desde el
  /// centro: amplía y desplaza para dejar a la vista la zona elegida.
  Matrix4 transform(double width, double height) {
    final tx = -panX * (level - 1) / 2 * width;
    final ty = -panY * (level - 1) / 2 * height;
    return Matrix4.translationValues(tx, ty, 0) *
        Matrix4.diagonal3Values(level, level, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is TvCameraZoom &&
      other.level == level &&
      other.panX == panX &&
      other.panY == panY;

  @override
  int get hashCode => Object.hash(level, panX, panY);
}

/// Aplica [zoom] a [child] recortando lo que se sale del área.
class TvCameraZoomView extends StatelessWidget {
  const TvCameraZoomView({super.key, required this.zoom, required this.child});

  final TvCameraZoom zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!zoom.isZoomed) return child;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, box) => Transform(
          alignment: Alignment.center,
          transform: zoom.transform(box.maxWidth, box.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
