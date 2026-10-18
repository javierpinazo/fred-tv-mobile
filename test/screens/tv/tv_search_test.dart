import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/tv_search.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';

import 'fakes.dart';

const _field = ValueKey('tv-search-field');
ValueKey<String> _res(int i) => ValueKey('tv-search-result-$i');

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

/// Escribe [text] en el campo (que debe tener el foco) y lo envía.
Future<void> _typeAndSubmit(WidgetTester t, String text) async {
  await _ok(t); // entra al modo edición
  await t.enterText(find.byType(TextField), text);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

FakeTvData _fake([int n = 10]) =>
    FakeTvData(channels: List.generate(n, (i) => fakeChannel(i + 1)));

void main() {
  testWidgets('buscar muestra resultados (regresión H1)', (t) async {
    final data = _fake();
    await pumpTv(t, TVSearch(data: data));
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'canal 1');
    expect(find.byKey(_res(0)), findsOneWidget);
    expect(find.byKey(_res(1)), findsOneWidget);
    expect(find.byKey(_res(2)), findsNothing);
    expect(isFocused(t, _res(0)), isTrue);
    expect(find.text('2 resultados'), findsOneWidget);
    expect(data.channelCalls.last.mediaTypes,
        [MediaType.livestream, MediaType.movie]);
    expect(data.channelCalls.last.query, 'canal 1');
  });

  testWidgets('↓ desde el campo va al primer resultado y ↑ vuelve', (t) async {
    await pumpTv(t, TVSearch(data: _fake()));
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'canal');
    await focusKey(t, 'tv-search-field');
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(isFocused(t, _res(0)), isTrue);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.arrowUp);
    expect(isFocused(t, _field), isTrue);
  });

  testWidgets('no roba el foco al construirse (regresión H4)', (t) async {
    await pumpTv(
      t,
      Row(
        children: [
          TvFocusable(
            key: const ValueKey('nav'),
            autofocus: true,
            onSelect: () {},
            builder: (_, __) => const SizedBox(width: 50, height: 50),
          ),
          Expanded(child: TVSearch(data: _fake())),
        ],
      ),
    );
    expect(isFocused(t, const ValueKey('nav')), isTrue);
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets('menos de 2 letras no consulta', (t) async {
    final data = _fake();
    await pumpTv(t, TVSearch(data: data));
    expect(find.text('Escribe al menos 2 letras'), findsOneWidget);
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'a');
    expect(data.channelCalls, isEmpty);
    expect(find.text('Escribe al menos 2 letras'), findsOneWidget);
  });

  testWidgets('sin coincidencias muestra el mensaje', (t) async {
    await pumpTv(t, TVSearch(data: _fake()));
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'xyz');
    expect(find.text('Sin resultados para "xyz"'), findsOneWidget);
  });

  testWidgets('escribir busca solo tras el debounce de 400 ms', (t) async {
    final data = _fake();
    await pumpTv(t, TVSearch(data: data));
    await focusKey(t, 'tv-search-field');
    await _ok(t);
    await t.enterText(find.byType(TextField), 'canal');
    await t.pump(const Duration(milliseconds: 300));
    expect(data.channelCalls, isEmpty);
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    expect(data.channelCalls.length, 1);
  });

  testWidgets('respuesta vieja no pisa a la nueva', (t) async {
    final pending = <String, Completer<List<Channel>>>{
      'ab': Completer<List<Channel>>(),
      'abc': Completer<List<Channel>>(),
    };
    final data = FakeTvData(onSearchChannels: (f) => pending[f.query]!.future);
    await pumpTv(t, TVSearch(data: data));
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'ab');
    await _typeAndSubmit(t, 'abc');
    pending['abc']!.complete([fakeChannel(3)]);
    await t.pumpAndSettle();
    pending['ab']!.complete([fakeChannel(1), fakeChannel(2)]);
    await t.pumpAndSettle();
    expect(find.byKey(_res(0)), findsOneWidget);
    expect(find.byKey(_res(1)), findsNothing);
    expect(find.text('Canal 3'), findsOneWidget);
    expect(find.text('1 resultados'), findsOneWidget);
  });

  testWidgets('error muestra mensaje', (t) async {
    final data = FakeTvData(onSearchChannels: (f) async => throw StateError('x'));
    await pumpTv(t, TVSearch(data: data));
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'canal');
    expect(find.text('Error al buscar. Intenta de nuevo.'), findsOneWidget);
  });

  testWidgets('OK reproduce con la lista de resultados', (t) async {
    final calls = <(int, int)>[];
    await pumpTv(
      t,
      TVSearch(
        data: _fake(),
        onPlay: (ctx, list, i) async {
          calls.add((list.length, i));
          return null;
        },
      ),
    );
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'canal');
    await focusKey(t, 'tv-search-result-3');
    await _ok(t);
    expect(calls, [(10, 3)]);
  });

  testWidgets('OK largo ofrece "Agregar a una lista…" con callback', (t) async {
    Channel? added;
    await pumpTv(
      t,
      TVSearch(
        data: _fake(),
        onAddToPlaylist: (ctx, ch) async => added = ch,
      ),
    );
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'canal');
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    await t.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.text('Agregar a una lista…'), findsOneWidget);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(added?.name, 'Canal 1');
  });

  testWidgets('hay más de una página de resultados: se cargan al bajar',
      (t) async {
    final data = _fake(80);
    await pumpTv(t, TVSearch(data: data));
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'canal');
    await t.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 14; i++) {
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    final pages = data.channelCalls.map((f) => f.page).toList();
    expect(pages.toSet().length, pages.length);
    expect(pages, contains(2));
  });

  testWidgets('el favorito desde la búsqueda usa el id vigente', (t) async {
    final data = _fake()..resolvedIds['Canal 1'] = 777;
    await pumpTv(t, TVSearch(data: data));
    await focusKey(t, 'tv-search-field');
    await _typeAndSubmit(t, 'canal');
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    await t.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t); // Agregar a favoritos
    expect(data.favoriteCalls, [(777, true)]);
  });
}
