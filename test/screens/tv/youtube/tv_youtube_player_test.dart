import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_player.dart';
import 'package:open_tv/screens/tv/youtube/youtube_player_page.dart';

import '../fakes.dart';

final _channel = Channel(
  id: 7,
  name: 'La Encerrona',
  url: 'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg',
  mediaType: MediaType.livestream,
  sourceId: 1,
  favorite: false,
);

const _video = YoutubeProgram(
    videoId: 'Ejg0OQPYVgw',
    title: 'URGENTE: paro de transportes',
    kind: YoutubeProgramKind.video,
    duration: '22:45',
    age: Duration(hours: 16));

const _live = YoutubeProgram(
    videoId: 'LLLLLLLLLLL', title: 'Centrífugos', kind: YoutubeProgramKind.live);

class FakeSurface implements YoutubePlayerSurface {
  String? html;
  String? baseUrl;
  final List<String> js = [];
  bool disposed = false;
  void Function(String message)? _handler;

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('yt-surface'));

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

  void emit(String message) => _handler!(message);

  void state(int s, {num pos = 0, num dur = 1365, bool live = false}) =>
      emit('{"t":"state","s":$s,"pos":$pos,"dur":$dur,"live":$live}');
}

Future<FakeSurface> _open(
  WidgetTester t, {
  YoutubeProgram program = _video,
  List<String>? external,
}) async {
  final surface = FakeSurface();
  await pumpTvRoute(
    t,
    (_) => TvYoutubePlayer(
      channel: _channel,
      program: program,
      surface: surface,
      keepAwake: false,
      openExternally: (id) async => external?.add(id),
    ),
  );
  return surface;
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.pump();
}

void main() {
  testWidgets('carga la página del vídeo con el origen del reproductor',
      (t) async {
    final s = await _open(t);
    expect(s.baseUrl, youtubePlayerOrigin);
    expect(s.html, contains("videoId:'Ejg0OQPYVgw'"));
    expect(s.html, contains("hl:'es'"));
    expect(find.byKey(const ValueKey('yt-surface')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('al empezar a reproducir quita la carga', (t) async {
    final s = await _open(t);
    s.state(1, pos: 1);
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('OK pausa o reanuda y las flechas saltan 30 s', (t) async {
    final s = await _open(t);
    s.state(1, pos: 60);
    await t.pump();

    await _key(t, LogicalKeyboardKey.select);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.arrowLeft);

    expect(s.js, ['ytToggle()', 'ytSeek(30)', 'ytSeek(-30)']);
  });

  testWidgets('una tecla muestra la posición un momento', (t) async {
    final s = await _open(t);
    s.state(1, pos: 82, dur: 1365);
    await t.pump();
    expect(find.text('1:22 / 22:45'), findsNothing);

    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(find.text('1:22 / 22:45'), findsOneWidget);

    await t.pump(const Duration(seconds: 5));
    expect(find.text('1:22 / 22:45'), findsNothing);
  });

  testWidgets('no repite el título: ya lo muestra el reproductor de YouTube',
      (t) async {
    final s = await _open(t);
    s.state(2, pos: 82);
    await t.pump();
    expect(find.text('URGENTE: paro de transportes'), findsNothing);
  });

  testWidgets('en pausa deja «En pausa» y la posición a la vista', (t) async {
    final s = await _open(t);
    s.state(1, pos: 82);
    await t.pump();
    s.state(2, pos: 82);
    await t.pump();
    await t.pump(const Duration(seconds: 10));

    expect(find.text('En pausa'), findsOneWidget);
    expect(find.text('1:22 / 22:45'), findsOneWidget);
  });

  testWidgets('un directo muestra EN VIVO en lugar de la posición', (t) async {
    final s = await _open(t, program: _live);
    s.state(1, pos: 5, dur: 3600, live: true);
    await t.pump();
    await _key(t, LogicalKeyboardKey.select);

    expect(find.text('EN VIVO'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('al terminar el vídeo vuelve atrás', (t) async {
    final s = await _open(t);
    s.state(1, pos: 1360);
    await t.pump();
    s.state(0, pos: 1365);
    await t.pumpAndSettle();

    expect(find.byType(TvYoutubePlayer), findsNothing);
    expect(s.disposed, isTrue);
  });

  testWidgets('error 150: ofrece Abrir en YouTube y lo abre con el id',
      (t) async {
    final external = <String>[];
    final s = await _open(t, external: external);
    s.emit('{"t":"error","code":150}');
    await t.pumpAndSettle();

    expect(find.text('No se pudo reproducir este vídeo aquí'), findsOneWidget);
    expect(find.text('Abrir en YouTube'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);

    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();

    expect(external, ['Ejg0OQPYVgw']);
    expect(s.js, isEmpty, reason: 'OK no se envía al reproductor roto');
    expect(find.byType(TvYoutubePlayer), findsNothing);
  });

  testWidgets('error: Volver cierra sin abrir YouTube', (t) async {
    final external = <String>[];
    final s = await _open(t, external: external);
    s.emit('{"t":"error","code":100}');
    await t.pumpAndSettle();

    await _key(t, LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();

    expect(external, isEmpty);
    expect(find.byType(TvYoutubePlayer), findsNothing);
  });

  testWidgets('si el reproductor no responde en 20 s muestra el mismo aviso',
      (t) async {
    await _open(t);
    await t.pump(const Duration(seconds: 19));
    expect(find.text('Abrir en YouTube'), findsNothing);
    await t.pump(const Duration(seconds: 2));
    await t.pump();
    expect(find.text('No se pudo reproducir este vídeo aquí'), findsOneWidget);
    expect(find.text('Abrir en YouTube'), findsOneWidget);
  });

  testWidgets('si responde a tiempo no salta el aviso', (t) async {
    final s = await _open(t);
    s.state(3);
    await t.pump(const Duration(seconds: 30));
    expect(find.text('Abrir en YouTube'), findsNothing);
  });

  testWidgets('Atrás mientras carga cierra y libera el reproductor', (t) async {
    final s = await _open(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    expect(find.byType(TvYoutubePlayer), findsNothing);
    expect(s.disposed, isTrue);
    // Un mensaje tardío de la página no debe romper nada.
    s.state(1, pos: 3);
    await t.pump(const Duration(seconds: 25));
    expect(t.takeException(), isNull);
  });
}
