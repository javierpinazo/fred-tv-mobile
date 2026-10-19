import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/widgets/tv_keyboard.dart';

import 'fakes.dart';

late BuildContext _ctx;

Future<void> _host(WidgetTester t) => pumpTv(
      t,
      Builder(builder: (c) {
        _ctx = c;
        return const SizedBox();
      }),
    );

Future<void> _press(WidgetTester t, String keyName) async {
  await focusKey(t, 'tv-key-$keyName');
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pump();
}

Future<void> _typeText(WidgetTester t, String text) async {
  for (final ch in text.split('')) {
    await _press(t, ch == ' ' ? 'space' : ch);
  }
}

void main() {
  testWidgets('escribe letras, números y símbolos y devuelve el texto',
      (t) async {
    await _host(t);
    late Future<TvKeyboardResult?> result;
    result = showTvKeyboard(_ctx, label: 'Nombre');
    await t.pumpAndSettle();
    await _typeText(t, 'tv24.m3u');
    expect(find.text('tv24.m3u'), findsOneWidget);
    await _press(t, 'done');
    await t.pumpAndSettle();
    final r = (await result)!;
    expect(r.text, 'tv24.m3u');
    expect(r.useSystem, isFalse);
  });

  testWidgets('Mayús alterna mayúsculas', (t) async {
    await _host(t);
    final result = showTvKeyboard(_ctx, label: 'URL');
    await t.pumpAndSettle();
    await _press(t, 'a');
    await _press(t, 'shift');
    await _press(t, 'b');
    await _press(t, 'shift');
    await _press(t, 'c');
    expect(find.text('aBc'), findsOneWidget);
    await _press(t, 'done');
    await t.pumpAndSettle();
    expect((await result)!.text, 'aBc');
  });

  testWidgets('borrar, espacio y limpiar', (t) async {
    await _host(t);
    final result = showTvKeyboard(_ctx, label: 'x');
    await t.pumpAndSettle();
    await _typeText(t, 'ab cd');
    await _press(t, 'back');
    expect(find.text('ab c'), findsOneWidget);
    await _press(t, 'clear');
    await _typeText(t, 'z');
    await _press(t, 'done');
    await t.pumpAndSettle();
    expect((await result)!.text, 'z');
  });

  testWidgets('arranca con el texto inicial', (t) async {
    await _host(t);
    final result = showTvKeyboard(_ctx, label: 'x', initial: 'hola');
    await t.pumpAndSettle();
    expect(find.text('hola'), findsOneWidget);
    await _typeText(t, 's');
    await _press(t, 'done');
    await t.pumpAndSettle();
    expect((await result)!.text, 'holas');
  });

  testWidgets('Atrás cancela y devuelve null', (t) async {
    await _host(t);
    final result = showTvKeyboard(_ctx, label: 'x');
    await t.pumpAndSettle();
    await _typeText(t, 'abc');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('Atrás no se consume en las teclas', (t) async {
    await _host(t);
    showTvKeyboard(_ctx, label: 'x');
    await t.pumpAndSettle();
    await focusKey(t, 'tv-key-q');
    expect(injectBackKey(), isFalse);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
  });

  testWidgets('la tecla de teclado del sistema devuelve el texto y la opción',
      (t) async {
    await _host(t);
    final result = showTvKeyboard(_ctx, label: 'x', initial: 'ab');
    await t.pumpAndSettle();
    await _press(t, 'system');
    await t.pumpAndSettle();
    final r = (await result)!;
    expect(r.useSystem, isTrue);
    expect(r.text, 'ab');
  });

  testWidgets('sin offerSystemKeyboard no aparece esa tecla', (t) async {
    await _host(t);
    showTvKeyboard(_ctx, label: 'x', offerSystemKeyboard: false);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-key-system')), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
  });

  testWidgets('el D-pad recorre las teclas', (t) async {
    await _host(t);
    showTvKeyboard(_ctx, label: 'x');
    await t.pumpAndSettle();
    await focusKey(t, 'tv-key-q');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(isFocused(t, const ValueKey('tv-key-w')), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(isFocused(t, const ValueKey('tv-key-s')), isTrue);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
  });

  testWidgets('un teclado físico también escribe', (t) async {
    await _host(t);
    final result = showTvKeyboard(_ctx, label: 'x');
    await t.pumpAndSettle();
    await focusKey(t, 'tv-key-q');
    await t.sendKeyEvent(LogicalKeyboardKey.keyH, character: 'h');
    await t.sendKeyEvent(LogicalKeyboardKey.keyI, character: 'i');
    await t.pump();
    expect(find.text('hi'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    await _press(t, 'done');
    await t.pumpAndSettle();
    expect((await result)!.text, 'h');
  });

  testWidgets('el botón principal muestra la etiqueta indicada', (t) async {
    await _host(t);
    final f = showTvKeyboard(_ctx, label: 'Buscar canales', doneLabel: 'Buscar');
    await t.pumpAndSettle();
    expect(find.text('Buscar'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(await f, isNull);
  });
}
