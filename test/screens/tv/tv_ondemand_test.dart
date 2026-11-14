import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/on_demand_registry.dart';
import 'package:open_tv/screens/tv/ondemand/tv_cineaparte_screen.dart';
import 'package:open_tv/screens/tv/tv_ondemand.dart';

import 'fakes.dart';

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.pump();
}

void main() {
  test('Cineaparte está habilitada; los demás servicios aún no', () {
    expect(kOnDemandCineaparteEnabled, isTrue);
    final services = onDemandServices();
    final cine = services.firstWhere((s) => s.id == 'cineaparte');
    expect(cine.provider, isNotNull);
    expect(cine.enabled, isTrue);
    expect(services.map((s) => s.name),
        ['Cineaparte', 'Pluto TV', 'Plex', 'Internet Archive', 'YouTube']);
    expect(services.where((s) => s.enabled).map((s) => s.id), ['cineaparte']);
  });

  testWidgets('Cineaparte sin «Próximamente»; los otros 4 sí', (t) async {
    await pumpTv(t, const Scaffold(body: TvOnDemandScreen()));
    for (final s in onDemandServices()) {
      expect(find.text(s.name), findsOneWidget);
    }
    expect(find.text('Próximamente'), findsNWidgets(4));
  });

  testWidgets('OK en un servicio sin conectar no abre nada', (t) async {
    await pumpTv(t, const Scaffold(body: TvOnDemandScreen()));
    await focusKey(t, 'tv-ondemand-pluto');
    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.byType(TvOnDemandScreen), findsOneWidget);
    expect(find.byType(TvCineaparteScreen), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('OK en Cineaparte abre su pantalla de películas', (t) async {
    final fake = _FakeCine();
    await pumpTv(
      t,
      Scaffold(
        body: TvOnDemandScreen(services: [
          OnDemandService(
              id: 'cineaparte',
              name: 'Cineaparte',
              icon: Icons.movie,
              provider: fake),
        ]),
      ),
    );
    await focusKey(t, 'tv-ondemand-cineaparte');
    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.byType(TvCineaparteScreen), findsOneWidget);
    expect(fake.calls, 1);
  });
}

class _FakeCine implements OnDemandProvider {
  int calls = 0;
  @override
  String get id => 'cineaparte';
  @override
  String get name => 'Cineaparte';
  @override
  Future<List<OnDemandTitle>> titles() async {
    calls++;
    return const [
      OnDemandTitle(
          id: '1',
          title: 'Peli',
          synopsis: '',
          posterUrl: '',
          details: '',
          source: VimeoSource('1')),
    ];
  }
}
