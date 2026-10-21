import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/tv_bootstrap.dart';

import 'fakes.dart';

Future<void> _pumpBootstrap(
  WidgetTester t,
  FakeTvData data,
  Future<void> Function() prepare,
) async {
  t.view.physicalSize = const Size(1920, 1080);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TvBootstrap(
      data: data,
      prepare: prepare,
      homeBuilder: (_) => const Scaffold(body: Text('HOME')),
    ),
  ));
}

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('muestra la carga y luego el home, y actualiza en segundo plano',
      (t) async {
    final data = FakeTvData();
    final gate = Completer<void>();
    await _pumpBootstrap(t, data, () => gate.future);
    expect(find.text('Preparando canales…'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(data.refreshCalls.single.onlyStale, isTrue);
    expect(data.refreshCalls.single.onlySourceId, isNull);
  });

  testWidgets('al entrar al home precalienta la guía de programación', (t) async {
    final data = FakeTvData();
    await _pumpBootstrap(t, data, () async {});
    await t.pumpAndSettle();
    expect(data.guideWarmUps, 1);
  });

  testWidgets('con la actualización automática desactivada no refresca',
      (t) async {
    final data = FakeTvData()..autoRefresh = false;
    await _pumpBootstrap(t, data, () async {});
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(data.refreshCalls, isEmpty);
  });

  testWidgets('si falla la preparación permite reintentar', (t) async {
    final data = FakeTvData();
    var calls = 0;
    await _pumpBootstrap(t, data, () async {
      calls++;
      if (calls == 1) throw Exception('sin red');
    });
    await t.pumpAndSettle();
    expect(find.text('No se pudo descargar la lista de canales'), findsOneWidget);
    expect(isFocused(t, const ValueKey('tv-bootstrap-retry')), isTrue);

    await _ok(t); // Reintentar
    expect(calls, 2);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Continuar entra al home aunque haya fallado', (t) async {
    final data = FakeTvData();
    await _pumpBootstrap(t, data, () async => throw Exception('sin red'));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(isFocused(t, const ValueKey('tv-bootstrap-continue')), isTrue);
    await _ok(t);
    expect(find.text('HOME'), findsOneWidget);
  });
}
