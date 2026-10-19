const String tvFallbackUserAgent = 'VLC/3.0.21 LibVLC/3.0.21';

/// Motor de reproducción.
enum TvEngineKind {
  exo,
  mpv;

  String get label => this == exo ? 'ExoPlayer' : 'mpv';
}

/// Ajuste del usuario: qué motor usar.
enum TvEngineMode {
  /// ExoPlayer primero y mpv de respaldo.
  auto,

  /// Solo mpv (el más compatible con streams raros).
  mpv;

  String get label => this == auto ? 'Automático' : 'Solo mpv';

  TvEngineMode get next => this == auto ? mpv : auto;

  static TvEngineMode fromName(String? name) =>
      name == 'mpv' ? TvEngineMode.mpv : TvEngineMode.auto;
}

class TvPlaybackAttempt {
  const TvPlaybackAttempt({required this.engine, this.hardwareDecoding = true});

  final TvEngineKind engine;

  /// Solo aplica a mpv.
  final bool hardwareDecoding;
}

/// Política de reproducción: ExoPlayer primero (HLS/DASH/progresivo por
/// http/https) y mpv de respaldo, primero con decodificación por hardware y
/// luego por software. En directo se reconecta si el stream cae.
abstract final class TvRetryPolicy {
  static const int maxLiveReconnects = 3;
  static const Duration reconnectDelay = Duration(seconds: 2);

  static const TvPlaybackAttempt _exo =
      TvPlaybackAttempt(engine: TvEngineKind.exo);
  static const TvPlaybackAttempt _mpvHw =
      TvPlaybackAttempt(engine: TvEngineKind.mpv);
  static const TvPlaybackAttempt _mpvSw =
      TvPlaybackAttempt(engine: TvEngineKind.mpv, hardwareDecoding: false);

  /// ExoPlayer solo se usa con http/https; el resto (rtmp, udp, rtsp, mms,
  /// srt, rutas locales…) va directo a mpv.
  static bool exoCanOpen(String url) {
    final u = url.trimLeft().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  /// Intentos para [url]. [prefer] fuerza el motor para este canal (p. ej. el
  /// usuario elige "Usar mpv" en las opciones del reproductor).
  static List<TvPlaybackAttempt> plan(
    String url, {
    TvEngineMode mode = TvEngineMode.auto,
    TvEngineKind? prefer,
  }) {
    final wantsExo = prefer != null
        ? prefer == TvEngineKind.exo
        : mode == TvEngineMode.auto;
    if (wantsExo && exoCanOpen(url)) return const [_exo, _mpvHw, _mpvSw];
    return const [_mpvHw, _mpvSw];
  }

  /// Intento siguiente al que acaba de fallar, o `null` si ya no quedan.
  static TvPlaybackAttempt? next(
      List<TvPlaybackAttempt> plan, int failedIndex) {
    final i = failedIndex + 1;
    return i < plan.length ? plan[i] : null;
  }

  /// Tiempo máximo hasta el primer fotograma antes de pasar al siguiente
  /// intento. ExoPlayer falla rápido; mpv necesita más margen.
  static Duration firstFrameTimeout(TvPlaybackAttempt attempt) =>
      attempt.engine == TvEngineKind.exo
          ? const Duration(seconds: 10)
          : const Duration(seconds: 15);
}
