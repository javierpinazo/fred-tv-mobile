import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/backend/youtube/youtube_show.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_programs.dart';

import '../fakes.dart';

final _channel = Channel(
  id: 7,
  name: 'Canal de prueba',
  url: 'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg',
  mediaType: MediaType.livestream,
  sourceId: 1,
  favorite: false,
);

YoutubeProgram _p(String id, String title, Duration age) => YoutubeProgram(
      videoId: id,
      title: title,
      kind: YoutubeProgramKind.video,
      duration: '20:00',
      age: age,
    );

final _e1 = _p('e1e1e1e1e1e', 'Encerrona de hoy', const Duration(hours: 2));
final _e2 = _p('e2e2e2e2e2e', 'Encerrona de ayer', const Duration(days: 1));
final _c1 = _p('c1c1c1c1c1c', 'Centrífugos último', const Duration(days: 2));
final _i1 = _p('i1i1i1i1i1i', 'Islas último', const Duration(days: 3));
final _x1 = _p('x1x1x1x1x1x', 'Especial suelto', const Duration(days: 4));

FakeTvData _data({List<String>? order}) {
  final data = FakeTvData()
    ..onYoutubePrograms =
        ((c, {force = false}) async => [_e1, _e2, _c1, _i1, _x1])
    ..youtubeShows = [
      YoutubeShow(key: 'isl', name: 'Pequeñas Islas', programs: [_i1]),
      YoutubeShow(key: 'enc', name: 'La Encerrona', programs: [_e1, _e2]),
      YoutubeShow(key: 'cen', name: 'Centrífugos', programs: [_c1]),
    ];
  if (order != null) data.youtubeOrders[_channel.url!] = order;
  return data;
}

Widget _noImage(BuildContext context, YoutubeProgram p) =>
    const ColoredBox(color: Colors.black);

