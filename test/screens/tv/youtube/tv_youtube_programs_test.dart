import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/youtube/youtube_channel_service.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/player/tv_player.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_programs.dart';

import '../fakes.dart';

final _channel = Channel(
  id: 7,
  name: 'La Encerrona',
  url: 'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg',
  mediaType: MediaType.livestream,
  sourceId: 1,
  favorite: false,
);

const _live = YoutubeProgram(
    videoId: 'LLLLLLLLLLL', title: 'Centrífugos', kind: YoutubeProgramKind.live);
const _a = YoutubeProgram(
    videoId: 'aaaaaaaaaaa',
    title: 'URGENTE: paro de transportes',
    kind: YoutubeProgramKind.video,
    duration: '22:45',
    age: Duration(hours: 16));
const _b = YoutubeProgram(
    videoId: 'bbbbbbbbbbb',
    title: 'AUDIO BOMBA',
    kind: YoutubeProgramKind.video,
    duration: '25:26',
    age: Duration(days: 1));

Widget _noImage(BuildContext context, YoutubeProgram p) =>
    const ColoredBox(color: Colors.black);

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

Future<List<YoutubeProgram>> _open(
  WidgetTester t,
  FakeTvData data, {
  List<YoutubeProgram>? played,
}) async {
  final list = played ?? <YoutubeProgram>[];
  await pumpTv(
    t,
    TvYoutubePrograms(
      channel: _channel,
      data: data,
      thumbnailBuilder: _noImage,
      onPlay: (context, channel, program) async => list.add(program),
    ),
  );
  return list;
}

void main() {
  testWidgets('muestra el directo primero con insignia y los vídeos con fecha',
      (t) async {
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) async => [_live, _a, _b];
    await _open(t, data);

    expect(find.text('La Encerrona'), findsOneWidget);
    expect(find.text('EN VIVO'), findsOneWidget);
    expect(find.text('En vivo ahora'), findsOneWidget);
    expect(find.text('Centrífugos'), findsOneWidget);
    expect(find.text('22:45'), findsOneWidget);
    expect(find.text('hace 16 h'), findsOneWidget);
    expect(find.text('hace 1 día'), findsOneWidget);
    expect(isFocused(t, const ValueKey('yt-LLLLLLLLLLL')), isTrue);
    // El directo va a la izquierda del primer vídeo.
    expect(t.getTopLeft(find.byKey(const ValueKey('yt-LLLLLLLLLLL'))).dx,
        lessThan(t.getTopLeft(find.byKey(const ValueKey('yt-aaaaaaaaaaa'))).dx));
  });

  testWidgets('pide los programas del canal abierto', (t) async {
    final asked = <String?>[];
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) async {
        asked.add(c.url);
        return [_a];
      };
    await _open(t, data);
    expect(asked, [_channel.url]);
  });

  testWidgets('OK en la primera tarjeta reproduce ese programa', (t) async {
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) async => [_live, _a, _b];
    final played = await _open(t, data);
    await _ok(t);
    expect(played.single.videoId, 'LLLLLLLLLLL');
  });

  testWidgets('flecha derecha y OK reproduce el segundo y conserva el foco',
      (t) async {
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) async => [_live, _a, _b];
    final played = await _open(t, data);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _ok(t);
    expect(played.single.videoId, 'aaaaaaaaaaa');
    expect(isFocused(t, const ValueKey('yt-aaaaaaaaaaa')), isTrue);
  });

  testWidgets('error: avisa y Reintentar vuelve a cargar sin caché', (t) async {
    final forces = <bool>[];
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) async {
        forces.add(force);
        if (forces.length == 1) throw YoutubeUnavailableException('caído');
        return [_a];
      };
    await _open(t, data);

    expect(find.text('No se pudieron cargar los programas de YouTube'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await _ok(t);

    expect(forces, [false, true]);
    expect(find.text('URGENTE: paro de transportes'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('un error inesperado también se avisa', (t) async {
    final data = FakeTvData()
      ..onYoutubePrograms =
          (c, {force = false}) async => throw StateError('otro');
    await _open(t, data);
    expect(find.text('No se pudieron cargar los programas de YouTube'),
        findsOneWidget);
  });

  testWidgets('canal sin programas', (t) async {
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) async => [];
    await _open(t, data);
    expect(find.text('Este canal no tiene programas recientes'), findsOneWidget);
  });

  testWidgets('Atrás durante la carga cierra sin errores', (t) async {
    final pending = Completer<List<YoutubeProgram>>();
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) => pending.future;
    await pumpTvRoute(
      t,
      (_) => TvYoutubePrograms(
          channel: _channel, data: data, thumbnailBuilder: _noImage),
    );
    expect(find.byType(TvYoutubePrograms), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(TvYoutubePrograms), findsNothing);

    pending.complete([_a]);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('openTvPlayer con un canal de YouTube abre su lista de programas',
      (t) async {
    final data = FakeTvData()
      ..onYoutubePrograms = (c, {force = false}) async => [];
    int? result = -1;
    await pumpTvRoute(
      t,
      null,
      open: (context) async => result = await openTvPlayer(context,
          playlist: [fakeChannel(1), _channel], index: 1, data: data),
    );

    expect(find.byType(TvYoutubePrograms), findsOneWidget);
    expect(find.byType(TvPlayer), findsNothing);
    expect(find.text('La Encerrona'), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(result, 1, reason: 'devuelve el índice para recuperar el foco');
  });
}
