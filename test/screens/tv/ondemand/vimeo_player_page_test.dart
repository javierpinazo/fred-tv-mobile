import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/ondemand/vimeo_player_page.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_player.dart';

import '../fakes.dart';

class FakeSurface implements YoutubePlayerSurface {
  String? html;
  String? baseUrl;
  final List<String> js = [];
  bool disposed = false;
  void Function(String message)? _handler;

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('vm-surface'));

  @override
  Future<void> load(String html, String baseUrl) async {
    this.html = html;
    this.baseUrl = baseUrl;
  }

  @override
  Future<void> run(String js) async => this.js.add(js);

  @override
  set onMessage(void Function(String message) handler) => _handler = handler;

  @override
  Future<void> dispose() async => disposed = true;

  void state(int s, {num pos = 0, num dur = 5400}) =>
      _handler!('{"t":"state","s":$s,"pos":$pos,"dur":$dur,"live":false}');
}

Future<FakeSurface> _open(WidgetTester t, {void Function(bool)? wakelock}) async {
  final surface = FakeSurface();
  await pumpTvRoute(
    t,
    (_) => TvVimeoPlayer(
        videoId: '1229366069',
        title: 'Expectante',
        surface: surface,
        wakelock: wakelock ?? (_) {}),
  );
  return surface;
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.pump();
}

void main() {
  group('vimeoPlayerHtml', () {
    test('trae el reproductor de Vimeo con el id y el canal de la app', () {
      final html = vimeoPlayerHtml('1229366069');
      expect(html, contains('player.vimeo.com'));
      expect(html, contains('1229366069'));
      expect(html, contains('autoplay'));
      expect(html, contains('FredTv.postMessage'));
    });

    test('rechaza ids que no son un número de Vimeo', () {
      for (final bad in ['abc', '', "123'+alert(1)+'", '1' * 13, '12 3']) {
        expect(() => vimeoPlayerHtml(bad), throwsArgumentError,
            reason: 'id «$bad»');
      }
    });
  });

  testWidgets('carga la página con el origen y muestra la carga', (t) async {
    final s = await _open(t);
    expect(s.baseUrl, vimeoPlayerOrigin);
    // Vimeo bloquea por dominio algunas películas de Cineaparte: el origen
    // tiene que ser el suyo.
    expect(vimeoPlayerOrigin, 'https://www.cineaparte.com/');
    expect(s.html, contains('1229366069'));
    expect(find.byKey(const ValueKey('vm-surface')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('OK pausa o reanuda y las flechas saltan 10 s', (t) async {
    final s = await _open(t);
    s.state(1, pos: 60);
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await _key(t, LogicalKeyboardKey.select);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.arrowLeft);

    expect(s.js, ['vmToggle()', 'vmSeek(10)', 'vmSeek(-10)']);
  });

  testWidgets('al terminar la película cierra la ruta y suelta la página',
      (t) async {
    final s = await _open(t);
    s.state(1, pos: 5000);
    await t.pump();
    s.state(0, pos: 5400);
    await t.pumpAndSettle();
    expect(find.byType(TvVimeoPlayer), findsNothing);
    expect(s.disposed, isTrue);
  });

  testWidgets('mantiene la pantalla encendida mientras reproduce', (t) async {
    final calls = <bool>[];
    await _open(t, wakelock: calls.add);
    expect(calls, [true]);
    Navigator.of(t.element(find.byType(TvVimeoPlayer))).pop();
    await t.pumpAndSettle();
    expect(calls, [true, false]);
  });
}
