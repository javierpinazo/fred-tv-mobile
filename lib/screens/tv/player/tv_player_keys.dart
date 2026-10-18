import 'package:flutter/services.dart';

enum TvPlayerCommand {
  none,
  togglePlayPause,
  play,
  pause,
  seekBack,
  seekForward,
  previousChannel,
  nextChannel,
  showOverlay,
  toggleOverlay,
  openOptions,
  exit,
}

final Set<LogicalKeyboardKey> _okKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

/// Convierte una tecla del control remoto en un comando del reproductor TV.
///
/// En directo ↑/↓ cambian de canal y ←/→ solo muestran la información (nunca
/// hacen seek). En VOD ←/→ saltan 10 s y OK pausa.
TvPlayerCommand mapTvPlayerKey(LogicalKeyboardKey key, {required bool isLive}) {
  if (_okKeys.contains(key)) {
    return isLive
        ? TvPlayerCommand.toggleOverlay
        : TvPlayerCommand.togglePlayPause;
  }
  if (key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.channelDown) {
    return isLive
        ? TvPlayerCommand.previousChannel
        : TvPlayerCommand.showOverlay;
  }
  if (key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.channelUp) {
    return isLive ? TvPlayerCommand.nextChannel : TvPlayerCommand.showOverlay;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return isLive ? TvPlayerCommand.showOverlay : TvPlayerCommand.seekBack;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return isLive ? TvPlayerCommand.showOverlay : TvPlayerCommand.seekForward;
  }
  if (key == LogicalKeyboardKey.mediaRewind) {
    return isLive ? TvPlayerCommand.none : TvPlayerCommand.seekBack;
  }
  if (key == LogicalKeyboardKey.mediaFastForward) {
    return isLive ? TvPlayerCommand.none : TvPlayerCommand.seekForward;
  }
  if (key == LogicalKeyboardKey.mediaPlayPause) {
    return TvPlayerCommand.togglePlayPause;
  }
  if (key == LogicalKeyboardKey.mediaPlay) return TvPlayerCommand.play;
  if (key == LogicalKeyboardKey.mediaPause) return TvPlayerCommand.pause;
  if (key == LogicalKeyboardKey.contextMenu ||
      key == LogicalKeyboardKey.info ||
      key == LogicalKeyboardKey.f2) {
    return TvPlayerCommand.openOptions;
  }
  if (key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.mediaStop) {
    return TvPlayerCommand.exit;
  }
  return TvPlayerCommand.none;
}
