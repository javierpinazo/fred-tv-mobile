import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/widgets/tv_button.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

import 'fakes.dart';

void main() {
  testWidgets('con foco invierte los colores; sin foco usa los normales',
      (t) async {
    await pumpTv(
      t,
      Row(children: [
        TvButton(
            key: const ValueKey('a'),
            label: 'Aceptar',
            autofocus: true,
            onSelect: () {}),
        TvButton(key: const ValueKey('b'), label: 'Cancelar', onSelect: () {}),
      ]),
    );
    expect(t.widget<Text>(find.text('Aceptar')).style!.color,
        TvTheme.background);
    expect(t.widget<Text>(find.text('Cancelar')).style!.color,
        TvTheme.textPrimary);
  });

  testWidgets('OK llama a onSelect', (t) async {
    var n = 0;
    await pumpTv(t, TvButton(label: 'Ir', autofocus: true, onSelect: () => n++));
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(n, 1);
  });
}
