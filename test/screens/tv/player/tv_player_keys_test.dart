import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/tv_player_keys.dart';

TvPlayerCommand _live(LogicalKeyboardKey k) =>
    mapTvPlayerKey(k, isLive: true);
TvPlayerCommand _vod(LogicalKeyboardKey k) =>
    mapTvPlayerKey(k, isLive: false);

void main() {
  test('los dígitos del control (y del teclado numérico) se reconocen', () {
    expect(digitForKey(LogicalKeyboardKey.digit0), 0);
    expect(digitForKey(LogicalKeyboardKey.digit7), 7);
    expect(digitForKey(LogicalKeyboardKey.numpad3), 3);
    expect(digitForKey(LogicalKeyboardKey.keyA), isNull);
    expect(digitForKey(LogicalKeyboardKey.select), isNull);
  });

  test('la tecla "último canal" solo actúa en directo', () {
    expect(_live(LogicalKeyboardKey.mediaLast), TvPlayerCommand.lastChannel);
    expect(_vod(LogicalKeyboardKey.mediaLast), TvPlayerCommand.none);
  });

  test('arriba/abajo y CH+/CH-', () {
    expect(_live(LogicalKeyboardKey.arrowUp), TvPlayerCommand.previousChannel);
    expect(_live(LogicalKeyboardKey.channelDown), TvPlayerCommand.previousChannel);
    expect(_live(LogicalKeyboardKey.arrowDown), TvPlayerCommand.nextChannel);
    expect(_live(LogicalKeyboardKey.channelUp), TvPlayerCommand.nextChannel);
    expect(_vod(LogicalKeyboardKey.arrowUp), TvPlayerCommand.showOverlay);
    expect(_vod(LogicalKeyboardKey.arrowDown), TvPlayerCommand.showOverlay);
    expect(_vod(LogicalKeyboardKey.channelUp), TvPlayerCommand.showOverlay);
  });

  test('izquierda/derecha', () {
    expect(_live(LogicalKeyboardKey.arrowLeft), TvPlayerCommand.showOverlay);
    expect(_live(LogicalKeyboardKey.arrowRight), TvPlayerCommand.showOverlay);
    expect(_vod(LogicalKeyboardKey.arrowLeft), TvPlayerCommand.seekBack);
    expect(_vod(LogicalKeyboardKey.arrowRight), TvPlayerCommand.seekForward);
  });

  test('rewind / fast forward solo en VOD', () {
    expect(_live(LogicalKeyboardKey.mediaRewind), TvPlayerCommand.none);
    expect(_live(LogicalKeyboardKey.mediaFastForward), TvPlayerCommand.none);
    expect(_vod(LogicalKeyboardKey.mediaRewind), TvPlayerCommand.seekBack);
    expect(_vod(LogicalKeyboardKey.mediaFastForward), TvPlayerCommand.seekForward);
  });

  test('OK alterna overlay en vivo y pausa en VOD', () {
    for (final k in [
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.gameButtonA,
    ]) {
      expect(_live(k), TvPlayerCommand.toggleOverlay);
      expect(_vod(k), TvPlayerCommand.togglePlayPause);
    }
  });

  test('teclas multimedia', () {
    for (final live in [true, false]) {
      expect(mapTvPlayerKey(LogicalKeyboardKey.mediaPlayPause, isLive: live),
          TvPlayerCommand.togglePlayPause);
      expect(mapTvPlayerKey(LogicalKeyboardKey.mediaPlay, isLive: live),
          TvPlayerCommand.play);
      expect(mapTvPlayerKey(LogicalKeyboardKey.mediaPause, isLive: live),
          TvPlayerCommand.pause);
    }
  });

  test('menú / info / F2 abren opciones', () {
    for (final k in [
      LogicalKeyboardKey.contextMenu,
      LogicalKeyboardKey.info,
      LogicalKeyboardKey.f2,
    ]) {
      expect(_live(k), TvPlayerCommand.openOptions);
      expect(_vod(k), TvPlayerCommand.openOptions);
    }
  });

  test('Atrás y Stop salen', () {
    for (final k in [
      LogicalKeyboardKey.goBack,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.browserBack,
      LogicalKeyboardKey.mediaStop,
    ]) {
      expect(_live(k), TvPlayerCommand.exit);
      expect(_vod(k), TvPlayerCommand.exit);
    }
  });

  test('otras teclas no hacen nada', () {
    expect(_live(LogicalKeyboardKey.keyA), TvPlayerCommand.none);
    expect(_vod(LogicalKeyboardKey.keyA), TvPlayerCommand.none);
  });

  test('Atrás del sistema lo gestiona el PopScope, no la tecla', () {
    expect(isSystemBackKey(LogicalKeyboardKey.goBack), isTrue);
    expect(isSystemBackKey(LogicalKeyboardKey.browserBack), isTrue);
    expect(isSystemBackKey(LogicalKeyboardKey.escape), isFalse);
    expect(isSystemBackKey(LogicalKeyboardKey.mediaStop), isFalse);
  });
}
