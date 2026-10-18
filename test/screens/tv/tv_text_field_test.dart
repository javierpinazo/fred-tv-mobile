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

Widget _layout(TextEditingController c, {ValueChanged<String>? onSubmitted}) =>
    Column(
      children: [
        TvTextField(
          key: const ValueKey('f'),
          controller: c,
          label: 'Campo',
          hint: 'Presiona OK para escribir',
          autofocus: true,
          onSubmitted: onSubmitted,
        ),
        TvFocusable(
          key: const ValueKey('below'),
          onSelect: () {},
          builder: (_, __) => const SizedBox(width: 100, height: 50),
        ),
      ],
    );

void main() {
  testWidgets('enfocar no abre el teclado', (t) async {
    await pumpTv(t, _layout(TextEditingController()));
    expect(isFocused(t, const ValueKey('f')), isTrue);
    expect(t.testTextInput.isVisible, isFalse);
    expect(find.text('Presiona OK para escribir'), findsOneWidget);
  });

  testWidgets('OK entra a edición y ↓ sale al siguiente', (t) async {
    await pumpTv(t, _layout(TextEditingController()));
    await _ok(t);
    expect(t.testTextInput.isVisible, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    expect(isFocused(t, const ValueKey('below')), isTrue);
  });

  testWidgets('enviar llama onSubmitted y vuelve al modo botón', (t) async {
    String? submitted;
    final c = TextEditingController();
    await pumpTv(t, _layout(c, onSubmitted: (v) => submitted = v));
    await _ok(t);
    await t.enterText(find.byType(TextField), 'hola');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(submitted, 'hola');
    expect(isFocused(t, const ValueKey('f')), isTrue);
    expect(find.text('hola'), findsOneWidget);
  });
}
