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

/// Vídeo de Pluto TV: `videoId` es el `_id` del ítem; la URL se resuelve al
/// reproducir (ver [OnDemandResolver]).
class PlutoSource extends OnDemandSource {
  const PlutoSource(super.videoId);
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
    this.categories = const [],
  });

  final String id;
  final String title;
  final String synopsis;
  final String posterUrl;

  /// Ficha corta, p. ej. «Largometraje ficción, 2018, 77 min.».
  final String details;
  final OnDemandSource source;

  /// Categorías del servicio a las que pertenece (vacía si no las tiene).
  final List<String> categories;
}

/// Un servicio de películas (Cineaparte, Pluto…).
abstract class OnDemandProvider {
  String get id;
  String get name;
  Future<List<OnDemandTitle>> titles();
}

/// Vídeo directo (HLS/MP4) ya resuelto: URL y cabeceras para pedirlo.
class OnDemandStream {
  const OnDemandStream({required this.url, this.headers = const {}});

  final String url;
  final Map<String, String> headers;
}

/// Proveedores cuyas películas no traen la URL de vídeo en el catálogo: se
/// resuelve en el momento de verla (p. ej. porque lleva un token que caduca).
abstract interface class OnDemandResolver {
  Future<OnDemandStream> resolve(OnDemandTitle title);
}

/// No se pudo leer el catálogo del servicio (red caída o la web cambió).
class OnDemandUnavailableException implements Exception {
  OnDemandUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'OnDemandUnavailableException: $message';
}
