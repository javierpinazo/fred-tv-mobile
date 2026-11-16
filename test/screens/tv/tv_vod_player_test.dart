import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/screens/tv/ondemand/tv_vod_player.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';

import 'fakes.dart';

class FakeEngine implements TvEngine {
  final List<TvMedia> opened = [];
  final List<Duration> seeks = [];
  int toggles = 0;
  int pauses = 0;
  bool disposed = false;
  Object? openError;

  final _firstFrame = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();

  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(hours: 2);

  void frame() => _firstFrame.add(null);
  void error(String m) => _errors.add(m);
  void complete() => _completed.add(true);
  void setPlaying(bool p) => _playing.add(p);
  void tick(Duration p) {
    position = p;
    _position.add(p);
  }

  @override
  TvEngineKind get kind => TvEngineKind.exo;
  @override
  Stream<void> get firstFrame => _firstFrame.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Future<void> open(TvMedia media) async {
    opened.add(media);
    if (openError != null) throw openError!;
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> playOrPause() async => toggles++;
  @override
  Future<void> seek(Duration to) async {
    seeks.add(to);
    position = to;
  }

  @override
  Future<void> setMuted(bool muted) async {}
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
  Widget buildVideo({required bool fill}) =>
      const SizedBox.expand(key: ValueKey('vod-video'));

  @override
  Future<void> dispose() async => disposed = true;
}

const _stream = OnDemandStream(
    url: 'https://x/master.m3u8', headers: {'Authorization': 'Bearer t'});

Future<FakeEngine> _open(WidgetTester t,
    {Duration readyTimeout = const Duration(seconds: 20)}) async {
  final engine = FakeEngine();
  await pumpTvRoute(
    t,
    (_) => TvVodPlayer(
        stream: _stream,
        title: 'El último héroe',
        engine: engine,
        readyTimeout: readyTimeout),
  );
  return engine;
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.pump();
}

void main() {
  testWidgets('abre el medio con la URL, las cabeceras y el User-Agent',
      (t) async {
    final e = await _open(t);
    final m = e.opened.single;
    expect(m.url, _stream.url);
    expect(m.headers, _stream.headers);
    expect(m.userAgent, tvFallbackUserAgent);
  });

  testWidgets('carga hasta el primer fotograma y luego el vídeo', (t) async {
    final e = await _open(t);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    e.frame();
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('vod-video')), findsOneWidget);
  });

  testWidgets('OK alterna pausa; ←/→ saltan 10 s sin pasar de 0 ni del final',
      (t) async {
    final e = await _open(t);
    e.frame();
    e.duration = const Duration(seconds: 100);
    e.position = const Duration(seconds: 5);
    await t.pump();

    await _key(t, LogicalKeyboardKey.select);
    expect(e.toggles, 1);

    await _key(t, LogicalKeyboardKey.arrowLeft);
    expect(e.seeks.last, Duration.zero);

    e.position = const Duration(seconds: 95);
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(e.seeks.last, const Duration(seconds: 100));

    e.position = const Duration(seconds: 50);
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(e.seeks.last, const Duration(seconds: 60));
  });

  testWidgets('una tecla muestra posición/duración y se oculta a los 4 s',
      (t) async {
    final e = await _open(t);
    e.frame();
    e.duration = const Duration(hours: 2, minutes: 1, seconds: 5);
    e.tick(const Duration(minutes: 1, seconds: 22));
    await t.pump();
    expect(find.text('1:22 / 2:01:05'), findsNothing);

    await _key(t, LogicalKeyboardKey.select); // pausa: no cambia la posición
    expect(find.text('1:22 / 2:01:05'), findsOneWidget);

    await t.pump(const Duration(seconds: 5));
    expect(find.text('1:22 / 2:01:05'), findsNothing);
  });

  testWidgets('al terminar la película cierra la ruta y libera el motor',
      (t) async {
    final e = await _open(t);
    e.frame();
    await t.pump();
    e.complete();
    await t.pumpAndSettle();
    expect(find.byType(TvVodPlayer), findsNothing);
    expect(e.disposed, isTrue);
  });

  testWidgets('error del motor → fallo; «Reintentar» reabre; «Volver» cierra',
      (t) async {
    final e = await _open(t);
    e.frame();
    e.error('boom');
    await t.pump();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);

    await _key(t, LogicalKeyboardKey.select); // «Reintentar» con el foco
    await t.pump();
    expect(e.opened, hasLength(2));
    expect(find.text('Reintentar'), findsNothing);

    // Tras reintentar, el mando vuelve a manejar el reproductor.
    e.frame();
    await t.pump();
    await _key(t, LogicalKeyboardKey.select);
    expect(e.toggles, 1);

    e.error('otra vez');
    await t.pump();
    await t.pump(); // el foco pasa al aviso después del fotograma
    await _key(t, LogicalKeyboardKey.arrowRight); // «Reintentar» → «Volver»
    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.byType(TvVodPlayer), findsNothing);
  });

  testWidgets('si open lanza → pantalla de fallo', (t) async {
    final engine = FakeEngine()..openError = Exception('no abre');
    await pumpTvRoute(t, (_) => TvVodPlayer(stream: _stream, engine: engine));
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('20 s sin primer fotograma → fallo', (t) async {
    await _open(t, readyTimeout: const Duration(seconds: 3));
    await t.pump(const Duration(seconds: 4));
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Atrás libera el motor', (t) async {
    final e = await _open(t);
    e.frame();
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(TvVodPlayer), findsNothing);
    expect(e.disposed, isTrue);
  });

  testWidgets('I1: tras el tiempo de espera para el motor, y si el primer '
      'fotograma llega tarde lo vuelve a parar', (t) async {
    final e = await _open(t, readyTimeout: const Duration(seconds: 3));
    await t.pump(const Duration(seconds: 4));
    expect(find.text('Reintentar'), findsOneWidget);
    expect(e.pauses, greaterThanOrEqualTo(1));
    final before = e.pauses;

    e.frame(); // llega tarde, ya con el aviso en pantalla
    await t.pump();
    expect(e.pauses, greaterThan(before));
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('I3: «Reintentar» tras un corte retoma desde donde iba',
      (t) async {
    final e = await _open(t);
    expect(e.opened.first.start, isNull);
    e.frame();
    await t.pump();
    e.tick(const Duration(minutes: 90));
    await t.pump();
    e.error('corte del servidor');
    await t.pump();
    await t.pump();
    await _key(t, LogicalKeyboardKey.select); // «Reintentar»
    await t.pump();
    expect(e.opened, hasLength(2));
    expect(e.opened[1].start, const Duration(minutes: 90));
  });

  testWidgets('I3: si el corte fue en los primeros segundos no hay retoma',
      (t) async {
    final e = await _open(t);
    e.tick(const Duration(seconds: 3));
    e.error('corte');
    await t.pump();
    await t.pump();
    await _key(t, LogicalKeyboardKey.select);
    await t.pump();
    expect(e.opened[1].start, isNull);
  });
}
