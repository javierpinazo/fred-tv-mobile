import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

// Fija la semántica de listas propias que usan las pantallas TV (el SQL real
// implementa lo mismo y se verifica en el dispositivo).
void main() {
  test('crear con nombre repetido (sin distinguir mayúsculas) lanza', () async {
    final d = FakeTvData();
    await d.createUserPlaylist('Noticias');
    expect(() => d.createUserPlaylist('noticias'), throwsStateError);
  });

  test('renombrar a un nombre existente lanza; al propio nombre no', () async {
    final d = FakeTvData();
    final a = await d.createUserPlaylist('A');
    await d.createUserPlaylist('B');
    expect(() => d.renameUserPlaylist(a, 'b'), throwsStateError);
    await d.renameUserPlaylist(a, 'a'); // mismo id: permitido
    expect((await d.userPlaylists()).map((p) => p.name), ['a', 'B']);
  });

  test('add devuelve false si el canal ya estaba', () async {
    final d = FakeTvData();
    final id = await d.createUserPlaylist('L');
    expect(await d.addToUserPlaylist(id, fakeChannel(1)), isTrue);
    expect(await d.addToUserPlaylist(id, fakeChannel(1)), isFalse);
    expect(await d.addToUserPlaylist(id, fakeChannel(2)), isTrue);
  });

  test('el mismo nombre en otra fuente es otro canal', () async {
    final d = FakeTvData();
    final id = await d.createUserPlaylist('L');
    expect(await d.addToUserPlaylist(id, fakeChannel(1, sourceId: 1)), isTrue);
    expect(await d.addToUserPlaylist(id, fakeChannel(1, sourceId: 2)), isTrue);
    expect((await d.userPlaylistChannels(id)).length, 2);
  });

  test('move intercambia con el vecino y no sale de los bordes', () async {
    final d = FakeTvData();
    final id = await d.createUserPlaylist('L');
    for (var i = 1; i <= 3; i++) {
      await d.addToUserPlaylist(id, fakeChannel(i));
    }
    Future<List<int?>> order() async =>
        (await d.userPlaylistChannels(id)).map((c) => c.id).toList();

    await d.moveInUserPlaylist(id, fakeChannel(1), 1);
    expect(await order(), [2, 1, 3]);
    await d.moveInUserPlaylist(id, fakeChannel(2), -1); // ya es el primero
    expect(await order(), [2, 1, 3]);
    await d.moveInUserPlaylist(id, fakeChannel(3), 1); // ya es el último
    expect(await order(), [2, 1, 3]);
    await d.moveInUserPlaylist(id, fakeChannel(3), -1);
    expect(await order(), [2, 3, 1]);
  });

  test('remove quita el canal y channelCount lo refleja', () async {
    final d = FakeTvData();
    final id = await d.createUserPlaylist('L');
    await d.addToUserPlaylist(id, fakeChannel(1));
    await d.addToUserPlaylist(id, fakeChannel(2));
    expect((await d.userPlaylists()).single.channelCount, 2);
    await d.removeFromUserPlaylist(id, fakeChannel(1));
    expect((await d.userPlaylists()).single.channelCount, 1);
    expect((await d.userPlaylistChannels(id)).single.id, 2);
  });

  test('eliminar una lista la quita del listado', () async {
    final d = FakeTvData();
    final id = await d.createUserPlaylist('L');
    await d.deleteUserPlaylist(id);
    expect(await d.userPlaylists(), isEmpty);
  });

  test('las listas salen ordenadas por nombre sin distinguir mayúsculas',
      () async {
    final d = FakeTvData();
    await d.createUserPlaylist('zeta');
    await d.createUserPlaylist('Alfa');
    await d.createUserPlaylist('beta');
    expect((await d.userPlaylists()).map((p) => p.name), ['Alfa', 'beta', 'zeta']);
  });

  test('addManualChannel devuelve un canal reproducible', () async {
    final d = FakeTvData();
    final ch = await d.addManualChannel(name: 'Mi canal', url: 'http://x/y.m3u8');
    expect(ch.name, 'Mi canal');
    expect(ch.url, 'http://x/y.m3u8');
    expect(ch.id, isNotNull);
  });
}
