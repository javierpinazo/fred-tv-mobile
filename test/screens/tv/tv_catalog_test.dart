import 'dart:async';
import 'dart:io' show HandshakeException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/screens/tv/ondemand/on_demand_play.dart';
import 'package:open_tv/screens/tv/ondemand/tv_catalog_screen.dart';
import 'package:open_tv/screens/tv/ondemand/vimeo_player_page.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_player.dart';

import 'fakes.dart';

const _vimeo = OnDemandTitle(
  id: '1',
  title: 'Expectante',
  synopsis: 'Una ficción sobre la paranoia.',
  posterUrl: '',
  details: 'Largometraje ficción, 2018, 77 min.',
  source: VimeoSource('1229366069'),
);
const _youtube = OnDemandTitle(
  id: '2',
  title: 'Túpac Amaru',
  synopsis: 'Biografía.',
  posterUrl: '',
  details: 'Largometraje, 1984, 90 min.',
  source: YoutubeSource('B4yhLGy9-z8'),
);

class FakeProvider implements OnDemandProvider {
  FakeProvider(this.results);

  /// Cada llamada a `titles()` consume el siguiente resultado (el último se repite).
  final List<Object> results;
  int calls = 0;

  @override
  String get id => 'cineaparte';
  @override
  String get name => 'Cineaparte';

  @override
  Future<List<OnDemandTitle>> titles() async {
    final r = results[calls < results.length ? calls : results.length - 1];
    calls++;
    if (r is Exception) throw r;
    if (r is Error) throw r;
    return r as List<OnDemandTitle>;
  }
}

class _GatedProvider implements OnDemandProvider {
  _GatedProvider(this._future);
  final Future<List<OnDemandTitle>> _future;
  @override
  String get id => 'cineaparte';
  @override
  String get name => 'Cineaparte';
  @override
  Future<List<OnDemandTitle>> titles() => _future;
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(k);
  await t.sendKeyUpEvent(k);
  await t.pump();
}

Future<List<OnDemandTitle>> _played(
    WidgetTester t, FakeProvider p, void Function(OnDemandTitle) sink) async {
  await pumpTv(
    t,
    TvCatalogScreen(
      provider: p,
      onPlay: (context, provider, title) async => sink(title),
    ),
  );
  await t.pumpAndSettle();
  return const [];
}

