import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/tv_user_playlists.dart';

import 'fakes.dart';

const _emptyHint = 'Crea tu primera lista con «Nueva lista».';
const _emptyList =
    'Esta lista está vacía. Mantén OK sobre cualquier canal y elige «Agregar a una lista…».';

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

Future<void> _long(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyRepeatEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

/// Rellena el diálogo de texto (el foco inicial está en el campo) y confirma.
Future<void> _fillPrompt(WidgetTester t, String text) async {
  await _ok(t); // abre el teclado propio
  await typeOnTvKeyboard(t, text);
  await _key(t, LogicalKeyboardKey.arrowDown);
  await _ok(t); // botón de confirmar
}

Future<(FakeTvData, int)> _seeded({int channels = 3}) async {
  final data = FakeTvData();
  final id = await data.createUserPlaylist('Lista');
  for (var i = 1; i <= channels; i++) {
    await data.addToUserPlaylist(id, fakeChannel(i));
  }
  return (data, id);
}

List<int?> _ids(FakeTvData d, int id) =>
    d.playlistItems[id]!.map((c) => c.id).toList();

void main() {
  testWidgets('sin listas muestra la invitación y crea la primera', (t) async {
    final data = FakeTvData();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    expect(find.text(_emptyHint), findsOneWidget);
    await focusKey(t, 'tv-playlist-new');
    await _ok(t);
    await _fillPrompt(t, 'Mi lista');
    expect(data.playlistNames.values, ['Mi lista']);
    expect(find.text('Mi lista'), findsOneWidget);
    expect(find.text('0 canales'), findsOneWidget);
    expect(find.text(_emptyList), findsOneWidget);
    expect(find.text(_emptyHint), findsNothing);
  });

  testWidgets('nombre duplicado muestra mensaje', (t) async {
    final (data, _) = await _seeded();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-new');
    await _ok(t);
    await _fillPrompt(t, 'lista');
    expect(find.text('Ya existe una lista con ese nombre'), findsOneWidget);
    expect(data.playlistNames.length, 1);
  });

  testWidgets('muestra el conteo y los canales de la lista', (t) async {
    final (data, _) = await _seeded();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    expect(find.text('3 canales'), findsOneWidget);
    expect(find.text('Canal 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-playlist-add-url')), findsOneWidget);
  });

  testWidgets('agregar canal por URL lo agrega a la lista', (t) async {
    final (data, id) = await _seeded(channels: 0);
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-add-url');
    await _ok(t);
    await _fillPrompt(t, 'Mi canal');
    await _fillPrompt(t, 'http://example.com/live.m3u8');
    expect(data.playlistItems[id]!.single.name, 'Mi canal');
    expect(data.playlistItems[id]!.single.url, 'http://example.com/live.m3u8');
    expect(find.text('Mi canal'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-playlist-channel-0')), findsOneWidget);
  });

  testWidgets('URL de stream inválida muestra mensaje', (t) async {
    final (data, id) = await _seeded(channels: 0);
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-add-url');
    await _ok(t);
    await _fillPrompt(t, 'Mi canal');
    await _fillPrompt(t, 'ftp://example.com/x');
    expect(find.text('La URL debe empezar con http:// o https://'),
        findsOneWidget);
    expect(data.playlistItems[id], isEmpty);
  });

  testWidgets('OK reproduce con índice sin contar la tarjeta de agregar',
      (t) async {
    final (data, _) = await _seeded();
    final calls = <(int, int)>[];
    await pumpTv(
      t,
      TvUserPlaylistsScreen(
        data: data,
        onPlay: (ctx, list, i) async {
          calls.add((list.length, i));
          return null;
        },
      ),
    );
    await focusKey(t, 'tv-playlist-channel-0');
    await _ok(t);
    expect(calls, [(3, 0)]);
  });

  testWidgets('Mover después y Quitar de la lista', (t) async {
    final (data, id) = await _seeded();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-channel-0');
    await _long(t);
    expect(find.text('Mover antes'), findsOneWidget);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t); // Mover después
    expect(_ids(data, id), [2, 1, 3]);
    expect(isFocused(t, const ValueKey('tv-playlist-channel-1')), isTrue);

    await _long(t);
    for (var i = 0; i < 3; i++) {
      await _key(t, LogicalKeyboardKey.arrowDown);
    }
    await _ok(t); // Quitar de la lista
    expect(_ids(data, id), [2, 3]);
  });

  testWidgets('Eliminar lista pide confirmación', (t) async {
    final (data, _) = await _seeded();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-0');
    await _long(t);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t); // Eliminar
    expect(find.text('¿Eliminar la lista «Lista»?'), findsOneWidget);
    await _ok(t); // Cancelar (foco inicial)
    expect(data.playlistNames.length, 1);

    await focusKey(t, 'tv-playlist-0');
    await _long(t);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    await _key(t, LogicalKeyboardKey.arrowLeft);
    await _ok(t); // Eliminar
    expect(data.playlistNames, isEmpty);
    expect(find.text(_emptyHint), findsOneWidget);
  });

  testWidgets('Renombrar usa el nombre actual como valor inicial', (t) async {
    final (data, id) = await _seeded();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-0');
    await _long(t);
    await _ok(t); // Renombrar
    expect(find.text('Lista'), findsWidgets);
    await _fillPrompt(t, 'Renombrada');
    expect(data.playlistNames[id], 'Renombrada');
  });

  testWidgets('← en la primera columna vuelve a la lista seleccionada',
      (t) async {
    final (data, _) = await _seeded();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-add-url');
    await _key(t, LogicalKeyboardKey.arrowLeft);
    expect(isFocused(t, const ValueKey('tv-playlist-0')), isTrue);
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, const ValueKey('tv-playlist-add-url')), isTrue);
  });

  testWidgets('un canal manual se puede eliminar del todo', (t) async {
    final data = FakeTvData();
    final id = await data.createUserPlaylist('Lista');
    final manual =
        await data.addManualChannel(name: 'Mi canal', url: 'http://x/y.m3u8');
    await data.addToUserPlaylist(id, manual);
    await data.addToUserPlaylist(id, fakeChannel(1));
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    expect(find.text('Mi canal'), findsOneWidget);

    await focusKey(t, 'tv-playlist-channel-0');
    await _long(t);
    expect(find.text('Eliminar canal'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await _key(t, LogicalKeyboardKey.arrowDown);
    }
    await _ok(t); // Eliminar canal
    expect(data.deletedManualChannels, ['Mi canal']);
    expect(find.text('Mi canal'), findsNothing);
    expect(_ids(data, id), [1]);
  });

  testWidgets('un canal de una fuente no ofrece "Eliminar canal"', (t) async {
    final (data, _) = await _seeded();
    await pumpTv(t, TvUserPlaylistsScreen(data: data));
    await focusKey(t, 'tv-playlist-channel-0');
    await _long(t);
    expect(find.text('Quitar de la lista'), findsOneWidget);
    expect(find.text('Eliminar canal'), findsNothing);
  });

  group('showAddToPlaylistDialog', () {
    late BuildContext ctx;
    Future<void> host(WidgetTester t, FakeTvData data) => pumpTv(
          t,
          Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        );

    testWidgets('agrega a una lista existente y avisa si ya estaba',
        (t) async {
      final data = FakeTvData();
      final id = await data.createUserPlaylist('A');
      await host(t, data);
      final channel = fakeChannel(5);

      showAddToPlaylistDialog(ctx, data: data, channel: channel);
      await t.pumpAndSettle();
      await _ok(t); // primera opción: «A»
      expect(_ids(data, id), [5]);
      expect(find.text('Agregado a «A»'), findsOneWidget);

      showAddToPlaylistDialog(ctx, data: data, channel: channel);
      await t.pumpAndSettle();
      await _ok(t);
      expect(_ids(data, id), [5]);
      expect(find.text('Ya está en «A»'), findsOneWidget);
    });

    testWidgets('Nueva lista crea y agrega', (t) async {
      final data = FakeTvData();
      await host(t, data);
      showAddToPlaylistDialog(ctx, data: data, channel: fakeChannel(7));
      await t.pumpAndSettle();
      await _ok(t); // única opción: «Nueva lista»
      await _fillPrompt(t, 'B');
      expect(data.playlistNames.values, ['B']);
      expect(data.playlistItems.values.single.single.id, 7);
      expect(find.text('Agregado a «B»'), findsOneWidget);
    });

    testWidgets('Nueva lista con nombre repetido avisa', (t) async {
      final data = FakeTvData();
      await data.createUserPlaylist('B');
      await host(t, data);
      showAddToPlaylistDialog(ctx, data: data, channel: fakeChannel(7));
      await t.pumpAndSettle();
      await _key(t, LogicalKeyboardKey.arrowDown); // «Nueva lista»
      await _ok(t);
      await _fillPrompt(t, 'b');
      expect(find.text('Ya existe una lista con ese nombre'), findsOneWidget);
      expect(data.playlistNames.length, 1);
    });
  });
}
