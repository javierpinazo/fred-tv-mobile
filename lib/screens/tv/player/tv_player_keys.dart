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
  lastChannel,
  exit,
}

final Set<LogicalKeyboardKey> _okKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

/// Dígito (0‑9) de una tecla del control o del teclado numérico; `null` si no
/// es un dígito.
int? digitForKey(LogicalKeyboardKey key) {
  const digits = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
  const pad = [
    LogicalKeyboardKey.numpad0,
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5,
    LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad8,
    LogicalKeyboardKey.numpad9,
  ];
  final i = digits.indexOf(key);
  if (i >= 0) return i;
  final j = pad.indexOf(key);
  return j >= 0 ? j : null;
}

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
  if (key == LogicalKeyboardKey.mediaLast) {
    return isLive ? TvPlayerCommand.lastChannel : TvPlayerCommand.none;
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

/// Teclas "Atrás" del control. Android además envía el "atrás" del sistema, que
/// recibe el `PopScope`; si el reproductor también consumiera la tecla se
/// procesaría dos veces (cierra el reproductor y mueve el foco del menú).
bool isSystemBackKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.browserBack;