void main() {
  testWidgets('muestra la carga y luego una tarjeta por película', (t) async {
    final gate = Completer<List<OnDemandTitle>>();
    await pumpTvRoute(
        t, (_) => TvCatalogScreen(provider: _GatedProvider(gate.future)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete([_vimeo, _youtube]);
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Expectante'), findsOneWidget);
    expect(find.text('Túpac Amaru'), findsOneWidget);
    expect(isFocused(t, const ValueKey('tv-cine-1')), isTrue);
  });

  testWidgets('si falla muestra el error y «Reintentar» vuelve a cargar',
      (t) async {
    final p = FakeProvider([
      OnDemandUnavailableException('sin red'),
      [_vimeo],
    ]);
    await pumpTv(t, TvCatalogScreen(provider: p));
    await t.pumpAndSettle();
    expect(find.text('No se pudieron cargar las películas'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.text('Expectante'), findsOneWidget);
    expect(p.calls, 2);
  });

  testWidgets('catálogo vacío se trata como error, no como pantalla en blanco',
      (t) async {
    await pumpTv(t, TvCatalogScreen(provider: FakeProvider([<OnDemandTitle>[]])));
    await t.pumpAndSettle();
    expect(find.text('No se pudieron cargar las películas'), findsOneWidget);
  });

  testWidgets('OK abre la ficha; «Ver» reproduce esa película; «Volver» cierra',
      (t) async {
    final played = <OnDemandTitle>[];
    await _played(t, FakeProvider([
      [_vimeo, _youtube]
    ]), played.add);

    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.text('Una ficción sobre la paranoia.'), findsOneWidget);
    expect(find.text('Largometraje ficción, 2018, 77 min.'), findsOneWidget);

    await _key(t, LogicalKeyboardKey.select); // «Ver» tiene el foco inicial
    await t.pumpAndSettle();
    expect(played.single.id, '1');

    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    await _key(t, LogicalKeyboardKey.arrowRight); // → «Volver»
    await _key(t, LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.text('Una ficción sobre la paranoia.'), findsNothing);
    expect(played, hasLength(1));
  });

  group('onDemandPlayerFor', () {
    test('Vimeo → TvVimeoPlayer con el id', () {
      final w = onDemandPlayerFor(_vimeo);
      expect(w, isA<TvVimeoPlayer>());
      expect((w as TvVimeoPlayer).videoId, '1229366069');
      expect(w.title, 'Expectante');
    });

    test('YouTube con subtítulos → TvYoutubePlayer con captions', () {
      final w = onDemandPlayerFor(OnDemandTitle(
          id: '3',
          title: 'Con subs',
          synopsis: '',
          posterUrl: '',
          details: '',
          source: const YoutubeSource('B4yhLGy9-z8', captions: true)));
      expect((w as TvYoutubePlayer).captions, isTrue);
      expect((onDemandPlayerFor(_youtube) as TvYoutubePlayer).captions, isFalse);
    });

    test('YouTube → TvYoutubePlayer con el id y el título', () {
      final w = onDemandPlayerFor(_youtube);
      expect(w, isA<TvYoutubePlayer>());
      final yt = w as TvYoutubePlayer;
      expect(yt.program.videoId, 'B4yhLGy9-z8');
      expect(yt.program.title, 'Túpac Amaru');
      expect(yt.program.isLive, isFalse);
      expect(yt.channel.name, 'On demand');
    });
  });

  group('categorías', () {
    OnDemandTitle t(String id, String name, List<String> cats) => OnDemandTitle(
        id: id,
        title: name,
        synopsis: '',
        posterUrl: '',
        details: '',
        source: const VimeoSource('1'),
        categories: cats);

    final titles = [
      t('1', 'Peli Drama', ['Drama']),
      t('2', 'Peli Acción', ['acción']),
      t('3', 'Peli Mixta', ['Drama', 'Comedia']),
    ];

    testWidgets('sin categorías no hay columna', (tt) async {
      await pumpTv(tt, TvCatalogScreen(provider: FakeProvider([[_vimeo]])));
      await tt.pumpAndSettle();
      expect(find.text('Todas'), findsNothing);
    });

    testWidgets('columna con «Todas» y las categorías en orden alfabético',
        (tt) async {
      await pumpTv(tt, TvCatalogScreen(provider: FakeProvider([titles])));
      await tt.pumpAndSettle();
      expect(find.byKey(const ValueKey('tv-cat-all')), findsOneWidget);
      final ys = [
        for (final k in ['tv-cat-all', 'tv-cat-acción', 'tv-cat-Comedia', 'tv-cat-Drama'])
          tt.getTopLeft(find.byKey(ValueKey(k))).dy
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Peli Drama'), findsOneWidget);
      expect(find.text('Peli Acción'), findsOneWidget);
    });

    testWidgets('elegir una categoría filtra y «Todas» restablece', (tt) async {
      await pumpTv(tt, TvCatalogScreen(provider: FakeProvider([titles])));
      await tt.pumpAndSettle();

      await focusKey(tt, 'tv-cat-Drama');
      await _key(tt, LogicalKeyboardKey.select);
      await tt.pumpAndSettle();
      expect(find.text('Peli Drama'), findsOneWidget);
      expect(find.text('Peli Mixta'), findsOneWidget); // en varias categorías
      expect(find.text('Peli Acción'), findsNothing);

      await focusKey(tt, 'tv-cat-Comedia');
      await _key(tt, LogicalKeyboardKey.select);
      await tt.pumpAndSettle();
      expect(find.text('Peli Mixta'), findsOneWidget);
      expect(find.text('Peli Drama'), findsNothing);

      await focusKey(tt, 'tv-cat-all');
      await _key(tt, LogicalKeyboardKey.select);
      await tt.pumpAndSettle();
      expect(find.text('Peli Acción'), findsOneWidget);
      expect(find.text('Peli Drama'), findsOneWidget);
    });

    testWidgets('→ entra en la cuadrícula y ← vuelve a la columna', (tt) async {
      await pumpTv(tt, TvCatalogScreen(provider: FakeProvider([titles])));
      await tt.pumpAndSettle();
      expect(isFocused(tt, const ValueKey('tv-cine-1')), isTrue);

      await _key(tt, LogicalKeyboardKey.arrowLeft);
      expect(isFocused(tt, const ValueKey('tv-cat-all')), isTrue);
      await _key(tt, LogicalKeyboardKey.arrowRight);
      expect(isFocused(tt, const ValueKey('tv-cine-1')), isTrue);
    });

    testWidgets('← desde la cuadrícula vuelve a la categoría elegida',
        (tt) async {
      await pumpTv(tt, TvCatalogScreen(provider: FakeProvider([titles])));
      await tt.pumpAndSettle();
      await focusKey(tt, 'tv-cat-Drama');
      await _key(tt, LogicalKeyboardKey.select);
      await tt.pumpAndSettle();

      await _key(tt, LogicalKeyboardKey.arrowRight);
      expect(isFocused(tt, const ValueKey('tv-cine-1')), isTrue);
      await _key(tt, LogicalKeyboardKey.arrowLeft);
      expect(isFocused(tt, const ValueKey('tv-cat-Drama')), isTrue);
    });
  });

  testWidgets('C1: una excepción cualquiera al cargar muestra el error y '
      '«Reintentar» (no un spinner eterno)', (tt) async {
    final p = FakeProvider([
      const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      [_vimeo],
    ]);
    await pumpTv(tt, TvCatalogScreen(provider: p));
    await tt.pumpAndSettle();
    expect(find.text('No se pudieron cargar las películas'), findsOneWidget);
    await _key(tt, LogicalKeyboardKey.select);
    await tt.pumpAndSettle();
    expect(find.text('Expectante'), findsOneWidget);
  });

  group('formato del cartel', () {
    OnDemandTitle t(String id, {required bool landscape}) => OnDemandTitle(
        id: id,
        title: 'Peli $id',
        synopsis: 'Sinopsis',
        posterUrl: '',
        details: '',
        source: const VimeoSource('1'),
        landscapePoster: landscape);

    testWidgets('carteles verticales: tarjeta más alta que ancha', (tt) async {
      await pumpTv(
          tt,
          TvCatalogScreen(
              provider: FakeProvider([
            [t('1', landscape: false)]
          ])));
      await tt.pumpAndSettle();
      final size = tt.getSize(find.byKey(const ValueKey('tv-cine-1')));
      expect(size.height, greaterThan(size.width));
    });

    testWidgets('miniaturas horizontales: tarjeta más ancha que alta y la '
        'ficha deja el cartel en 16:9', (tt) async {
      await pumpTv(
          tt,
          TvCatalogScreen(
              provider: FakeProvider([
            [t('1', landscape: true), t('2', landscape: true)]
          ])));
      await tt.pumpAndSettle();
      final size = tt.getSize(find.byKey(const ValueKey('tv-cine-1')));
      expect(size.width, greaterThan(size.height));

      await _key(tt, LogicalKeyboardKey.select);
      await tt.pumpAndSettle();
      final poster = tt.getSize(find.byKey(const ValueKey('tv-cine-poster')));
      expect(poster.width / poster.height, closeTo(16 / 9, 0.02));
    });

    testWidgets('catálogo mixto: se queda en vertical', (tt) async {
      await pumpTv(
          tt,
          TvCatalogScreen(
              provider: FakeProvider([
            [t('1', landscape: true), t('2', landscape: false)]
          ])));
      await tt.pumpAndSettle();
      final size = tt.getSize(find.byKey(const ValueKey('tv-cine-1')));
      expect(size.height, greaterThan(size.width));
    });
  });
}
