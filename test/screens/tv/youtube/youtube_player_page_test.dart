import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/youtube/youtube_player_page.dart';

void main() {
  test('la página lleva el vídeo, el idioma y el API de YouTube', () {
    final h = youtubePlayerHtml('Ejg0OQPYVgw', language: 'pt');
    expect(h, contains("videoId:'Ejg0OQPYVgw'"));
    expect(h, contains("hl:'pt'"));
    expect(h, contains('https://www.youtube.com/iframe_api'));
    expect(h, contains('FredTv.postMessage'));
    expect(h, contains('function ytToggle()'));
    expect(h, contains('function ytSeek('));
  });

  test('sin controles táctiles y con arranque automático', () {
    final h = youtubePlayerHtml('Ejg0OQPYVgw');
    expect(h, contains('autoplay:1'));
    expect(h, contains('controls:0'));
    expect(h, contains("hl:'es'"));
  });

  test('apaga los subtítulos automáticos al arrancar y al cambiar de estado', () {
    final h = youtubePlayerHtml('Ejg0OQPYVgw');
    expect(h, contains("player.unloadModule('captions')"));
    expect(h, contains('onReady:function(e){noCaptions();'));
    expect(h, contains('onApiChange:noCaptions'));
    expect(h, contains('onStateChange:function(){noCaptions();state();}'));
  });

  test('rechaza ids que no son de YouTube', () {
    for (final bad in [
      '',
      "x';alert(1);//",
      'Ejg0OQPYVg',
      'Ejg0OQPYVgw0',
      '../../etc/pw',
    ]) {
      expect(() => youtubePlayerHtml(bad), throwsArgumentError, reason: bad);
    }
  });

  test('un idioma extraño no se cuela en la página', () {
    expect(youtubePlayerHtml('Ejg0OQPYVgw', language: "es';x//"),
        contains("hl:'es'"));
  });

  test('interpreta los mensajes de estado', () {
    final e = parseYoutubePlayerEvent(
            '{"t":"state","s":1,"pos":82.4,"dur":1365,"live":false}')
        as YoutubeStateEvent;
    expect(e.state, YoutubePlayerState.playing);
    expect(e.position, const Duration(seconds: 82));
    expect(e.duration, const Duration(seconds: 1365));
    expect(e.isLive, isFalse);

    YoutubePlayerState stateOf(int s) => (parseYoutubePlayerEvent(
                '{"t":"state","s":$s,"pos":0,"dur":0,"live":true}')
            as YoutubeStateEvent)
        .state;
    expect(stateOf(-1), YoutubePlayerState.loading);
    expect(stateOf(0), YoutubePlayerState.ended);
    expect(stateOf(2), YoutubePlayerState.paused);
    expect(stateOf(3), YoutubePlayerState.buffering);
    expect(stateOf(5), YoutubePlayerState.loading);
  });

  test('interpreta los errores', () {
    expect(
        (parseYoutubePlayerEvent('{"t":"error","code":150}')
                as YoutubeErrorEvent)
            .code,
        150);
  });

  test('ignora lo que no entiende', () {
    expect(parseYoutubePlayerEvent('basura'), isNull);
    expect(parseYoutubePlayerEvent('{"t":"state"}'), isNull);
    expect(parseYoutubePlayerEvent('{"t":"otro","s":1}'), isNull);
    expect(parseYoutubePlayerEvent('[1,2]'), isNull);
    expect(parseYoutubePlayerEvent('{"t":"state","s":99,"pos":0,"dur":0}'),
        isNull);
  });

  test('teclas del mando', () {
    expect(youtubeKeyCommand(LogicalKeyboardKey.select),
        YoutubeKeyCommand.toggle);
    expect(
        youtubeKeyCommand(LogicalKeyboardKey.enter), YoutubeKeyCommand.toggle);
    expect(youtubeKeyCommand(LogicalKeyboardKey.mediaPlayPause),
        YoutubeKeyCommand.toggle);
    expect(youtubeKeyCommand(LogicalKeyboardKey.arrowLeft),
        YoutubeKeyCommand.back30);
    expect(youtubeKeyCommand(LogicalKeyboardKey.mediaRewind),
        YoutubeKeyCommand.back30);
    expect(youtubeKeyCommand(LogicalKeyboardKey.arrowRight),
        YoutubeKeyCommand.forward30);
    expect(youtubeKeyCommand(LogicalKeyboardKey.mediaFastForward),
        YoutubeKeyCommand.forward30);
    expect(youtubeKeyCommand(LogicalKeyboardKey.arrowUp), isNull);
  });

  test('órdenes para la página', () {
    expect(youtubeCommandJs(YoutubeKeyCommand.toggle), 'ytToggle()');
    expect(youtubeCommandJs(YoutubeKeyCommand.back30), 'ytSeek(-30)');
    expect(youtubeCommandJs(YoutubeKeyCommand.forward30), 'ytSeek(30)');
  });
}
