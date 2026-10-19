import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/m3u.dart' show HttpStatusException;
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/screens/tv/tv_add_m3u_screen.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

import 'fakes.dart';

const _name = ValueKey('tv-m3u-name');
const _url = ValueKey('tv-m3u-url');
const _add = ValueKey('tv-m3u-add');

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, String key, String text) async {
  await focusKey(t, key);
  await _ok(t);
  await typeOnTvKeyboard(t, text);
}

Color? _colorOf(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('↓ recorre nombre → URL → Agregar', (t) async {
    await pumpTv(t, TvAddM3uScreen(data: FakeTvData()));
    expect(find.text('Agregar lista M3U'), findsOneWidget);
    expect(isFocused(t, _name), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    expect(isFocused(t, _url), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    expect(isFocused(t, _add), isTrue);
  });

  testWidgets('campos vacíos muestran mensaje y no agregan', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TvAddM3uScreen(data: data));
    await focusKey(t, 'tv-m3u-add');
    await _ok(t);
    expect(find.text('Completa todos los campos'), findsOneWidget);
    expect(_colorOf(t, 'Completa todos los campos'), TvTheme.error);
    expect(data.addedSources, isEmpty);
  });

  testWidgets('URL sin http(s) muestra mensaje', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TvAddM3uScreen(data: data));
    await _type(t, 'tv-m3u-name', 'Mi lista');
    await _type(t, 'tv-m3u-url', 'ftp://x/y.m3u');
    await focusKey(t, 'tv-m3u-add');
    await _ok(t);
    expect(find.text('La URL debe empezar con http:// o https://'),
        findsOneWidget);
    expect(data.addedSources, isEmpty);
  });

  testWidgets('éxito agrega, avisa y limpia los campos', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TvAddM3uScreen(data: data));
    await _type(t, 'tv-m3u-name', ' Mi lista ');
    await _type(t, 'tv-m3u-url', 'HTTPS://example.com/lista.m3u');
    await focusKey(t, 'tv-m3u-add');
    await _ok(t);
    final added = data.addedSources.single;
    expect(added.name, 'Mi lista');
    expect(added.url, 'HTTPS://example.com/lista.m3u');
    expect(added.sourceType, SourceType.m3uUrl);
    expect(find.text('Lista agregada correctamente'), findsOneWidget);
    expect(_colorOf(t, 'Lista agregada correctamente'), TvTheme.success);
    expect(find.text('Mi lista'), findsNothing, reason: 'campo limpio');
  });

  testWidgets('nombre repetido muestra mensaje', (t) async {
    final data = FakeTvData()..addSourceError = StateError('duplicate');
    await pumpTv(t, TvAddM3uScreen(data: data));
    await _type(t, 'tv-m3u-name', 'Mi lista');
    await _type(t, 'tv-m3u-url', 'http://example.com/a.m3u');
    await focusKey(t, 'tv-m3u-add');
    await _ok(t);
    expect(find.text('Ya existe una lista con ese nombre'), findsOneWidget);
  });

  testWidgets('error de red o 404 muestra mensaje', (t) async {
    final data = FakeTvData()..addSourceError = const HttpStatusException(404);
    await pumpTv(t, TvAddM3uScreen(data: data));
    await _type(t, 'tv-m3u-name', 'Mi lista');
    await _type(t, 'tv-m3u-url', 'http://example.com/a.m3u');
    await focusKey(t, 'tv-m3u-add');
    await _ok(t);
    expect(find.text('Esta lista no está disponible'), findsOneWidget);
  });
}
