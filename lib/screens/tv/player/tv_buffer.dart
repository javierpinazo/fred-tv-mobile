/// Buffer de reproducción: cuántos segundos se acumulan antes de reproducir y
/// al recuperarse de un corte. Más segundos = menos tirones en canales pesados
/// (p. ej. 1080p), a cambio de empezar un poco más tarde.
abstract final class TvBuffer {
  static const List<int> options = [0, 2, 5, 10];
  static const int defaultSeconds = 2;

  /// Propiedades de mpv para [seconds] de buffer.
  static Map<String, String> mpvOptions(int seconds) {
    if (seconds <= 0) {
      return const {
        'cache': 'yes',
        'cache-pause': 'yes',
        'cache-pause-initial': 'no',
        'cache-pause-wait': '1',
      };
    }
    return {
      'cache': 'yes',
      'cache-pause': 'yes',
      'cache-pause-initial': 'yes',
      'cache-pause-wait': '$seconds',
      'demuxer-readahead-secs': '${seconds * 3}',
      'demuxer-max-bytes': '${64 * 1024 * 1024}',
    };
  }

  static String label(int seconds) =>
      seconds <= 0 ? 'Desactivado' : '$seconds s';

  /// Siguiente opción al pulsar OK (da la vuelta; un valor desconocido vuelve al
  /// valor por defecto).
  static int next(int current) {
    final i = options.indexOf(current);
    if (i < 0) return defaultSeconds;
    return options[(i + 1) % options.length];
  }
}
