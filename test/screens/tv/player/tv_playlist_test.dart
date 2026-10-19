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

  test('jumpTo salta a un número de canal (base 1) y valida el rango', () {
    final c = TvPlaylistCursor(
        [fakeChannel(1), fakeChannel(2), fakeChannel(3)], 0);
    expect(c.jumpTo(3), isTrue);
    expect(c.current.id, 3);
    expect(c.jumpTo(0), isFalse);
    expect(c.jumpTo(4), isFalse);
    expect(c.current.id, 3);
  });

  test('goToLast alterna entre los dos últimos canales vistos', () {
    final c = TvPlaylistCursor(
        [fakeChannel(1), fakeChannel(2), fakeChannel(3)], 0);
    expect(c.hasLast, isFalse);
    expect(c.goToLast(), isFalse);
    c.next(); // 2
    c.next(); // 3
    expect(c.hasLast, isTrue);
    expect(c.goToLast(), isTrue);
    expect(c.current.id, 2);
    expect(c.goToLast(), isTrue);
    expect(c.current.id, 3);
    c.jumpTo(1);
    expect(c.goToLast(), isTrue);
    expect(c.current.id, 3);
  });

  test('saltar al mismo canal no cambia el canal anterior', () {
    final c = TvPlaylistCursor(
        [fakeChannel(1), fakeChannel(2), fakeChannel(3)], 0);
    c.next();
    c.jumpTo(2); // ya está en el 2
    expect(c.goToLast(), isTrue);
    expect(c.current.id, 1);
  });

  test('lista vacía o índice fuera de rango lanza ArgumentError', () {
    expect(() => TvPlaylistCursor([], 0), throwsArgumentError);
    expect(() => TvPlaylistCursor([fakeChannel(1)], 1), throwsArgumentError);
    expect(() => TvPlaylistCursor([fakeChannel(1)], -1), throwsArgumentError);
  });
}
