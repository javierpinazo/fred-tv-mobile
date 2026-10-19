import 'package:open_tv/models/channel.dart';

/// Cursor circular sobre la lista de canales para el zapping.
class TvPlaylistCursor {
  TvPlaylistCursor(this.channels, int index) : _index = index {
    if (channels.isEmpty) {
      throw ArgumentError('La lista de canales no puede estar vacía');
    }
    if (index < 0 || index >= channels.length) {
      throw ArgumentError.value(index, 'index', 'fuera de rango');
    }
  }

  final List<Channel> channels;
  int _index;
  int? _last;

  int get index => _index;
  Channel get current => channels[_index];

  /// Si hay un canal visto antes del actual al que volver.
  bool get hasLast => _last != null;

  void _moveTo(int index) {
    if (index == _index) return;
    _last = _index;
    _index = index;
  }

  /// Avanza o retrocede saltando los canales caídos; si todos los demás lo
  /// están, se queda donde está.
  void _step(int direction) {
    final n = channels.length;
    for (var i = 1; i < n; i++) {
      final candidate = (_index + direction * i % n + n) % n;
      if (!channels[candidate].dead) {
        _moveTo(candidate);
        return;
      }
    }
  }

  void next() => _step(1);

  void previous() => _step(-1);

  /// Salta al canal [number] (base 1). `false` si no existe.
  bool jumpTo(int number) {
    if (number < 1 || number > channels.length) return false;
    _moveTo(number - 1);
    return true;
  }

  /// Alterna con el canal visto justo antes. `false` si no hay ninguno.
  bool goToLast() {
    final last = _last;
    if (last == null) return false;
    _moveTo(last);
    return true;
  }

  String get positionLabel => '${_index + 1} / ${channels.length}';
}
