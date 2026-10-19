import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/widgets/tv_pin_dialog.dart';

import 'fakes.dart';

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

String? _result;
bool _done = false;

Future<void> _open(WidgetTester t, {String title = 'PIN'}) async {
  _result = null;
  _done = false;
  await pumpTv(
    t,
    Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () async {
            _result = await showTvPinPrompt(context, title: title);
            _done = true;
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await t.tap(find.text('abrir'));
  await t.pumpAndSettle();
}

Future<void> _keypad(WidgetTester t, List<int> digits) async {
  for (final d in digits) {
    await focusKey(t, 'tv-pin-key-$d');
    await _ok(t);
  }
}

void main() {
  testWidgets('muestra el título y cuatro puntos vacíos', (t) async {
    await _open(t, title: 'Introduce el PIN');
    expect(find.text('Introduce el PIN'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-pin-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-pin-dot-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-pin-dot-4')), findsNothing);
    expect(_done, isFalse);
  });

  testWidgets('el teclado en pantalla devuelve el PIN al completar 4 dígitos',
      (t) async {
    await _open(t);
    await _keypad(t, [4, 8, 2, 1]);
    expect(_done, isTrue);
    expect(_result, '4821');
  });

  testWidgets('las teclas numéricas del mando también escriben', (t) async {
    await _open(t);
    for (final k in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.digit4,
    ]) {
      await t.sendKeyEvent(k);
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(_result, '1234');
  });

  testWidgets('borrar quita el último dígito', (t) async {
    await _open(t);
    await _keypad(t, [1, 2]);
    await focusKey(t, 'tv-pin-back');
    await _ok(t);
    await _keypad(t, [3, 4, 5]);
    expect(_result, '1345');
  });

  testWidgets('la tecla Retroceso del teclado también borra', (t) async {
    await _open(t);
    await t.sendKeyEvent(LogicalKeyboardKey.digit1);
    await t.sendKeyEvent(LogicalKeyboardKey.digit2);
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    for (final k in [
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ]) {
      await t.sendKeyEvent(k);
    }
    await t.pumpAndSettle();
    expect(_result, '1789');
  });

  testWidgets('Cancelar devuelve null y Atrás también', (t) async {
    await _open(t);
    await _keypad(t, [1, 2]);
    await focusKey(t, 'tv-pin-cancel');
    await _ok(t);
    expect(_done, isTrue);
    expect(_result, isNull);

    await _open(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_done, isTrue);
    expect(_result, isNull);
  });
}
