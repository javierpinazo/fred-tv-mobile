import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';
import 'package:open_tv/screens/tv/widgets/tv_guide_dialog.dart';

import 'fakes.dart';

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

// 19-oct-2026 en Lima: 08:00 AM, 09:00 AM, 10:00 AM (UTC+5h).
List<GuideProgram> _programs() => [
      GuideProgram(
          start: DateTime.utc(2026, 10, 19, 13),
          title: 'Primera hora',
          description: 'La información relevante.'),
      GuideProgram(start: DateTime.utc(2026, 10, 19, 14), title: 'Deporte express'),
      GuideProgram(
          start: DateTime.utc(2026, 10, 19, 15),
          title: 'Más conectados',
          description: 'El magazine de las mañanas.'),
    ];

final _channel = Channel(
    name: 'TV Peru (1080p)',
    mediaType: MediaType.livestream,
    sourceId: 1,
    favorite: true);

// Son las 09:30 en Lima (14:30 UTC): "ahora" es Deporte express.
DateTime _clock() => DateTime.utc(2026, 10, 19, 14, 30);

Future<void> _open(WidgetTester t, FakeTvData data) async {
  await pumpTv(
    t,
    Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () =>
              showTvGuide(context, data: data, channel: _channel, clock: _clock),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await t.tap(find.text('abrir'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('muestra la programación del día y marca lo que se emite ahora',
      (t) async {
    final data = FakeTvData()..guidePrograms = _programs();
    await _open(t, data);
    expect(find.text('TV Peru (1080p)'), findsOneWidget);
    expect(find.text('Primera hora'), findsOneWidget);
    expect(find.text('Deporte express'), findsOneWidget);
    expect(find.text('Más conectados'), findsOneWidget);
    expect(find.text('08:00 AM'), findsOneWidget);
    expect(find.text('La información relevante.'), findsOneWidget);
    expect(find.text('AHORA'), findsOneWidget);
    expect(data.guideDayCalls.single, DateTime(2026, 10, 19));
  });

  testWidgets('con muchos programas el foco llega igual al que se emite ahora',
      (t) async {
    // 40 programas de media hora; "ahora" cae en el número 30 (lejos de la
    // pantalla): la lista debe desplazarse hasta él y enfocarlo.
    final data = FakeTvData()
      ..guidePrograms = [
        for (var i = 0; i < 40; i++)
          GuideProgram(
            start: DateTime.utc(2026, 10, 19, 5).add(Duration(minutes: 30 * i)),
            title: 'Programa $i',
            description: 'Descripción del programa $i que ocupa un par de líneas.',
          ),
      ];
    await pumpTv(
      t,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showTvGuide(context,
                data: data,
                channel: _channel,
                // 05:00 UTC + 15 h = 20:00 UTC → programa 30 (hora de Lima 15:00).
                clock: () => DateTime.utc(2026, 10, 19, 20, 10)),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(isFocused(t, const ValueKey('tv-guide-item-30')), isTrue);
    expect(find.text('Programa 30'), findsOneWidget);
  });

  testWidgets('el foco empieza en el programa que se emite ahora', (t) async {
    final data = FakeTvData()..guidePrograms = _programs();
    await _open(t, data);
    expect(isFocused(t, const ValueKey('tv-guide-item-1')), isTrue);
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(isFocused(t, const ValueKey('tv-guide-item-2')), isTrue);
    await _key(t, LogicalKeyboardKey.arrowUp);
    await _key(t, LogicalKeyboardKey.arrowUp);
    await _key(t, LogicalKeyboardKey.arrowUp);
    // Arriba de la lista están los botones de día.
    expect(isFocused(t, const ValueKey('tv-guide-next')) ||
        isFocused(t, const ValueKey('tv-guide-prev')), isTrue);
  });

  testWidgets('el botón de día siguiente carga el día de mañana sin "ahora"',
      (t) async {
    final data = FakeTvData()..guidePrograms = _programs();
    await _open(t, data);
    await focusKey(t, 'tv-guide-next');
    await _ok(t);
    expect(data.guideDayCalls.last, DateTime(2026, 10, 20));
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.text('AHORA'), findsNothing);
    // Otra vez para volver: "Anterior".
    await focusKey(t, 'tv-guide-prev');
    await _ok(t);
    expect(data.guideDayCalls.last, DateTime(2026, 10, 19));
    expect(find.text('Hoy'), findsOneWidget);
  });

  testWidgets('no se puede ir a antes de hoy ni más de 6 días adelante',
      (t) async {
    final data = FakeTvData()..guidePrograms = _programs();
    await _open(t, data);
    await focusKey(t, 'tv-guide-prev');
    await _ok(t);
    expect(data.guideDayCalls, hasLength(1)); // sigue en hoy: no hubo carga
    for (var i = 0; i < 8; i++) {
      await focusKey(t, 'tv-guide-next');
      await _ok(t);
    }
    expect(data.guideDayCalls.last, DateTime(2026, 10, 25));
  });

  testWidgets('si falla la carga avisa y Reintentar vuelve a pedirla', (t) async {
    final data = FakeTvData()
      ..guidePrograms = _programs()
      ..guideFails = true;
    await _open(t, data);
    expect(find.text('No se pudo cargar la guía'), findsOneWidget);
    data.guideFails = false;
    await focusKey(t, 'tv-guide-retry');
    await _ok(t);
    expect(find.text('Primera hora'), findsOneWidget);
    expect(find.text('No se pudo cargar la guía'), findsNothing);
  });

  testWidgets('un día sin programas lo dice', (t) async {
    final data = FakeTvData()..guidePrograms = [];
    await _open(t, data);
    expect(find.text('Sin programación para este día'), findsOneWidget);
  });

  testWidgets('Atrás cierra la guía', (t) async {
    final data = FakeTvData()..guidePrograms = _programs();
    await _open(t, data);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Primera hora'), findsNothing);
  });
}
