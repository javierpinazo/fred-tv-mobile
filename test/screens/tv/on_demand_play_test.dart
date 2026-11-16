import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/screens/tv/ondemand/on_demand_play.dart';

import 'fakes.dart';

const _pluto = OnDemandTitle(
  id: 'abc123',
  title: 'El último héroe',
  synopsis: '',
  posterUrl: '',
  details: '',
  source: PlutoSource('abc123'),
);

class FakeResolver implements OnDemandProvider, OnDemandResolver {
  FakeResolver(this.results);

  /// Cada llamada consume el siguiente resultado (el último se repite):
  /// un `OnDemandStream`, una excepción o un `Completer<OnDemandStream>`.
  final List<Object> results;
  int calls = 0;

  @override
  String get id => 'pluto';
  @override
  String get name => 'Pluto TV';
  @override
  Future<List<OnDemandTitle>> titles() async => [_pluto];

  @override
  Future<OnDemandStream> resolve(OnDemandTitle title) {
    final r = results[calls < results.length ? calls : results.length - 1];
    calls++;
    if (r is Exception) return Future.error(r);
    if (r is Completer<OnDemandStream>) return r.future;
    return Future.value(r as OnDemandStream);
  }
}

const _stream = OnDemandStream(
    url: 'https://x/master.m3u8', headers: {'Authorization': 'Bearer t'});

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.pump();
}

/// Monta un botón que lanza `playOnDemandTitle` con un reproductor de mentira.
Future<List<OnDemandStream>> _launch(
    WidgetTester t, FakeResolver provider) async {
  final built = <OnDemandStream>[];
  await pumpTv(
    t,
    Builder(
      builder: (context) => TextButton(
        key: const ValueKey('go'),
        onPressed: () => playOnDemandTitle(
          context,
          provider,
          _pluto,
          playerBuilder: (stream, title) {
            built.add(stream);
            return Scaffold(body: Text('REPRODUCTOR $title'));
          },
        ),
        child: const Text('ir'),
      ),
    ),
  );
  await t.tap(find.byKey(const ValueKey('go')));
  await t.pump();
  return built;
}

void main() {
  testWidgets('Pluto: muestra «Preparando…», resuelve una vez y abre el reproductor',
      (t) async {
    final gate = Completer<OnDemandStream>();
    final p = FakeResolver([gate]);
    final built = await _launch(t, p);
    expect(find.text('Preparando la película…'), findsOneWidget);
    expect(built, isEmpty);

    gate.complete(_stream);
    await t.pumpAndSettle();
    expect(p.calls, 1);
    expect(built.single.url, _stream.url);
    expect(find.text('Preparando la película…'), findsNothing);
    expect(find.text('REPRODUCTOR El último héroe'), findsOneWidget);
  });

  testWidgets('si resolve falla: mensaje y «Reintentar» vuelve a resolver',
      (t) async {
    final p = FakeResolver([OnDemandUnavailableException('401'), _stream]);
    final built = await _launch(t, p);
    await t.pumpAndSettle();
    expect(find.text('No se pudieron cargar las películas'), findsOneWidget);
    expect(find.text('Preparando la película…'), findsNothing);
    expect(built, isEmpty);

    await _key(t, LogicalKeyboardKey.select); // «Reintentar»
    await t.pumpAndSettle();
    expect(p.calls, 2);
    expect(built, hasLength(1));
  });

  testWidgets('si resolve falla, «Volver» cierra sin abrir el reproductor',
      (t) async {
    final p = FakeResolver([OnDemandUnavailableException('500')]);
    final built = await _launch(t, p);
    await t.pumpAndSettle();
    await _key(t, LogicalKeyboardKey.arrowRight); // → «Volver»
    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(p.calls, 1);
    expect(built, isEmpty);
    expect(find.text('No se pudieron cargar las películas'), findsNothing);
  });
}
