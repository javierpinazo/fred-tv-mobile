import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_text_field.dart';

import 'fakes.dart';

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Widget _layout(
  TextEditingController c, {
  ValueChanged<String>? onSubmitted,
  ValueChanged<String>? onChanged,
}) =>
    Column(
      children: [
        TvTextField(
          key: const ValueKey('f'),
          controller: c,
          label: 'Campo',
          hint: 'Presiona OK para escribir',
          autofocus: true,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
        ),
        TvFocusable(
          key: const ValueKey('below'),
          onSelect: () {},
          builder: (_, __) => const SizedBox(width: 100, height: 50),
        ),
      ],
    );

/// Abre el teclado propio y pasa al teclado del sistema con su tecla.
Future<void> _toSystemKeyboard(WidgetTester t) async {
  await _ok(t);
  await focusKey(t, 'tv-key-system');
  await _ok(t);
}

void main() {
  testWidgets('enfocar no abre ningún teclado', (t) async {
    await pumpTv(t, _layout(TextEditingController()));
    expect(isFocused(t, const ValueKey('f')), isTrue);
    expect(t.testTextInput.isVisible, isFalse);
    expect(find.byKey(const ValueKey('tv-key-q')), findsNothing);
    expect(find.text('Presiona OK para escribir'), findsOneWidget);
  });

  testWidgets('OK abre el teclado propio, no el del sistema', (t) async {
    await pumpTv(t, _layout(TextEditingController()));
    await _ok(t);
    expect(find.byKey(const ValueKey('tv-key-q')), findsOneWidget);
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets('Listo llama onChanged y onSubmitted y vuelve al campo',
      (t) async {
    String? submitted, changed;
    final c = TextEditingController();
    await pumpTv(
      t,
      _layout(c,
          onSubmitted: (v) => submitted = v, onChanged: (v) => changed = v),
    );
    await _ok(t);
    await typeOnTvKeyboard(t, 'hola');
    expect(submitted, 'hola');
    expect(changed, 'hola');
    expect(c.text, 'hola');
    expect(isFocused(t, const ValueKey('f')), isTrue);
    expect(find.text('hola'), findsOneWidget);
  });

  testWidgets('Atrás cancela sin cambiar el texto', (t) async {
    String? submitted;
    final c = TextEditingController(text: 'previo');
    await pumpTv(t, _layout(c, onSubmitted: (v) => submitted = v));
    await _ok(t);
    await typeOnTvKeyboard(t, 'otro', submit: false);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(c.text, 'previo');
    expect(submitted, isNull);
    expect(isFocused(t, const ValueKey('f')), isTrue);
  });

  testWidgets('el teclado propio arranca con el texto actual', (t) async {
    final c = TextEditingController(text: 'abc');
    await pumpTv(t, _layout(c));
    await _ok(t);
    await typeOnTvKeyboard(t, 'd', clear: false);
    expect(c.text, 'abcd');
  });

  testWidgets('Voz / sistema pasa al teclado de Android con el texto',
      (t) async {
    final c = TextEditingController(text: 'ab');
    await pumpTv(t, _layout(c));
    await _toSystemKeyboard(t);
    expect(find.byType(TextField), findsOneWidget);
    expect(t.testTextInput.isVisible, isTrue);
    expect(c.text, 'ab');
  });

  testWidgets('en teclado de sistema ↓ ← → no salen: se dejan al teclado',
      (t) async {
    await pumpTv(t, _layout(TextEditingController()));
    await _toSystemKeyboard(t);
    for (final k in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await t.sendKeyEvent(k);
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget, reason: '$k no debe salir');
      expect(isFocused(t, const ValueKey('below')), isFalse);
    }
  });

  testWidgets('en teclado de sistema ↑ sale del modo edición', (t) async {
    await pumpTv(t, _layout(TextEditingController()));
    await _toSystemKeyboard(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(isFocused(t, const ValueKey('f')), isTrue);
  });

  testWidgets('en teclado de sistema, enviar llama onSubmitted', (t) async {
    String? submitted;
    await pumpTv(
      t,
      _layout(TextEditingController(), onSubmitted: (v) => submitted = v),
    );
    await _toSystemKeyboard(t);
    await t.enterText(find.byType(TextField), 'hola');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(submitted, 'hola');
    expect(isFocused(t, const ValueKey('f')), isTrue);
  });

  testWidgets('si el foco se va a otro sitio en teclado de sistema no lo recupera',
      (t) async {
    await pumpTv(t, _layout(TextEditingController()));
    await _toSystemKeyboard(t);
    await focusKey(t, 'below');
    await t.pumpAndSettle();
    expect(isFocused(t, const ValueKey('below')), isTrue);
    expect(isFocused(t, const ValueKey('f')), isFalse);
  });
}
