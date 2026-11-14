import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/widgets/tv_button.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_player.dart';
import 'package:open_tv/screens/tv/youtube/youtube_player_page.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Origen con el que se carga la página del reproductor de Vimeo.
/// Es el de Cineaparte: Vimeo bloquea por dominio algunas de sus películas.
const vimeoPlayerOrigin = 'https://www.cineaparte.com/';

final _vimeoId = RegExp(r'^\d{1,12}$');

/// Página con el reproductor oficial de Vimeo a pantalla completa y sin sus
/// controles (se maneja con `vmToggle()` y `vmSeek(±s)`). Informa a la app por
/// el canal `FredTv` con los mismos mensajes que el reproductor de YouTube
/// (`state`: 0 terminó, 1 reproduce, 2 pausa, 3 carga). Lanza [ArgumentError]
/// si [videoId] no es un número de Vimeo.
String vimeoPlayerHtml(String videoId) {
  if (!_vimeoId.hasMatch(videoId)) {
    throw ArgumentError.value(videoId, 'videoId', 'no es un id de Vimeo');
  }
  return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden}
#p{position:fixed;left:0;top:0;width:100vw;height:100vh;border:0}
</style>
</head>
<body>
<iframe id="p" src="https://player.vimeo.com/video/$videoId?autoplay=1&controls=0&playsinline=1&title=0&byline=0&portrait=0&dnt=1" allow="autoplay; fullscreen" allowfullscreen></iframe>
<script src="https://player.vimeo.com/api/player.js"></script>
<script>
function send(o){try{$youtubePlayerChannel.postMessage(JSON.stringify(o));}catch(e){}}
var pl=new Vimeo.Player(document.getElementById('p'));
var st=-1,pos=0,dur=0;
function report(){send({t:'state',s:st,pos:pos,dur:dur,live:false,q:''});}
pl.getDuration().then(function(d){dur=d;});
pl.on('play',function(){st=1;report();});
pl.on('playing',function(){st=1;report();});
pl.on('pause',function(){st=2;report();});
pl.on('bufferstart',function(){st=3;report();});
pl.on('bufferend',function(){st=1;report();});
pl.on('ended',function(){st=0;report();});
pl.on('timeupdate',function(e){pos=e.seconds;dur=e.duration;if(st===1)report();});
pl.on('error',function(e){send({t:'error',code:100});});
function vmToggle(){pl.getPaused().then(function(p){if(p)pl.play();else pl.pause();});}
function vmSeek(d){pl.getCurrentTime().then(function(c){pl.setCurrentTime(Math.max(0,c+d));});}
</script>
</body>
</html>
''';
}

void _keepScreenOn(bool on) => unawaited(WakelockPlus.toggle(enable: on));

/// Reproductor de Vimeo a pantalla completa, manejado con el mando: OK pausa
/// o reanuda, ←/→ saltan 10 s, Atrás cierra. Termina solo al acabar la
/// película. Todavía no lo abre ninguna pantalla.
class TvVimeoPlayer extends StatefulWidget {
  const TvVimeoPlayer({
    super.key,
    required this.videoId,
    this.title,
    this.surface,
    this.readyTimeout = const Duration(seconds: 20),
    this.wakelock = _keepScreenOn,
  });

  final String videoId;
  final String? title;
  final YoutubePlayerSurface? surface;
  final Duration readyTimeout;
  /// Enciende (`true`) o suelta (`false`) la pantalla encendida.
  final void Function(bool on) wakelock;

  @override
  State<TvVimeoPlayer> createState() => _TvVimeoPlayerState();
}

class _TvVimeoPlayerState extends State<TvVimeoPlayer> {
  late final YoutubePlayerSurface _surface;
  final FocusNode _keysNode = FocusNode(debugLabel: 'vm-player-keys');
  final FocusNode _failNode = FocusNode(debugLabel: 'vm-player-back');
  Timer? _readyTimer;
  bool _started = false;
  bool _failed = false;
  bool _closing = false;
  bool _paused = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _surface = widget.surface ?? WebViewYoutubeSurface();
    _surface.onMessage = _onMessage;
    _readyTimer = Timer(widget.readyTimeout, _fail);
    widget.wakelock(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    try {
      unawaited(_surface.load(vimeoPlayerHtml(widget.videoId), vimeoPlayerOrigin));
    } on ArgumentError catch (e) {
      debugPrint('TvVimeoPlayer: $e');
      scheduleMicrotask(_fail);
    }
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _keysNode.dispose();
    _failNode.dispose();
    unawaited(_surface.dispose());
    widget.wakelock(false);
    super.dispose();
  }

  void _fail() {
    if (!mounted || _failed) return;
    _readyTimer?.cancel();
    setState(() => _failed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _failNode.requestFocus();
    });
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  void _onMessage(String message) {
    if (!mounted || _failed) return;
    final event = parseYoutubePlayerEvent(message);
    switch (event) {
      case null:
        return;
      case YoutubeErrorEvent():
        _fail();
      case YoutubeStateEvent():
        _readyTimer?.cancel();
        if (event.state == YoutubePlayerState.ended) {
          _close();
          return;
        }
        setState(() {
          _paused = event.state == YoutubePlayerState.paused;
          if (event.state == YoutubePlayerState.playing) _started = true;
        });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_failed) return KeyEventResult.ignored;
    final command = youtubeKeyCommand(event.logicalKey);
    if (command == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      unawaited(_surface.run(switch (command) {
        YoutubeKeyCommand.toggle => 'vmToggle()',
        YoutubeKeyCommand.back30 => 'vmSeek(-10)',
        YoutubeKeyCommand.forward30 => 'vmSeek(10)',
      }));
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _keysNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_failed) _surface.build(context),
            if (!_failed && !_started)
              const Center(child: CircularProgressIndicator()),
            if (!_failed && _paused)
              const Center(
                  child: Icon(Icons.pause_circle_outline,
                      size: 96, color: TvTheme.textPrimary)),
            if (_failed) _failure(context),
          ],
        ),
      ),
    );
  }

  Widget _failure(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: TvTheme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 72, color: TvTheme.error),
            const SizedBox(height: 18),
            Text(l10n.ytPlayerFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: TvTheme.fontTitle, color: TvTheme.textPrimary)),
            if (widget.title != null) ...[
              const SizedBox(height: 8),
              Text(widget.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: TvTheme.fontBody,
                      color: TvTheme.textSecondary)),
            ],
            const SizedBox(height: 32),
            TvButton(
                label: l10n.ytBack,
                onSelect: _close,
                primary: true,
                focusNode: _failNode),
          ],
        ),
      ),
    );
  }
}
