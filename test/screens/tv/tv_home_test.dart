import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart';
import 'package:open_tv/screens/tv/tv_home.dart';

import 'fakes.dart';

const _groups = ['Deportes', 'Noticias', 'Cine'];

FakeTvData _fake() => FakeTvData(
      groups: _groups,
      channels: List.generate(
        30,
        (i) => fakeChannel(i + 1, group: _groups[i % _groups.length]),
      ),
    );

Future<void> _home(WidgetTester t, FakeTvData data, {TvPlayCallback? onPlay}) =>
    pumpTv(t, TVHome(data: data, onPlay: onPlay));

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _long(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyRepeatEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

ValueKey<String> _nav(int i) => ValueKey('tv-nav-$i');

Future<void> _goToTab(WidgetTester t, int index) async {
  for (var i = 0; i < index; i++) {
    await _key(t, LogicalKeyboardKey.arrowDown);
  }
}

void main() {
  testWidgets('al iniciar el foco está en Canales (regresión H4)', (t) async {
    await _home(t, _fake());
    expect(isFocused(t, _nav(0)), isTrue);
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets('→ desde Canales entra al primer grupo', (t) async {
    await _home(t, _fake());
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-group-0')), isTrue);
  });

  testWidgets('← desde el grupo vuelve al menú en el mismo ítem', (t) async {
    await _home(t, _fake());
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.arrowLeft);
    expect(isFocused(t, _nav(0)), isTrue);
  });

  testWidgets('OK en el menú también entra al contenido', (t) async {
    await _home(t, _fake());
    await _ok(t);
    expect(isFocused(t, const ValueKey('tv-group-0')), isTrue);
  });

  testWidgets('el menú recorre las 5 pestañas con ↑↓', (t) async {
    await _home(t, _fake());
    for (var i = 1; i < 5; i++) {
      await _key(t, LogicalKeyboardKey.arrowDown);
      expect(isFocused(t, _nav(i)), isTrue, reason: 'pestaña $i');
    }
    await _key(t, LogicalKeyboardKey.arrowDown); // borde inferior
    expect(isFocused(t, _nav(4)), isTrue);
    await _key(t, LogicalKeyboardKey.arrowUp);
    expect(isFocused(t, _nav(3)), isTrue);
  });

  testWidgets('Buscar: → enfoca el campo sin abrir teclado (regresión H3)',
      (t) async {
    await _home(t, _fake());
    await _goToTab(t, 3);
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-search-field')), isTrue);
    expect(t.testTextInput.isVisible, isFalse);
  });

  testWidgets('Ajustes: → enfoca la primera fila', (t) async {
    await _home(t, _fake());
    await _goToTab(t, 4);
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-settings-iptv')), isTrue);
  });

  testWidgets('Mis listas sin listas: → enfoca "Nueva lista"', (t) async {
    await _home(t, _fake());
    await _goToTab(t, 2);
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-playlist-new')), isTrue);
  });

  testWidgets('volver a Canales restaura la última tarjeta enfocada',
      (t) async {
    await _home(t, _fake());
    await focusKey(t, 'tv-channel-5');
    await focusKey(t, 'tv-nav-0');
    await t.pumpAndSettle();
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-channel-5')), isTrue);
  });

  testWidgets('Atrás desde el contenido vuelve al menú', (t) async {
    await _home(t, _fake());
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-group-0')), isTrue);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(isFocused(t, _nav(0)), isTrue);
  });

  testWidgets('Atrás con el teclado abierto lo cierra y otro Atrás vuelve al menú',
      (t) async {
    await _home(t, _fake());
    await _goToTab(t, 3);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _ok(t); // abre el teclado propio
    expect(find.byKey(const ValueKey('tv-key-q')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-key-q')), findsNothing);
    expect(isFocused(t, const ValueKey('tv-search-field')), isTrue);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(isFocused(t, _nav(3)), isTrue);
  });

  testWidgets('Atrás con el teclado de sistema en edición vuelve al menú',
      (t) async {
    await _home(t, _fake());
    await _goToTab(t, 3);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _ok(t);
    await focusKey(t, 'tv-key-system');
    await _ok(t); // pasa al teclado de sistema
    expect(t.testTextInput.isVisible, isTrue);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(isFocused(t, _nav(3)), isTrue);
  });

  testWidgets('pestaña sin enfocables: → deja el foco en el menú', (t) async {
    await _home(t, _fake()); // sin favoritos
    await _goToTab(t, 1);
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, _nav(1)), isTrue);
  });

  testWidgets('favorito marcado en Canales aparece en Favoritos', (t) async {
    final data = _fake();
    await _home(t, data);
    await focusKey(t, 'tv-channel-0');
    await _long(t);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t); // Agregar a favoritos
    expect(data.favoriteCalls, [(data.channels[0].id!, true)]);

    await focusKey(t, 'tv-nav-1');
    await t.pumpAndSettle();
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-channel-0')), isTrue);
    expect(find.text('Canal 1'), findsOneWidget);
  });

  testWidgets('el menú de un canal ofrece "Agregar a una lista…"', (t) async {
    await _home(t, _fake());
    await focusKey(t, 'tv-channel-0');
    await _long(t);
    expect(find.text('Agregar a una lista…'), findsOneWidget);
  });

  testWidgets('actualización de fuentes no recarga mientras se navega',
      (t) async {
    final data = _fake();
    await _home(t, data);
    await focusKey(t, 'tv-channel-3');
    final before = data.groupCalls.length;

    tvSourcesVersion.value++;
    await t.pumpAndSettle();
    expect(data.groupCalls.length, before, reason: 'no recarga bajo los pies');
    expect(isFocused(t, const ValueKey('tv-channel-3')), isTrue);

    await focusKey(t, 'tv-nav-0'); // vuelve al menú: se aplica la recarga
    await t.pumpAndSettle();
    expect(data.groupCalls.length, before + 1);
  });
}
