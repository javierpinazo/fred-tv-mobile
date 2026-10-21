import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/tv_camera.dart';

void main() {
  group('TvCameraZoom', () {
    test('empieza sin zoom y OK recorre 2x, 3x, 4x y vuelve a 1x', () {
      var z = TvCameraZoom.none;
      expect(z.isZoomed, isFalse);
      final labels = <String>[];
      for (var i = 0; i < 4; i++) {
        z = z.cycle();
        labels.add(z.label);
      }
      expect(labels, ['2x', '3x', '4x', '1x']);
      expect(z.isZoomed, isFalse);
    });

    test('sin zoom no hay nada que mover', () {
      expect(TvCameraZoom.none.panBy(1, 1), TvCameraZoom.none);
    });

    test('con zoom la imagen se mueve y no pasa de los bordes', () {
      var z = TvCameraZoom.none.cycle();
      z = z.panBy(TvCameraZoom.panStep, 0);
      expect((z.panX, z.panY), (TvCameraZoom.panStep, 0));
      for (var i = 0; i < 10; i++) {
        z = z.panBy(TvCameraZoom.panStep, -TvCameraZoom.panStep);
      }
      expect((z.panX, z.panY), (1.0, -1.0));
    });

    test('al volver a 1x se centra; subir de nivel conserva la zona', () {
      var z = TvCameraZoom.none.cycle().panBy(0.5, -0.5);
      z = z.cycle();
      expect((z.level, z.panX, z.panY), (3.0, 0.5, -0.5));
      z = z.cycle().cycle();
      expect(z, TvCameraZoom.none);
    });

    test('la transformación deja a la vista la zona elegida', () {
      // Puntos relativos al centro de un área de 400 × 200. A 2x con la
      // imagen pegada a la derecha, el borde derecho del contenido queda en el
      // borde derecho del área y el izquierdo se sale por completo.
      const z = TvCameraZoom(level: 2, panX: 1, panY: 0);
      final m = z.transform(400, 200);
      expect(MatrixUtils.transformPoint(m, const Offset(200, 0)),
          const Offset(200, 0));
      expect(MatrixUtils.transformPoint(m, const Offset(-200, 0)).dx,
          lessThan(-200));
      // Centrada, el zoom solo agranda desde el centro.
      final c = const TvCameraZoom(level: 2).transform(400, 200);
      expect(MatrixUtils.transformPoint(c, const Offset(100, 50)),
          const Offset(200, 100));
    });
  });

  testWidgets('TvCameraZoomView sin zoom no envuelve el contenido', (t) async {
    const child = SizedBox(key: ValueKey('c'), width: 10, height: 10);
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: TvCameraZoomView(zoom: TvCameraZoom.none, child: child),
    ));
    expect(find.byType(Transform), findsNothing);
    await t.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: TvCameraZoomView(zoom: TvCameraZoom(level: 2), child: child),
    ));
    expect(find.byType(ClipRect), findsOneWidget);
    expect(find.byKey(const ValueKey('c')), findsOneWidget);
  });
}
