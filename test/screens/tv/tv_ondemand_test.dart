import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_registry.dart';
import 'package:open_tv/screens/tv/tv_ondemand.dart';

import 'fakes.dart';

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.pump();
}

void main() {
  test('Cineaparte no está habilitada mientras la constante sea falsa', () {
    expect(kOnDemandCineaparteEnabled, isFalse);
    final services = onDemandServices();
    final cine = services.firstWhere((s) => s.id == 'cineaparte');
    expect(cine.provider, isNotNull);
    expect(cine.enabled, isFalse);
    expect(services.map((s) => s.name),
        ['Cineaparte', 'Pluto TV', 'Plex', 'Internet Archive', 'YouTube']);
    expect(services.where((s) => s.enabled), isEmpty);
  });

  testWidgets('muestra una tarjeta por servicio, todas «Próximamente»',
      (t) async {
    await pumpTv(t, const Scaffold(body: TvOnDemandScreen()));
    for (final s in onDemandServices()) {
      expect(find.text(s.name), findsOneWidget);
    }
    expect(find.text('Próximamente'), findsNWidgets(onDemandServices().length));
  });

  testWidgets('la primera tarjeta es enfocable y OK no abre nada', (t) async {
    await pumpTv(t, const Scaffold(body: TvOnDemandScreen()));
    await focusKey(t, 'tv-ondemand-cineaparte');
    expect(isFocused(t, const ValueKey('tv-ondemand-cineaparte')), isTrue);

    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.byType(TvOnDemandScreen), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(t.takeException(), isNull);
  });
}
