import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/exo_engine.dart';
import 'package:video_player/video_player.dart';

void main() {
  test('exoVideoLayoutChanged ignora posición y buffer', () {
    const a = VideoPlayerValue(
      duration: Duration(minutes: 1),
      size: Size(1920, 1080),
      isInitialized: true,
    );
    expect(
        exoVideoLayoutChanged(a, a.copyWith(position: const Duration(seconds: 5))),
        isFalse);
    expect(exoVideoLayoutChanged(a, a.copyWith(isBuffering: true)), isFalse);
    expect(exoVideoLayoutChanged(a, a.copyWith(size: const Size(1280, 720))),
        isTrue);
    expect(exoVideoLayoutChanged(a, a.copyWith(isInitialized: false)), isTrue);
    expect(exoVideoLayoutChanged(a, a.copyWith(rotationCorrection: 90)), isTrue);
  });

  testWidgets('positionStream emite cada 500 ms y no deja temporizadores',
      (t) async {
    final engine = ExoEngine();
    final seen = <Duration>[];
    final sub = engine.positionStream.listen(seen.add);
    await t.pump(const Duration(milliseconds: 1100));
    expect(seen, [Duration.zero, Duration.zero]);
    unawaited(sub.cancel());
    await t.pump();
    // Sin temporizador pendiente: testWidgets fallaría al terminar si quedara uno.
  });
}
