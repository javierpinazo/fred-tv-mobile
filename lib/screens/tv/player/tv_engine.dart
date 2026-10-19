import 'package:flutter/widgets.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';

/// Lo que un motor necesita para abrir un canal.
class TvMedia {
  const TvMedia({
    required this.url,
    required this.userAgent,
    this.headers = const {},
    this.start,
    this.bufferSecs = 2,
    this.hardwareDecoding = true,
    this.zeroCopy = false,
  });

  final String url;
  final String userAgent;

  /// Cabeceras extra (Referer, Origin…).
  final Map<String, String> headers;
  final Duration? start;

  /// Segundos de buffer (solo mpv; ExoPlayer usa el suyo).
  final int bufferSecs;

  /// Solo mpv.
  final bool hardwareDecoding;

  /// Solo mpv: decodificación sin copia (experimental).
  final bool zeroCopy;
}

/// Motor de reproducción detrás de `TvPlayer`: ExoPlayer o mpv.
abstract class TvEngine {
  TvEngineKind get kind;

  /// Emite cuando ya hay imagen.
  Stream<void> get firstFrame;
  Stream<String> get errors;
  Stream<bool> get completed;
  Stream<bool> get playing;

  Duration get position;
  Stream<Duration> get positionStream;
  Duration get duration;

  Future<void> open(TvMedia media);
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration to);

  /// Si permite elegir pista de audio / subtítulos.
  bool get supportsTracks;
  List<IdData<String>> audioTracks();
  List<IdData<String>> subtitleTracks();
  Future<void> selectAudio(int index);
  Future<void> selectSubtitle(int index);

  Widget buildVideo({required bool fill});

  Future<void> dispose();
}
