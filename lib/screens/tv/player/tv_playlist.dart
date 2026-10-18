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

  int get index => _index;
  Channel get current => channels[_index];

  void next() => _index = (_index + 1) % channels.length;

  void previous() => _index = (_index - 1 + channels.length) % channels.length;

  String get positionLabel => '${_index + 1} / ${channels.length}';
}
