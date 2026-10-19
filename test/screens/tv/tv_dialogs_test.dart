import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';

import 'fakes.dart';

late BuildContext _ctx;

Future<void> _host(WidgetTester t) => pumpTv(
      t,
      Builder(builder: (c) {
        _ctx = c;
        return const SizedBox();
      }),
    );

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _press(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('showTvConfirm: foco inicial en Cancelar → false', (t) async {
    await _host(t);
    final f = showTvConfirm(_ctx, message: '¿Eliminar?');
    await t.pumpAndSettle();
    expect(isFocused(t, const ValueKey('tv-confirm-cancel')), isTrue);
    await _ok(t);
    expect(await f, isFalse);
  });

  testWidgets('showTvConfirm: ← llega a Eliminar → true', (t) async {
    await _host(t);
    final f = showTvConfirm(_ctx, message: '¿Eliminar?');
    await t.pumpAndSettle();
    await _press(t, LogicalKeyboardKey.arrowLeft);
    expect(isFocused(t, const ValueKey('tv-confirm-ok')), isTrue);
    await _ok(t);
    expect(await f, isTrue);
  });

  testWidgets('showTvTextPrompt devuelve el texto recortado', (t) async {
    await _host(t);
    final f = showTvTextPrompt(_ctx, title: 'Nueva lista', label: 'Nombre');
    await t.pumpAndSettle();
    await _ok(t); // abre el teclado propio
    await typeOnTvKeyboard(t, ' Mi lista ');
    await _press(t, LogicalKeyboardKey.arrowDown);
    expect(isFocused(t, const ValueKey('tv-prompt-confirm')), isTrue);
    await _ok(t);
    expect(await f, 'Mi lista');
  });

  testWidgets('showTvTextPrompt vacío devuelve null', (t) async {
    await _host(t);
    final f = showTvTextPrompt(_ctx, title: 'Nueva lista', label: 'Nombre');
    await t.pumpAndSettle();
    await _press(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(await f, isNull);
  });

  testWidgets('showTvOptions devuelve el valor del ítem elegido', (t) async {
    await _host(t);
    final f = showTvOptions<int>(
      _ctx,
      title: 'Opciones',
      options: [('Uno', 1), ('Dos', 2), ('Tres', 3)],
    );
    await t.pumpAndSettle();
    await _press(t, LogicalKeyboardKey.arrowDown);
    await _press(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(await f, 3);
  });

  testWidgets('Atrás cierra showTvOptions con null', (t) async {
    await _host(t);
    final f = showTvOptions<int>(_ctx, title: 'x', options: [('Uno', 1)]);
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(await f, isNull);
  });
}