Future<List<YoutubeProgram>> _open(WidgetTester t, FakeTvData data,
    {double textScale = 1}) async {
  final played = <YoutubeProgram>[];
  await pumpTv(
    t,
    MediaQuery(
      data: MediaQueryData(
          size: const Size(960, 540), textScaler: TextScaler.linear(textScale)),
      child: TvYoutubePrograms(
        channel: _channel,
        data: data,
        thumbnailBuilder: _noImage,
        onPlay: (context, channel, program) async => played.add(program),
      ),
    ),
  );
  return played;
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

Future<void> _ok(WidgetTester t) => _key(t, LogicalKeyboardKey.select);

Future<void> _longOk(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyRepeatEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

/// Claves de los programas, de arriba abajo, tal como están en pantalla.
List<String> _rowOrder(WidgetTester t) {
  final tops = <String, double>{};
  for (final key in ['enc', 'cen', 'isl']) {
    final finder = find.byKey(Key('yt-show-$key'), skipOffstage: false);
    if (finder.evaluate().isNotEmpty) tops[key] = t.getTopLeft(finder).dy;
  }
  return tops.keys.toList()..sort((a, b) => tops[a]!.compareTo(tops[b]!));
}

String? _focusedCard(WidgetTester t) {
  for (final id in [
    'enc-e1e1e1e1e1e',
    'enc-e2e2e2e2e2e',
    'cen-c1c1c1c1c1c',
    'isl-i1i1i1i1i1i',
    'e1e1e1e1e1e',
  ]) {
    final key = ValueKey('yt-$id');
    if (find.byKey(key).evaluate().isNotEmpty && isFocused(t, key)) return id;
  }
  return null;
}

void main() {
  testWidgets('una fila por programa: el preferido arriba, luego por fecha',
      (t) async {
    await _open(t, _data(order: ['cen']));
    expect(_rowOrder(t), ['cen', 'enc', 'isl']);
    expect(find.text('Centrífugos'), findsOneWidget);
    expect(_focusedCard(t), 'cen-c1c1c1c1c1c');
    expect(t.takeException(), isNull);
  });

  testWidgets('sin orden guardado van por fecha y el mosaico queda al final',
      (t) async {
    await _open(t, _data());
    expect(_rowOrder(t), ['enc', 'cen', 'isl']);
    expect(_focusedCard(t), 'enc-e1e1e1e1e1e');

    await t.scrollUntilVisible(find.text('Todo lo último'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    final all = t.getTopLeft(find.text('Todo lo último')).dy;
    expect(
        all,
        greaterThan(t
            .getTopLeft(find.byKey(const Key('yt-show-isl'), skipOffstage: false))
            .dy));
    expect(find.byKey(const ValueKey('yt-x1x1x1x1x1x'), skipOffstage: false),
        findsOneWidget,
        reason: 'lo que no es de ningún programa está en el mosaico');
  });

  testWidgets('sin programas no hay título de sección: solo el mosaico',
      (t) async {
    final data = _data()..youtubeShows = const [];
    await _open(t, data);
    expect(find.text('Todo lo último'), findsNothing);
    expect(_focusedCard(t), 'e1e1e1e1e1e');
  });

  testWidgets('las flechas recorren la fila y cambian de fila', (t) async {
    await _open(t, _data());
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(_focusedCard(t), 'enc-e2e2e2e2e2e');
    await _key(t, LogicalKeyboardKey.arrowLeft);
    expect(_focusedCard(t), 'enc-e1e1e1e1e1e');
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(_focusedCard(t), 'cen-c1c1c1c1c1c');
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(_focusedCard(t), 'isl-i1i1i1i1i1i');
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(_focusedCard(t), 'e1e1e1e1e1e', reason: 'entra en el mosaico');
    await _key(t, LogicalKeyboardKey.arrowUp);
    expect(_focusedCard(t), 'isl-i1i1i1i1i1i');
  });

  testWidgets('OK reproduce la emisión de la fila y conserva el foco',
      (t) async {
    final played = await _open(t, _data());
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(played.single.videoId, 'c1c1c1c1c1c');
    expect(_focusedCard(t), 'cen-c1c1c1c1c1c');
  });

  testWidgets('mantener OK → Poner primero: reordena, guarda y deja el foco',
      (t) async {
    final data = _data();
    await _open(t, data);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(_focusedCard(t), 'isl-i1i1i1i1i1i');

    await _longOk(t);
    expect(find.text('Poner primero'), findsOneWidget);
    expect(find.text('Subir'), findsOneWidget);
    expect(find.text('Bajar'), findsNothing, reason: 'ya es la última fila');
    await _ok(t);

    expect(find.text('Poner primero'), findsNothing);
    expect(_rowOrder(t), ['isl', 'enc', 'cen']);
    expect(data.youtubeOrders[_channel.url], ['isl', 'enc', 'cen']);
    expect(_focusedCard(t), 'isl-i1i1i1i1i1i');
    expect(t.takeException(), isNull);
  });

  testWidgets('la primera fila solo se puede bajar', (t) async {
    final data = _data();
    await _open(t, data);
    await _longOk(t);
    expect(find.text('Poner primero'), findsNothing);
    expect(find.text('Subir'), findsNothing);
    expect(find.text('Bajar'), findsOneWidget);
    await _ok(t);
    expect(_rowOrder(t), ['cen', 'enc', 'isl']);
    expect(data.youtubeOrders[_channel.url], ['cen', 'enc', 'isl']);
    expect(_focusedCard(t), 'enc-e1e1e1e1e1e');
  });

  testWidgets('Atrás en el menú no cambia nada', (t) async {
    final data = _data();
    await _open(t, data);
    await _longOk(t);
    expect(find.text('Bajar'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_rowOrder(t), ['enc', 'cen', 'isl']);
    expect(data.youtubeOrders, isEmpty);
    expect(_focusedCard(t), 'enc-e1e1e1e1e1e');
  });

  testWidgets('mantener OK en el mosaico no abre ningún menú', (t) async {
    final data = _data()..youtubeShows = const [];
    await _open(t, data);
    await _longOk(t);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Bajar'), findsNothing);
    expect(find.text('Poner primero'), findsNothing);
  });

  testWidgets('con una sola fila no hay nada que mover', (t) async {
    final data = _data()
      ..youtubeShows = [
        YoutubeShow(key: 'enc', name: 'La Encerrona', programs: [_e1, _e2]),
      ];
    await _open(t, data);
    await _longOk(t);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('como mucho cinco filas', (t) async {
    final data = _data()
      ..youtubeShows = [
        for (var i = 1; i <= 7; i++)
          YoutubeShow(key: 'p$i', name: 'Programa $i', programs: [
            _p('p${i}p${i}p${i}p${i}p${i}x', 'Emisión $i', Duration(days: i)),
          ]),
      ];
    await _open(t, data);
    for (var i = 1; i <= 7; i++) {
      expect(
          find.byKey(Key('yt-show-p$i'), skipOffstage: false).evaluate().length,
          i <= 5 ? lessThanOrEqualTo(1) : 0,
          reason: 'programa $i');
    }
    expect(find.byKey(const Key('yt-show-p1')), findsOneWidget);
  });

  testWidgets('con letra grande no se desborda nada', (t) async {
    await _open(t, _data(), textScale: 1.6);
    expect(t.takeException(), isNull);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(t.takeException(), isNull);
    expect(_focusedCard(t), 'e1e1e1e1e1e');
  });
}
