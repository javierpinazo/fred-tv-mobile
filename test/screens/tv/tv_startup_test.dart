import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/tv_startup.dart';

import 'fakes.dart';

void main() {
  testWidgets('configureTvImageCache limita la caché de imágenes', (t) async {
    final cache = PaintingBinding.instance.imageCache;
    final bytes = cache.maximumSizeBytes, count = cache.maximumSize;
    addTearDown(() {
      cache.maximumSizeBytes = bytes;
      cache.maximumSize = count;
    });
    configureTvImageCache();
    expect(cache.maximumSizeBytes, 50 << 20);
    expect(cache.maximumSize, 200);
  });

  testWidgets('tvErrorWidget es un recuadro discreto, sin texto técnico',
      (t) async {
    await pumpTv(t, tvErrorWidget(FlutterErrorDetails(exception: 'boom')));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });
}
