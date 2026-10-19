import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart';

import 'fakes.dart';

const _groups = ['Deportes', 'Noticias', 'Cine'];

FakeTvData _fake({int n = 50, List<String> groups = _groups}) => FakeTvData(
      groups: groups,
      channels: List.generate(
        n,
        (i) => fakeChannel(i + 1, group: _groups[i % _groups.length]),
      ),
    );

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump();
}

Future<void> _longPress(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyRepeatEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

Future<void> _ok(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  await t.pumpAndSettle();
}

ValueKey<String> _ch(int i) => ValueKey('tv-channel-$i');
ValueKey<String> _gr(int i) => ValueKey('tv-group-$i');

void main() {
  testWidgets('↓ en la grilla baja una fila en la misma columna', (t) async {
    await pumpTv(t, TVChannelBrowser(data: _fake()));
    await focusKey(t, 'tv-channel-1');
    final before = t.getRect(find.byKey(_ch(1)));
    await _key(t, LogicalKeyboardKey.arrowDown);
    expect(isFocused(t, _ch(5)), isTrue);
    final after = t.getRect(find.byKey(_ch(5)));
    expect(after.top, greaterThan(before.top));
    expect((after.left - before.left).abs(), lessThan(12));
  });

  testWidgets('← en la primera columna va al grupo seleccionado', (t) async {
    await pumpTv(t, TVChannelBrowser(data: _fake()));
    await focusKey(t, 'tv-channel-0');
    await _key(t, LogicalKeyboardKey.arrowLeft);
    expect(isFocused(t, _gr(0)), isTrue);

    // Con otro grupo seleccionado, vuelve a ese grupo.
    await focusKey(t, 'tv-group-0');
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    await focusKey(t, 'tv-channel-0');
    await _key(t, LogicalKeyboardKey.arrowLeft);
    expect(isFocused(t, _gr(2)), isTrue);
  });

  testWidgets('→ desde un grupo entra a la grilla', (t) async {
    await pumpTv(t, TVChannelBrowser(data: _fake()));
    await focusKey(t, 'tv-group-0');
    await _key(t, LogicalKeyboardKey.arrowRight);
    expect(isFocused(t, _ch(0)), isTrue);
  });

  testWidgets('Atrás no se consume en grupos ni en tarjetas (regresión H5)',
      (t) async {
    await pumpTv(t, TVChannelBrowser(data: _fake()));
    await focusKey(t, 'tv-group-1');
    expect(injectBackKey(), isFalse);
    await focusKey(t, 'tv-channel-3');
    expect(injectBackKey(), isFalse);
  });

  testWidgets('debounce: recorrer grupos rápido carga solo el último',
      (t) async {
    final data = _fake();
    await pumpTv(t, TVChannelBrowser(data: data));
    final initial = data.channelCalls.length;
    await focusKey(t, 'tv-group-0');
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    expect(data.channelCalls.length, initial + 1);
    expect(data.channelCalls.last.groupName, 'Cine');
    expect(data.channelCalls.last.mediaTypes, [MediaType.livestream]);
  });

  testWidgets('OK reproduce con la lista y el índice', (t) async {
    final calls = <(int, int)>[];
    await pumpTv(
      t,
      TVChannelBrowser(
        data: _fake(),
        onPlay: (ctx, list, i) async {
          calls.add((list.length, i));
          return null;
        },
      ),
    );
    await focusKey(t, 'tv-channel-5');
    await _ok(t);
    expect(calls, [(36, 5)]);
  });

  testWidgets('OK largo → menú → favorito', (t) async {
    final data = _fake();
    await pumpTv(t, TVChannelBrowser(data: data));
    await focusKey(t, 'tv-channel-2');
    await _longPress(t);
    expect(find.text('Agregar a favoritos'), findsOneWidget);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(data.favoriteCalls, [(data.channels[2].id!, true)]);
    expect(find.text('Agregado a favoritos'), findsOneWidget);
  });

  testWidgets('el menú ofrece "Agregar a una lista…" solo con callback',
      (t) async {
    await pumpTv(t, TVChannelBrowser(data: _fake()));
    await focusKey(t, 'tv-channel-0');
    await _longPress(t);
    expect(find.text('Agregar a una lista…'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    Channel? added;
    await pumpTv(
      t,
      TVChannelBrowser(
        data: _fake(),
        onAddToPlaylist: (ctx, ch) async => added = ch,
      ),
    );
    await focusKey(t, 'tv-channel-0');
    await _longPress(t);
    expect(find.text('Agregar a una lista…'), findsOneWidget);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(added?.id, isNotNull);
  });

  testWidgets('al volver del reproductor enfoca el último canal visto',
      (t) async {
    await pumpTv(
      t,
      TVChannelBrowser(
        data: _fake(),
        onPlay: (ctx, list, i) async => 7,
      ),
    );
    await focusKey(t, 'tv-channel-2');
    await _ok(t);
    await t.pumpAndSettle();
    expect(isFocused(t, _ch(7)), isTrue);
  });

  testWidgets('mantener ↓ con paginación no pierde el foco', (t) async {
    final data = FakeTvData(
      groups: const [],
      channels: List.generate(80, (i) => fakeChannel(i + 1)),
    );
    await pumpTv(t, TVChannelBrowser(data: data));
    await focusKey(t, 'tv-channel-0');
    await t.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 12; i++) {
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();

    final focused = [
      for (var i = 0; i < 80; i++)
        if (find.byKey(_ch(i)).evaluate().isNotEmpty && isFocused(t, _ch(i))) i
    ];
    expect(focused.length, 1, reason: 'exactamente una tarjeta con foco');
    expect(focused.single, greaterThan(36), reason: 'avanzó a la 2.ª página');
    final pages = data.channelCalls.map((f) => f.page).toList();
    expect(pages.toSet().length, pages.length, reason: 'sin páginas repetidas');
    expect(pages, contains(2));
  });

  testWidgets('favoritesOnly sin favoritos muestra estado vacío', (t) async {
    final data = _fake();
    await pumpTv(t, TVChannelBrowser(favoritesOnly: true, data: data));
    expect(
      find.text(
        'Aún no tienes favoritos. Mantén presionado OK sobre un canal para agregarlo.',
      ),
      findsOneWidget,
    );
    expect(data.channelCalls.single.viewType, ViewType.favorites);
    expect(find.byKey(_gr(0)), findsNothing);
  });

  testWidgets('quitar un favorito lo saca de la grilla y mueve el foco',
      (t) async {
    final data = FakeTvData(
      channels: [
        fakeChannel(1, favorite: true),
        fakeChannel(2, favorite: true),
        fakeChannel(3, favorite: true),
      ],
    );
    await pumpTv(t, TVChannelBrowser(favoritesOnly: true, data: data));
    await focusKey(t, 'tv-channel-1');
    await _longPress(t);
    expect(find.text('Quitar de favoritos'), findsOneWidget);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    await t.pumpAndSettle();
    expect(find.byKey(_ch(2)), findsNothing);
    expect(isFocused(t, _ch(1)), isTrue);
  });

  testWidgets('hay más de 36 grupos: se cargan todas las páginas', (t) async {
    final many = List.generate(50, (i) => 'Grupo $i');
    final data = FakeTvData(groups: many, channels: [fakeChannel(1)]);
    await pumpTv(t, TVChannelBrowser(data: data));
    expect(data.groupCalls.map((f) => f.page).toList(), [1, 2]);
    await focusKey(t, 'tv-group-0');
    for (var i = 0; i < 50; i++) {
      await _key(t, LogicalKeyboardKey.arrowDown);
    }
    await t.pumpAndSettle();
    expect(isFocused(t, _gr(50)), isTrue); // 'Todos los canales' + 50 grupos
  });

  testWidgets('el favorito usa el id vigente tras refrescar la fuente',
      (t) async {
    final data = _fake()..resolvedIds['Canal 3'] = 999;
    await pumpTv(t, TVChannelBrowser(data: data));
    await focusKey(t, 'tv-channel-2'); // 'Canal 3' con el id viejo 3
    await _longPress(t);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(data.favoriteCalls, [(999, true)]);
  });

  testWidgets('si el canal ya no existe no se marca nada y se avisa',
      (t) async {
    final data = _fake()..vanished.add('Canal 3');
    await pumpTv(t, TVChannelBrowser(data: data));
    await focusKey(t, 'tv-channel-2');
    await _longPress(t);
    await _key(t, LogicalKeyboardKey.arrowDown);
    await _ok(t);
    expect(data.favoriteCalls, isEmpty);
    expect(find.text('Este canal ya no está disponible'), findsOneWidget);
  });

  testWidgets('un canal con guía ofrece "Ver programación" y la abre', (t) async {
    final data = _fake();
    data.guideChannels.addAll(data.channels.map((c) => c.name));
    data.guidePrograms = [
      GuideProgram(start: DateTime.utc(2026, 10, 19, 13), title: 'Primera hora'),
    ];
    await pumpTv(t, TVChannelBrowser(data: data));
    await focusKey(t, 'tv-channel-0');
    await _longPress(t);
    expect(find.text('Ver programación'), findsOneWidget);
    await focusKey(t, 'tv-option-2');
    await _ok(t);
    expect(find.text('Primera hora'), findsOneWidget);
  });

  testWidgets('con historial aparece "Recientes" justo después de "Todos"',
      (t) async {
    final data = _fake();
    data.recents = [fakeChannel(77), fakeChannel(78)];
    await pumpTv(t, TVChannelBrowser(data: data));
    expect(find.text('Recientes'), findsOneWidget);
    // Orden: Todos, Recientes, Deportes…
    final all = t.getRect(find.text('Todos los canales')).top;
    final rec = t.getRect(find.text('Recientes')).top;
    final dep = t.getRect(find.text('Deportes')).top;
    expect(all, lessThan(rec));
    expect(rec, lessThan(dep));
  });

  testWidgets('elegir "Recientes" lista el historial en su orden', (t) async {
    final data = _fake();
    data.recents = [fakeChannel(77), fakeChannel(78)];
    await pumpTv(t, TVChannelBrowser(data: data));
    await focusKey(t, 'tv-group-1');
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    expect(data.channelCalls.last.viewType, ViewType.history);
    expect(find.text('Canal 77'), findsOneWidget);
    expect(find.text('Canal 78'), findsOneWidget);
    expect(find.text('Canal 1'), findsNothing);
  });

  testWidgets('sin historial no se muestra "Recientes"', (t) async {
    await pumpTv(t, TVChannelBrowser(data: _fake()));
    expect(find.text('Recientes'), findsNothing);
  });

  testWidgets('un canal sin guía no ofrece "Ver programación"', (t) async {
    await pumpTv(t, TVChannelBrowser(data: _fake()));
    await focusKey(t, 'tv-channel-0');
    await _longPress(t);
    expect(find.text('Agregar a favoritos'), findsOneWidget);
    expect(find.text('Ver programación'), findsNothing);
  });
}
