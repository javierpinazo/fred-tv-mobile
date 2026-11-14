/// De dónde sale el vídeo de una película.
sealed class OnDemandSource {
  const OnDemandSource(this.videoId);
  final String videoId;
}

/// Vídeo alojado en Vimeo (`player.vimeo.com/video/<id>`).
class VimeoSource extends OnDemandSource {
  const VimeoSource(super.videoId);
}

/// Vídeo alojado en YouTube (`youtube.com/embed/<id>`).
class YoutubeSource extends OnDemandSource {
  const YoutubeSource(super.videoId);
}

/// Una película de un servicio on demand.
class OnDemandTitle {
  const OnDemandTitle({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.details,
    required this.source,
  });

  final String id;
  final String title;
  final String synopsis;
  final String posterUrl;

  /// Ficha corta, p. ej. «Largometraje ficción, 2018, 77 min.».
  final String details;
  final OnDemandSource source;
}

/// Un servicio de películas (Cineaparte, Pluto…).
abstract class OnDemandProvider {
  String get id;
  String get name;
  Future<List<OnDemandTitle>> titles();
}

/// No se pudo leer el catálogo del servicio (red caída o la web cambió).
class OnDemandUnavailableException implements Exception {
  OnDemandUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'OnDemandUnavailableException: $message';
}
