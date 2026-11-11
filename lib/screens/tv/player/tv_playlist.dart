import 'package:open_tv/models/channel.dart';

/// Cursor circular sobre la lista de canales para el zapping.
class TvPlaylistCursor {
  TvPlaylistCursor(List<Channel> channels, int index)
      : channels = List.of(channels),
        _index = index {
    if (channels.isEmpty) {
      throw ArgumentError('La lista de canales no puede estar vacía');
    }
    if (index < 0 || index >= channels.length) {
      throw ArgumentError.value(index, 'index', 'fuera de rango');
    }
  }

  /// Copia de la lista: [show] puede añadirle canales.
  final List<Channel> channels;
  int _index;
  int? _last;

  /// Posiciones de los canales añadidos con [show] (no están en la lista original).
  final List<int> _added = [];

  int get index => _index;
  Channel get current => channels[_index];

  /// Posición del canal actual en la lista original (sin contar los añadidos
  /// con [show]); si el actual es uno añadido, la del canal que le precede.
  int get baseIndex {
    final before = _added.where((i) => i < _index).length;
    return (_index - before - (_added.contains(_index) ? 1 : 0))
        .clamp(0, channels.length - _added.length - 1);
  }

  /// Si hay un canal visto antes del actual al que volver.
  bool get hasLast => _last != null;

  /// El canal visto justo antes del actual, o `null`.
  Channel? get last => _last == null ? null : channels[_last!];

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

  /// Pasa a [channel] (se busca por dirección): si no está en la lista, se
  /// añade justo después del actual.
  void show(Channel channel) {
    final found = channels.indexWhere((c) => c.url == channel.url);
    if (found >= 0) {
      _moveTo(found);
      return;
    }
    final at = _index + 1;
    channels.insert(at, channel);
    for (var i = 0; i < _added.length; i++) {
      if (_added[i] >= at) _added[i]++;
    }
    _added.add(at);
    _moveTo(at); // el canal anterior pasa a ser el actual de antes
  }

  String get positionLabel => '${_index + 1} / ${channels.length}';
}
