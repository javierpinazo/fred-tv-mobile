import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/screens/tv/player/tv_camera.dart';
import 'package:open_tv/screens/tv/player/tv_camera_session.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';

/// Motor de mentira: registra lo que se abre y deja disparar los eventos.
class _FakeEngine implements TvEngine {
  final frame = StreamController<void>.broadcast();
  final error = StreamController<String>.broadcast();
  final done = StreamController<bool>.broadcast();
  final opened = <TvMedia>[];
  bool disposed = false;
  Duration pos = Duration.zero;
  Object? openError;

  @override
  TvEngineKind get kind => TvEngineKind.mpv;
  @override
  Stream<void> get firstFrame => frame.stream;
  @override
  Stream<String> get errors => error.stream;
  @override
  Stream<bool> get completed => done.stream;
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Duration get position => pos;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Duration get duration => Duration.zero;
  @override
  Future<void> open(TvMedia media) async {
    opened.add(media);
    if (openError != null) throw openError!;
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> playOrPause() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  bool get supportsTracks => false;
  @override
  List<IdData<String>> audioTracks() => const [];
  @override
  List<IdData<String>> subtitleTracks() => const [];
  @override
  Future<void> selectAudio(int index) async {}
  @override
  Future<void> selectSubtitle(int index) async {}
  @override
  Widget buildVideo({required bool fill}) => const SizedBox();
  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  const url = 'rtsp://192.168.1.20/stream1';
  late List<_FakeEngine> engines;
  late TvCameraSession session;

  setUp(() {
    engines = [];
    session = TvCameraSession(
      engineFactory: () {
        final e = _FakeEngine();
        engines.add(e);
        return e;
      },
      framePause: () async {},
      retryDelay: const Duration(milliseconds: 40),
      reconnectDelay: const Duration(milliseconds: 20),
    );
  });

  tearDown(() => session.dispose());

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test('mostrar abre la cámara sin audio, con poco buffer y por hardware',
      () async {
    await session.show(url);
    expect(session.visible, isTrue);
    expect(session.status, TvCameraStatus.connecting);
    final media = engines.single.opened.single;
    expect(media.url, url);
    expect(media.mute, isTrue);
    expect(media.bufferSecs, 0);
    expect(media.hardwareDecoding, isTrue);
    expect(session.url, url);
  });

  test('el primer fotograma la deja en directo', () async {
    await session.show(url);
    engines.single.frame.add(null);
    await settle();
    expect(session.status, TvCameraStatus.live);
  });

  test('ocultar libera el motor y quita el intercambio y el zoom', () async {
    await session.show(url);
    session
      ..toggleSwap()
      ..cycleZoom();
    expect(session.swapped, isTrue);
    expect(session.zoom.isZoomed, isTrue);
    await session.hide();
    expect(session.visible, isFalse);
    expect(session.swapped, isFalse);
    expect(session.zoom.isZoomed, isFalse);
    expect(engines.single.disposed, isTrue);
    expect(session.buildVideo(), isNull);
    expect(session.url, isNull);
  });

  test('intercambiar solo funciona con la cámara visible', () async {
    session.toggleSwap();
    expect(session.swapped, isFalse);
    await session.show(url);
    session.toggleSwap();
    expect(session.swapped, isTrue);
    session.toggleSwap();
    expect(session.swapped, isFalse);
  });

  test('el zoom cambia de nivel y mueve la imagen', () async {
    await session.show(url);
    session.panZoom(0.25, 0); // sin zoom no se mueve
    expect(session.zoom, TvCameraZoom.none);
    session.cycleZoom();
    session.panZoom(0.25, -0.25);
    expect((session.zoom.level, session.zoom.panX, session.zoom.panY),
        (2.0, 0.25, -0.25));
  });

  test('si el hardware no da imagen prueba por software', () async {
    await session.show(url);
    engines.single.error.add('no hay decodificador');
    await settle();
    expect(engines, hasLength(1)); // mismo motor, segundo intento
    expect(engines.single.opened.map((m) => m.hardwareDecoding),
        [true, false]);
    expect(session.status, TvCameraStatus.connecting);
  });

  test('sin intentos que probar queda sin señal y reintenta sola', () async {
    await session.show(url);
    engines.single.error.add('x'); // hardware falla
    await settle();
    engines.single.error.add('x'); // software falla
    await settle();
    expect(session.status, TvCameraStatus.error);
    expect(engines.first.disposed, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(engines, hasLength(2));
    expect(engines.last.opened.single.hardwareDecoding, isTrue);
    expect(session.status, TvCameraStatus.connecting);
  });

  test('un fallo al abrir cuenta como intento fallido', () async {
    final failing = TvCameraSession(
      engineFactory: () {
        final e = _FakeEngine()..openError = StateError('sin red');
        engines.add(e);
        return e;
      },
      framePause: () async {},
      retryDelay: const Duration(seconds: 5),
    );
    addTearDown(failing.dispose);
    await failing.show(url);
    await settle();
    expect(failing.status, TvCameraStatus.error);
    expect(engines.first.opened, hasLength(2)); // hardware y software
  });

  test('si el directo se cae se reconecta desde el principio', () async {
    await session.show(url);
    engines.single.frame.add(null);
    await settle();
    expect(session.status, TvCameraStatus.live);
    engines.single.done.add(true);
    await settle();
    expect(session.status, TvCameraStatus.error);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(engines, hasLength(2));
    expect(engines.last.opened.single.hardwareDecoding, isTrue);
  });

  test('retryNow reintenta sin esperar', () async {
    final slow = TvCameraSession(
      engineFactory: () {
        final e = _FakeEngine()..openError = StateError('sin red');
        engines.add(e);
        return e;
      },
      framePause: () async {},
      retryDelay: const Duration(minutes: 5),
    );
    addTearDown(slow.dispose);
    await slow.show(url);
    await settle();
    expect(slow.status, TvCameraStatus.error);
    await slow.retryNow();
    expect(engines, hasLength(2));
  });

  test('cerrar la sesión libera el motor', () async {
    final own = TvCameraSession(
      engineFactory: () {
        final e = _FakeEngine();
        engines.add(e);
        return e;
      },
      framePause: () async {},
    );
    await own.show(url);
    own.dispose();
    expect(engines.single.disposed, isTrue);
  });
}
