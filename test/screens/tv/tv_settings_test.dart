import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/backend/sql.dart' show customSourceName;
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';
import 'package:open_tv/screens/tv/tv_settings.dart';

import 'fakes.dart';

Source _src(
  int id,
  String name, {
  bool enabled = true,
  SourceType type = SourceType.m3uUrl,
}) =>
    Source(
      id: id,
      name: name,
      url: 'http://example.com/$id.m3u',
      sourceType: type,
      enabled: enabled,
    );

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

const _iptv = ValueKey('tv-settings-iptv');
const _m3u = ValueKey('tv-settings-m3u');
const _refresh = ValueKey('tv-settings-refresh');
const _auto = ValueKey('tv-settings-auto');

void main() {
  testWidgets('↓ recorre todas las filas (regresión H2)', (t) async {
    final data = FakeTvData(sources: [_src(1, 'Lista 1'), _src(2, 'Lista 2')]);
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-iptv');
    expect(isFocused(t, _iptv), isTrue);
    for (final key in [_m3u, _refresh, _auto,
        const ValueKey('tv-settings-buffer'),
        const ValueKey('tv-settings-engine'),
        const ValueKey('tv-settings-textsize'),
        const ValueKey('tv-settings-contrast'),
        const ValueKey('tv-settings-hidedead'),
        const ValueKey('tv-settings-deadcount'),
        const ValueKey('tv-settings-hideadult'),
        const ValueKey('tv-settings-pin'),
        const ValueKey('tv-source-1'), const ValueKey('tv-source-2')]) {
      await _key(t, LogicalKeyboardKey.arrowDown);
      expect(isFocused(t, key), isTrue, reason: '$key');
    }
  });

  testWidgets('no lista Custom Channels y muestra el tiempo desde la última',
      (t) async {
    final data = FakeTvData(sources: [
      _src(1, 'Reciente'),
      _src(2, 'Nunca'),
      _src(3, 'Apagada', enabled: false),
      _src(9, customSourceName, type: SourceType.m3u),
    ]);
    data.lastRefreshes[1] =
        DateTime.now().subtract(const Duration(hours: 3, minutes: 5));
    await pumpTv(t, TVSettings(data: data));
    // El ListView es perezoso: se agranda la ventana para construir todas las filas.
    t.view.physicalSize = const Size(1920, 3000);
    await t.pump();
    expect(find.text('Reciente'), findsOneWidget);
    expect(find.text('Actualizada hace 3 h'), findsOneWidget);
    expect(find.text('Nunca actualizada'), findsOneWidget);
    expect(find.text('Desactivada'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-source-9')), findsNothing);
    expect(find.text(customSourceName), findsNothing);
  });

  testWidgets('Actualizar listas ahora llama refreshSources y avisa',
      (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-refresh');
    await _ok(t);
    expect(data.refreshCalls.single.onlyStale, isFalse);
    expect(data.refreshCalls.single.onlySourceId, isNull);
    expect(find.text('Listas actualizadas'), findsOneWidget);
  });

  testWidgets('si alguna lista falla lo indica', (t) async {
    final data = FakeTvData()
      ..refreshResult =
          const SourceRefreshResult(refreshed: 1, failedNames: ['A', 'B']);
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-refresh');
    await _ok(t);
    expect(find.text('2 listas no se pudieron actualizar'), findsOneWidget);
  });

  testWidgets('con refresco en curso no lanza otro', (t) async {
    final data = FakeTvData()..refreshing = true;
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-refresh');
    await _ok(t);
    expect(data.refreshCalls, isEmpty);
    expect(find.text('Ya se están actualizando las listas'), findsOneWidget);
  });

  testWidgets('alternar actualización automática', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    expect(find.text('Activada'), findsOneWidget);
    await focusKey(t, 'tv-settings-auto');
    await _ok(t);
    expect(data.autoRefresh, isFalse);
    expect(find.text('Desactivada'), findsOneWidget);
  });

  testWidgets('el buffer de reproducción cambia con OK y se recuerda',
      (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    expect(find.text('2 s'), findsOneWidget);
    await focusKey(t, 'tv-settings-buffer');
    await _ok(t);
    expect(data.bufferSecs, 5);
    expect(find.text('5 s'), findsOneWidget);
    await _ok(t);
    expect(data.bufferSecs, 10);
    await _ok(t);
    expect(data.bufferSecs, 0);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('tv-settings-buffer')),
            matching: find.text('Desactivado')),
        findsOneWidget);
    await _ok(t);
    expect(data.bufferSecs, 2);
  });

  testWidgets('el motor de video alterna entre Automático y Solo mpv',
      (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    expect(find.text('Automático'), findsOneWidget);
    await focusKey(t, 'tv-settings-engine');
    await _ok(t);
    expect(data.engineMode, TvEngineMode.mpv);
    expect(find.text('Solo mpv'), findsOneWidget);
    await _ok(t);
    expect(data.engineMode, TvEngineMode.auto);
  });

  testWidgets('el tamaño de letra rota y se guarda', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    expect(find.text('100 %'), findsOneWidget);
    await focusKey(t, 'tv-settings-textsize');
    await _ok(t);
    expect(data.textScale, 1.15);
    expect(find.text('115 %'), findsOneWidget);
    await _ok(t);
    expect(data.textScale, 1.3);
    await _ok(t);
    expect(data.textScale, 1.0);
  });

  testWidgets('el alto contraste se activa y desactiva', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-contrast');
    await _ok(t);
    expect(data.highContrast, isTrue);
    expect(find.text('Activado'), findsOneWidget);
    await _ok(t);
    expect(data.highContrast, isFalse);
    expect(find.text('Desactivado'), findsWidgets);
  });

  testWidgets('ocultar canales caídos se activa y se recuerda', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-hidedead');
    await _ok(t);
    expect(data.hideDead, isTrue);
    await _ok(t);
    expect(data.hideDead, isFalse);
  });

  testWidgets('canales caídos: muestra la cuenta y limpia con confirmación',
      (t) async {
    final data = FakeTvData()..deadCount = 3;
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-deadcount'); // desplaza hasta la fila
    expect(find.text('3 marcados'), findsOneWidget);
    await _ok(t);
    expect(find.text('Limpiar'), findsOneWidget);
    await _ok(t); // el foco inicial del diálogo es Cancelar
    expect(data.deadCleared, isFalse);
    await focusKey(t, 'tv-settings-deadcount');
    await _ok(t);
    await _key(t, LogicalKeyboardKey.arrowLeft); // de Cancelar a Limpiar
    await _ok(t);
    expect(data.deadCleared, isTrue);
    expect(find.text('Ninguno'), findsOneWidget);
  });

  Future<void> pin(WidgetTester t, String digits) async {
    for (final d in digits.split('')) {
      await focusKey(t, 'tv-pin-key-$d');
      await _ok(t);
    }
  }

  testWidgets('ocultar contenido adulto sin PIN se activa y desactiva solo',
      (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-hideadult');
    await _ok(t);
    expect(data.hideAdult, isTrue);
    await _ok(t);
    expect(data.hideAdult, isFalse);
  });

  testWidgets('crear un PIN pide escribirlo dos veces', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-pin');
    expect(find.text('Sin PIN'), findsOneWidget);
    await _ok(t);
    expect(find.text('Nuevo PIN'), findsOneWidget);
    await pin(t, '1234');
    expect(find.text('Repite el PIN'), findsOneWidget);
    await pin(t, '1234');
    expect(data.pin, '1234');
    expect(find.text('PIN guardado'), findsOneWidget);
    expect(find.text('Configurado'), findsOneWidget);
  });

  testWidgets('si la repetición no coincide no se guarda el PIN', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-pin');
    await _ok(t);
    await pin(t, '1234');
    await pin(t, '1235');
    expect(data.pin, isNull);
    expect(find.text('Los PIN no coinciden'), findsOneWidget);
  });

  testWidgets('con PIN, desactivar el ocultado exige el PIN correcto',
      (t) async {
    final data = FakeTvData()
      ..pin = '1234'
      ..hideAdult = true;
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-hideadult');
    await _ok(t);
    await pin(t, '0000');
    expect(find.text('PIN incorrecto'), findsOneWidget);
    expect(data.hideAdult, isTrue);

    await focusKey(t, 'tv-settings-hideadult');
    await _ok(t);
    await pin(t, '1234');
    expect(data.hideAdult, isFalse);
  });

  testWidgets('activar el ocultado nunca pide PIN aunque exista', (t) async {
    final data = FakeTvData()..pin = '1234';
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-hideadult');
    await _ok(t);
    expect(data.hideAdult, isTrue);
    expect(find.text('Introduce el PIN'), findsNothing);
  });

  testWidgets('quitar el PIN exige el actual', (t) async {
    final data = FakeTvData()..pin = '1234';
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-pin');
    await _ok(t);
    await pin(t, '1234');
    expect(find.text('Quitar PIN'), findsOneWidget);
    await focusKey(t, 'tv-option-1');
    await _ok(t);
    expect(data.pin, isNull);
    expect(find.text('PIN quitado'), findsOneWidget);
  });

  testWidgets('cambiar el PIN: actual, nuevo y repetición', (t) async {
    final data = FakeTvData()..pin = '1234';
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-pin');
    await _ok(t);
    await pin(t, '1234');
    await focusKey(t, 'tv-option-0');
    await _ok(t);
    await pin(t, '5678');
    await pin(t, '5678');
    expect(data.pin, '5678');
  });

  testWidgets('un PIN actual incorrecto no deja cambiar nada', (t) async {
    final data = FakeTvData()..pin = '1234';
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-pin');
    await _ok(t);
    await pin(t, '9999');
    expect(find.text('PIN incorrecto'), findsOneWidget);
    expect(find.text('Quitar PIN'), findsNothing);
    expect(data.pin, '1234');
  });

  testWidgets('desactivar una fuente', (t) async {
    final data = FakeTvData(sources: [_src(1, 'Lista 1')]);
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-source-1');
    await _ok(t);
    expect(find.text('Actualizar'), findsOneWidget);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t); // Desactivar
    expect(data.enabledCalls, [(1, false)]);
  });

  testWidgets('actualizar una fuente usa onlySourceId', (t) async {
    final data = FakeTvData(sources: [_src(7, 'Lista 7')]);
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-source-7');
    await _ok(t);
    await _ok(t); // Actualizar
    expect(data.refreshCalls.single.onlySourceId, 7);
  });

  testWidgets('eliminar fuente pide confirmación', (t) async {
    final data = FakeTvData(sources: [_src(1, 'Lista 1')]);
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-source-1');
    await _ok(t);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t); // Eliminar
    expect(find.text('¿Eliminar la fuente «Lista 1» y sus canales?'),
        findsOneWidget);
    await _ok(t); // el foco inicial es Cancelar
    expect(data.deletedIds, isEmpty);

    await focusKey(t, 'tv-source-1');
    await _ok(t);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    await _key(t, LogicalKeyboardKey.arrowLeft);
    await _ok(t); // Eliminar
    expect(data.deletedIds, [1]);
    expect(find.byKey(const ValueKey('tv-source-1')), findsNothing);
  });

  testWidgets('las filas abren las pantallas de alta', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TVSettings(data: data));
    await focusKey(t, 'tv-settings-iptv');
    await _ok(t);
    expect(find.text('Listas de iptv-org'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await focusKey(t, 'tv-settings-m3u');
    await _ok(t);
    expect(find.text('Agregar lista M3U'), findsOneWidget);
  });
}
