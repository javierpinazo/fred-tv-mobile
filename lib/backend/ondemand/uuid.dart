import 'dart:math';

/// UUID v4 aleatorio (identificador de cliente para las sesiones anónimas de
/// Pluto TV y Plex).
String newUuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int from, int to) => [
        for (var i = from; i < to; i++) b[i].toRadixString(16).padLeft(2, '0')
      ].join();
  return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
}
