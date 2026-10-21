import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/screens/tv/player/tv_buffer.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';

/// Valor de `hwdec` de mpv: automático (`mediacodec-copy` en esta TV), sin copia
/// (`mediacodec`, experimental) o por software.
String mpvHwdecFor({required bool zeroCopy, required bool hardwareDecoding}) {
  if (!hardwareDecoding) return 'no';
  return zeroCopy ? 'mediacodec' : 'auto-safe';
}

/// Opciones de mpv según la URL. En HLS se desactivan las conexiones
/// persistentes: algunos servidores las cierran y el demuxer da el directo por
/// terminado al recargar la lista (el canal se reiniciaba cada ~8 s).
Map<String, String> mpvUrlOptions(String url) {
  final u = url.trimLeft().toLowerCase();
  if (u.contains('.m3u8')) return const {'demuxer-lavf-o': 'http_persistent=0'};
  // RTSP por TCP: por UDP el wifi pierde paquetes y la imagen se ensucia.
  if (u.startsWith('rtsp://') || u.startsWith('rtsps://')) {
    return const {'demuxer-lavf-o': 'rtsp_transport=tcp'};
  }
  return const {};
}

/// Motor mpv (FFmpeg) vía media_kit: el más compatible con streams raros.
class MpvEngine implements TvEngine {
  MpvEngine() : _player = mk.Player() {
    _video = VideoController(_player);
  }

  final mk.Player _player;
  late final VideoController _video;

  @override
  TvEngineKind get kind => TvEngineKind.mpv;

  @override
  Stream<void> get firstFrame =>
      _player.stream.width.where((w) => w != null && w > 0).map((_) {});

  @override
  Stream<String> get errors => _player.stream.error;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Duration get position => _player.state.position;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  Future<void> open(TvMedia media) async {
    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      await platform.setProperty(
          'hwdec',
          mpvHwdecFor(
              zeroCopy: media.zeroCopy,
              hardwareDecoding: media.hardwareDecoding));
      await platform.setProperty('network-timeout', '15');
      await platform.setProperty('mute', media.mute ? 'yes' : 'no');
      for (final e in TvBuffer.mpvOptions(media.bufferSecs).entries) {
        await platform.setProperty(e.key, e.value);
      }
      for (final e in mpvUrlOptions(media.url).entries) {
        await platform.setProperty(e.key, e.value);
      }
    }
    await _player.open(
      mk.Media(
        media.url,
        start: media.start,
        httpHeaders: {...media.headers, 'User-Agent': media.userAgent},
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
  bool get supportsTracks => true;

  @override
  List<IdData<String>> audioTracks() => _player.state.tracks.audio
      .asMap()
      .entries
      .map((e) => IdData(
          id: e.key,
          data: e.value.title ?? e.value.language ?? e.value.id))
      .toList();

  @override
  List<IdData<String>> subtitleTracks() => _player.state.tracks.subtitle
      .asMap()
      .entries
      .map((e) => IdData(
          id: e.key,
          data: e.value.language != null
              ? '${e.value.language} - ${e.value.id}'
              : e.value.id))
      .toList();

  @override
  Future<void> selectAudio(int index) =>
      _player.setAudioTrack(_player.state.tracks.audio[index]);

  @override
  Future<void> selectSubtitle(int index) =>
      _player.setSubtitleTrack(_player.state.tracks.subtitle[index]);

  @override
  Widget buildVideo({required bool fill}) => Video(
        controller: _video,
        controls: NoVideoControls,
        fit: fill ? BoxFit.cover : BoxFit.contain,
        wakelock: true,
      );

  @override
  Future<void> dispose() async {
    // Fotogramas perdidos de la sesión: sirve para comparar modos de decodificación.
    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      try {
        final dropped = await platform.getProperty('frame-drop-count');
        final decoderDropped =
            await platform.getProperty('decoder-frame-drop-count');
        debugPrint('MpvEngine: fotogramas perdidos vo=$dropped '
            'decodificador=$decoderDropped');
      } catch (_) {}
    }
    await _player.dispose();
  }
}
