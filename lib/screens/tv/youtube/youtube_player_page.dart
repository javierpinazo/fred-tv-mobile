import 'dart:convert';

import 'package:flutter/services.dart';

/// Origen con el que se carga la página del reproductor: el reproductor de
/// YouTube exige que la página que lo incrusta tenga un origen https.
const youtubePlayerOrigin = 'https://fredtv.example.app/';

/// Nombre del canal JavaScript por el que la página habla con la app.
const youtubePlayerChannel = 'FredTv';

final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _language = RegExp(r'^[a-z]{2}$');

/// Página con el reproductor IFrame oficial de YouTube a pantalla completa,
/// sin sus controles (se maneja con [youtubeCommandJs]). Lanza
/// [ArgumentError] si [videoId] no tiene forma de id de YouTube.
String youtubePlayerHtml(String videoId,
    {String language = 'es', bool captions = false}) {
  if (!_videoId.hasMatch(videoId)) {
    throw ArgumentError.value(videoId, 'videoId', 'no es un id de YouTube');
  }
  final hl = _language.hasMatch(language) ? language : 'es';
  // Con subtítulos (películas que no están en español) no se descargan los
  // módulos de subtítulos y se piden en el idioma de la app.
  final noCaptionsBody = captions
      ? ''
      : "try{player.unloadModule('captions');player.unloadModule('cc');}catch(e){}";
  final captionVars = captions ? ",cc_load_policy:1,cc_lang_pref:'$hl'" : '';
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
<div id="p"></div>
<script>
var player=null;
function send(o){try{$youtubePlayerChannel.postMessage(JSON.stringify(o));}catch(e){}}
function state(){
  if(!player||!player.getPlayerState)return;
  var d=player.getVideoData?player.getVideoData():null;
  send({t:'state',s:player.getPlayerState(),pos:player.getCurrentTime()||0,
    dur:player.getDuration()||0,live:!!(d&&d.isLive),
    q:player.getPlaybackQuality?player.getPlaybackQuality():'',
    vw:window.innerWidth,vh:window.innerHeight});
}
// YouTube enciende por su cuenta los subtítulos automáticos y tapan los
// rótulos del programa: se descarga el módulo cada vez que puede volver.
function noCaptions(){
  $noCaptionsBody
}
function onYouTubeIframeAPIReady(){
  player=new YT.Player('p',{videoId:'$videoId',width:'100%',height:'100%',
    playerVars:{autoplay:1,controls:0,rel:0,playsinline:1,fs:0,iv_load_policy:3,disablekb:1,hl:'$hl'$captionVars},
    events:{
      onReady:function(e){noCaptions();e.target.playVideo();state();},
      onApiChange:noCaptions,
      onStateChange:function(){noCaptions();state();},
      onError:function(e){send({t:'error',code:e.data});}
    }});
}
function ytToggle(){
  if(!player||!player.getPlayerState)return;
  if(player.getPlayerState()===1)player.pauseVideo();else player.playVideo();
}
function ytSeek(d){
  if(!player||!player.getCurrentTime)return;
  player.seekTo(Math.max(0,player.getCurrentTime()+d),true);
  setTimeout(state,800);
}
setInterval(function(){
  if(player&&player.getPlayerState&&player.getPlayerState()===1)state();
},1000);
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body>
</html>
''';
}

enum YoutubePlayerState { loading, playing, paused, buffering, ended }

/// Lo que la página del reproductor comunica a la app.
sealed class YoutubePlayerEvent {
  const YoutubePlayerEvent();
}

final class YoutubeStateEvent extends YoutubePlayerEvent {
  const YoutubeStateEvent({
    required this.state,
    required this.position,
    required this.duration,
    required this.isLive,
    this.quality = '',
  });

  final YoutubePlayerState state;
  final Duration position;
  final Duration duration;
  final bool isLive;

  /// Calidad que informa YouTube (`hd1080`, `hd720`…), para diagnóstico.
  final String quality;
}

/// Error del reproductor: 2 parámetro inválido, 5 fallo de HTML5, 100 vídeo
/// no encontrado, 101/150 no se permite reproducirlo incrustado.
final class YoutubeErrorEvent extends YoutubePlayerEvent {
  const YoutubeErrorEvent(this.code);
  final int code;
}

/// Interpreta un mensaje de la página; `null` si no se entiende.
YoutubePlayerEvent? parseYoutubePlayerEvent(String message) {
  final Object? data;
  try {
    data = jsonDecode(message);
  } on FormatException {
    return null;
  }
  if (data is! Map) return null;
  switch (data['t']) {
    case 'error':
      final code = data['code'];
      return code is num ? YoutubeErrorEvent(code.toInt()) : null;
    case 'state':
      final s = data['s'], pos = data['pos'], dur = data['dur'];
      if (s is! num || pos is! num || dur is! num) return null;
      final state = switch (s.toInt()) {
        -1 || 5 => YoutubePlayerState.loading,
        0 => YoutubePlayerState.ended,
        1 => YoutubePlayerState.playing,
        2 => YoutubePlayerState.paused,
        3 => YoutubePlayerState.buffering,
        _ => null,
      };
      if (state == null) return null;
      final quality = data['q'];
      return YoutubeStateEvent(
        state: state,
        position: Duration(seconds: pos.floor()),
        duration: Duration(seconds: dur.floor()),
        isLive: data['live'] == true,
        quality: quality is String ? quality : '',
      );
  }
  return null;
}

enum YoutubeKeyCommand { toggle, back30, forward30 }

/// Qué hace cada tecla del mando en el reproductor; `null` si nada.
YoutubeKeyCommand? youtubeKeyCommand(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.mediaPlay ||
      key == LogicalKeyboardKey.mediaPause) {
    return YoutubeKeyCommand.toggle;
  }
  if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.mediaRewind) {
    return YoutubeKeyCommand.back30;
  }
  if (key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.mediaFastForward) {
    return YoutubeKeyCommand.forward30;
  }
  return null;
}

/// JavaScript que ejecuta [command] en la página del reproductor.
String youtubeCommandJs(YoutubeKeyCommand command) => switch (command) {
      YoutubeKeyCommand.toggle => 'ytToggle()',
      YoutubeKeyCommand.back30 => 'ytSeek(-30)',
      YoutubeKeyCommand.forward30 => 'ytSeek(30)',
    };
