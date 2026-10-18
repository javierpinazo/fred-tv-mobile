import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/tv_playlist.dart';

import '../fakes.dart';

void main() {
  test('next y previous dan la vuelta', () {
    final c = TvPlaylistCursor(
        [fakeChannel(1), fakeChannel(2), fakeChannel(3)], 2);
    expect(c.current.id, 3);
    c.next();
    expect(c.index, 0);
    expect(c.current.id, 1);
    c.previous();
    expect(c.index, 2);
    expect(c.positionLabel, '3 / 3');
  });

  test('lista vacía o índice fuera de rango lanza ArgumentError', () {
    expect(() => TvPlaylistCursor([], 0), throwsArgumentError);
    expect(() => TvPlaylistCursor([fakeChannel(1)], 1), throwsArgumentError);
    expect(() => TvPlaylistCursor([fakeChannel(1)], -1), throwsArgumentError);
  });
}
