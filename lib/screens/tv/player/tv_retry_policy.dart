const String tvFallbackUserAgent = 'VLC/3.0.21 LibVLC/3.0.21';

class TvPlaybackAttempt {
  const TvPlaybackAttempt({required this.hardwareDecoding});

  final bool hardwareDecoding;
}

/// Política de reintentos: primero decodificación por hardware y, si no sale
/// ningún fotograma, por software; en directo se reconecta si el stream cae.
abstract final class TvRetryPolicy {
  static const List<TvPlaybackAttempt> attempts = [
    TvPlaybackAttempt(hardwareDecoding: true),
    TvPlaybackAttempt(hardwareDecoding: false),
  ];

  static const Duration firstFrameTimeout = Duration(seconds: 15);
  static const int maxLiveReconnects = 3;
  static const Duration reconnectDelay = Duration(seconds: 2);

  /// Intento siguiente al que acaba de fallar, o `null` si ya no quedan.
  static TvPlaybackAttempt? next(int failedAttemptIndex) {
    final i = failedAttemptIndex + 1;
    return i < attempts.length ? attempts[i] : null;
  }
}
