// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/exo_engine.dart';
import 'package:open_tv/screens/tv/player/hls_audio_fix.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Plataforma de vídeo falsa: apunta qué reproductores se crearon y cuáles se
/// liberaron.
class FakeVideoPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  final List<int> created = [];
  final List<int> disposed = [];
  int _next = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = _next++;
    created.add(id);
    return id;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      create(options.dataSource);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 1),
        size: const Size(10, 10),
      ));

  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // WakelockPlus habla por un canal de plataforma que no existe en tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (message) async =>
                const StandardMessageCodec().encodeMessage(<Object?>[]));
  });

  test('I2: dispose mientras prepara el HLS no deja ningún reproductor vivo',
      () async {
    final platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    final gate = Completer<HlsAudioFix?>();
    final engine = ExoEngine(prepareFix: (_) => gate.future);

    final opening = engine.open(
        const TvMedia(url: 'https://x.invalid/a.m3u8', userAgent: 'ua'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await engine.dispose(); // el usuario pulsa Atrás mientras prepara
    gate.complete(null);
    await opening;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(platform.created.toSet().difference(platform.disposed.toSet()),
        isEmpty,
        reason: 'reproductores creados sin liberar: ${platform.created}');
  });

  test('I2: dispose después de crear el controlador también lo libera',
      () async {
    final platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    final engine = ExoEngine(prepareFix: (_) async => null);

    final opening = engine.open(
        const TvMedia(url: 'https://x.invalid/a.mp4', userAgent: 'ua'));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await engine.dispose();
    await opening;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(platform.created.toSet().difference(platform.disposed.toSet()),
        isEmpty);
  });
}
