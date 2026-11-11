enum YoutubeProgramKind { live, video }

/// Un programa de un canal de YouTube: un directo en curso o un vídeo (subido
/// o directo ya emitido).
class YoutubeProgram {
  const YoutubeProgram({
    required this.videoId,
    required this.title,
    required this.kind,
    this.duration,
    this.age,
  });

  final String videoId;
  final String title;
  final YoutubeProgramKind kind;

  /// Duración tal como la muestra YouTube («22:45»); `null` en los directos.
  final String? duration;

  /// Antigüedad aproximada; `null` en los directos o si no se pudo entender.
  final Duration? age;

  bool get isLive => kind == YoutubeProgramKind.live;

  String get thumbnail => 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
}
