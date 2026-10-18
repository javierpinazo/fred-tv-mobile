import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';

import 'fakes.dart';

Widget _box() => const SizedBox(width: 100, height: 100);

void main() {
  testWidgets('OK al soltar llama onSelect una vez', (t) async {
    var selects = 0, longs = 0;
    await pumpTv(
      t,
      TvFocusable(
        autofocus: true,
        onSelect: () => selects++,
        onLongPress: () => longs++,
        builder: (_, __) => _box(),
      ),
    );
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(selects, 1);
    expect(longs, 0);
  });

  testWidgets('OK mantenido llama onLongPress y no onSelect', (t) async {
    var selects = 0, longs = 0;
    await pumpTv(
      t,
      TvFocusable(
        autofocus: true,
        onSelect: () => selects++,
        onLongPress: () => longs++,
        builder: (_, __) => _box(),
      ),
    );
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    for (var i = 0; i < 3; i++) {
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    }
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(longs, 1);
    expect(selects, 0);
  });

  testWidgets('KeyUp sin KeyDown propio no activa', (t) async {
    // El simulador no permite un KeyUp sin KeyDown, así que el KeyDown lo
    // recibe otro widget y el foco pasa al TvFocusable antes de soltar la tecla.
    var selects = 0;
    final other = FocusNode();
    addTearDown(other.dispose);
    await pumpTv(
      t,
      Row(
        children: [
          Focus(
            focusNode: other,
            autofocus: true,
            child: const SizedBox(width: 10, height: 10),
          ),
          TvFocusable(
            key: const ValueKey('tv'),
            onSelect: () => selects++,
            builder: (_, __) => _box(),
          ),
        ],
      ),
    );
    await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
    t
        .state<TvFocusableState>(find.byKey(const ValueKey('tv')))
        .focusNode
        .requestFocus();
    await t.pump();
    await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(selects, 0);
  });

  testWidgets('tecla MENU llama onLongPress', (t) async {
    var longs = 0;
    await pumpTv(
      t,
      TvFocusable(
        autofocus: true,
        onLongPress: () => longs++,
        builder: (_, __) => _box(),
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    expect(longs, 1);
  });

  testWidgets('flechas y Atrás no se consumen', (t) async {
    await pumpTv(
      t,
      Row(
        children: [
          TvFocusable(
            key: const ValueKey('a'),
            autofocus: true,
            onSelect: () {},
            builder: (_, __) => _box(),
          ),
          TvFocusable(
            key: const ValueKey('b'),
            onSelect: () {},
            builder: (_, __) => _box(),
          ),
        ],
      ),
    );
    expect(isFocused(t, const ValueKey('a')), isTrue);
    // goBack no tiene tecla física en el simulador: se inyecta el evento directo.
    final back = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.browserBack,
      logicalKey: LogicalKeyboardKey.goBack,
      timeStamp: Duration.zero,
    );
    expect(HardwareKeyboard.instance.handleKeyEvent(back), isFalse);
    HardwareKeyboard.instance.handleKeyEvent(KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.browserBack,
      logicalKey: LogicalKeyboardKey.goBack,
      timeStamp: Duration.zero,
    ));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(isFocused(t, const ValueKey('b')), isTrue);
  });
}
