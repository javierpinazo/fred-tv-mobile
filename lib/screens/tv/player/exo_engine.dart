import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/screens/tv/player/hls_audio_fix.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Pista de formato para ExoPlayer según la URL (HLS/DASH/Smooth).
VideoFormat? exoFormatHint(String url) {
  final u = url.toLowerCase();
  if (u.contains('.m3u8')) return VideoFormat.hls;
  if (u.contains('.mpd')) return VideoFormat.dash;
  if (u.contains('.ism')) return VideoFormat.ss;
  return null;
}

/// Motor ExoPlayer (Media3) vía `video_player`: HLS/DASH nativo y decodificación
/// por hardware optimizada para Android. No permite elegir pistas.
class ExoEngine implements TvEngine {
  VideoPlayerController? _controller;
  HlsAudioFix? _fix;
  final ValueNotifier<int> _tick = ValueNotifier(0);

  final StreamController<void> _firstFrame = StreamController.broadcast();
  final StreamController<String> _errors = StreamController.broadcast();
  final StreamController<bool> _completed = StreamController.broadcast();
  final StreamController<bool> _playing = StreamController.broadcast();

  bool _errorSent = false;
  bool _completedSent = false;
  bool _lastPlaying = false;
  bool _disposed = false;

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
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Stream<Duration> get positionStream =>
      Stream<Duration>.periodic(const Duration(milliseconds: 500), (_) => position)
          .asBroadcastStream();

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  Future<void> _release() async {
    final old = _controller;
    _controller = null;
    _errorSent = false;
    _completedSent = false;
    _lastPlaying = false;
    if (old != null) {
      old.removeListener(_onValue);
      try {
        await old.dispose();
      } catch (e) {
        debugPrint('ExoEngine: error liberando el reproductor: $e');
      }
    }
    if (!_disposed) _tick.value++;
  }

  Future<void> _closeFix() async {
    final fix = _fix;
    _fix = null;
    await fix?.close();
  }

  @override
  Future<void> open(TvMedia media) async {
    await _release();
    await _closeFix();
    // HLS que declara solo video: se sirve la lista corregida en local para que
    // ExoPlayer cree la pista de audio.
    final fix = await HlsAudioFix.prepare(media.url,
        userAgent: media.userAgent, headers: media.headers);
    _fix = fix;
    if (fix != null) debugPrint('ExoEngine: lista HLS corregida (audio)');
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(fix?.url ?? media.url),
      formatHint: exoFormatHint(media.url),
      httpHeaders: {...media.headers, 'User-Agent': media.userAgent},
    );
    _controller = controller;
    controller.addListener(_onValue);
    try {
      await controller.initialize();
      if (_disposed || _controller != controller) return;
      if (media.start != null) await controller.seekTo(media.start!);
      await controller.play();
    } catch (e) {
      if (_controller == controller) {
        controller.removeListener(_onValue);
        _controller = null;
        unawaited(controller.dispose());
      }
      rethrow;
    }
    if (_disposed || _controller != controller) return;
    unawaited(WakelockPlus.enable());
    _tick.value++;
    _firstFrame.add(null);
  }

  void _onValue() {
    final c = _controller;
    if (c == null || _disposed) return;
    final v = c.value;
    if (v.hasError) {
      if (!_errorSent) {
        _errorSent = true;
        _errors.add(v.errorDescription ?? 'Error de ExoPlayer');
      }
      return;
    }
    if (v.isPlaying != _lastPlaying) {
      _lastPlaying = v.isPlaying;
      _playing.add(v.isPlaying);
    }
    if (v.isCompleted && !_completedSent) {
      _completedSent = true;
      _completed.add(true);
    }
    _tick.value++;
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> playOrPause() async {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? await c.pause() : await c.play();
  }

  @override
  Future<void> seek(Duration to) async => _controller?.seekTo(to);

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
  Widget buildVideo({required bool fill}) {
    return ValueListenableBuilder<int>(
      valueListenable: _tick,
      builder: (context, _, __) {
        final c = _controller;
        if (c == null || !c.value.isInitialized) return const SizedBox.expand();
        final size = c.value.size;
        if (fill && size.width > 0 && size.height > 0) {
          return ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          );
        }
        return Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
            child: VideoPlayer(c),
          ),
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await _release();
    await _closeFix();
    _disposed = true;
    unawaited(WakelockPlus.disable());
    _tick.dispose();
    await _firstFrame.close();
    await _errors.close();
    await _completed.close();
    await _playing.close();
  }
}
