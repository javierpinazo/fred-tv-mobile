import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/iptv_org_catalog.dart';
import 'package:open_tv/backend/m3u.dart' show HttpStatusException;
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/screens/tv/tv_iptv_org_screen.dart';

import 'fakes.dart';

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

ValueKey<String> _item(int i) => ValueKey('tv-iptv-item-$i');

IptvOrgCatalog _catalog({int countriesStatus = 200}) => IptvOrgCatalog(
      client: MockClient((request) async {
        if (request.url.path.endsWith('countries.json')) {
          return countriesStatus == 200
              ? http.Response.bytes(
                  utf8.encode(
                      '[{"name":"Peru","code":"PE","flag":"🇵🇪"},{"name":"Chile","code":"CL","flag":"🇨🇱"}]'),
                  200)
              : http.Response('x', countriesStatus);
        }
        return http.Response(
            '[{"id":"news","name":"News"},{"id":"xxx","name":"XXX"}]', 200);
      }),
    );

void main() {
  testWidgets('Recomendados muestra Perú primero', (t) async {
    await pumpTv(t, TvIptvOrgScreen(data: FakeTvData()));
    expect(find.text('Listas de iptv-org'), findsOneWidget);
    expect(find.text('Recomendados'), findsOneWidget);
    expect(find.text('Países'), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    final first = find.descendant(
        of: find.byKey(_item(0)), matching: find.text('Perú'));
    expect(first, findsOneWidget);
  });

  testWidgets('agregar Perú llama addSource con la URL correcta', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TvIptvOrgScreen(data: data));
    await focusKey(t, 'tv-iptv-item-0');
    await _ok(t);
    final added = data.addedSources.single;
    expect(added.name, 'iptv-org · Perú');
    expect(added.url, 'https://iptv-org.github.io/iptv/countries/pe.m3u');
    expect(added.sourceType, SourceType.m3uUrl);
    expect(find.text('«Perú» agregada'), findsOneWidget);
    expect(find.text('Agregada'), findsOneWidget);
  });

  testWidgets('ítem ya agregado muestra chip y no vuelve a agregar', (t) async {
    final data = FakeTvData(sources: [
      Source(
        id: 1,
        name: 'iptv-org · Perú',
        url: 'https://iptv-org.github.io/iptv/countries/pe.m3u',
        sourceType: SourceType.m3uUrl,
      ),
    ]);
    await pumpTv(t, TvIptvOrgScreen(data: data));
    expect(find.text('Agregada'), findsOneWidget);
    await focusKey(t, 'tv-iptv-item-0');
    await _ok(t);
    expect(data.addedSources, isEmpty);
    expect(find.text('Ya agregada'), findsOneWidget);
  });

  testWidgets('404 muestra "Esta lista no está disponible"', (t) async {
    final data = FakeTvData()..addSourceError = const HttpStatusException(404);
    await pumpTv(t, TvIptvOrgScreen(data: data));
    await focusKey(t, 'tv-iptv-item-0');
    await _ok(t);
    expect(find.text('Esta lista no está disponible'), findsOneWidget);
  });

  testWidgets('otros errores muestran "No se pudo agregar la lista"', (t) async {
    final data = FakeTvData()..addSourceError = Exception('red');
    await pumpTv(t, TvIptvOrgScreen(data: data));
    await focusKey(t, 'tv-iptv-item-0');
    await _ok(t);
    expect(find.text('No se pudo agregar la lista'), findsOneWidget);
  });

  testWidgets('Países se carga del API y queda ordenado', (t) async {
    final data = FakeTvData(catalog: _catalog());
    await pumpTv(t, TvIptvOrgScreen(data: data));
    await focusKey(t, 'tv-iptv-section-1');
    await t.pumpAndSettle();
    expect(find.descendant(of: find.byKey(_item(0)), matching: find.text('Chile')),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(_item(1)), matching: find.text('Peru')),
        findsOneWidget);
  });

  testWidgets('Categorías oculta xxx', (t) async {
    final data = FakeTvData(catalog: _catalog());
    await pumpTv(t, TvIptvOrgScreen(data: data));
    await focusKey(t, 'tv-iptv-section-2');
    await t.pumpAndSettle();
    expect(find.text('News'), findsOneWidget);
    expect(find.text('XXX'), findsNothing);
  });

  testWidgets('error del catálogo muestra Reintentar', (t) async {
    final data = FakeTvData(catalog: _catalog(countriesStatus: 500));
    await pumpTv(t, TvIptvOrgScreen(data: data));
    await focusKey(t, 'tv-iptv-section-1');
    await t.pumpAndSettle();
    expect(find.text('No se pudo cargar el catálogo. Revisa tu conexión.'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('→ desde la sección entra a la lista y ← vuelve a la sección',
      (t) async {
    await pumpTv(t, TvIptvOrgScreen(data: FakeTvData()));
    await focusKey(t, 'tv-iptv-section-0');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(isFocused(t, _item(0)), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(isFocused(t, const ValueKey('tv-iptv-section-0')), isTrue);
  });
}
