import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/db_factory.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/user_playlists_sql.dart';
import 'package:open_tv/backend/youtube/youtube_channel.dart';
import 'package:open_tv/backend/youtube/youtube_seed.dart';

const _names = [
  'La Encerrona',
  'La República',
  'Curwen',
  'Paolo Benza',
  'Carlos León Moya',
];

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fredtv_youtube_seed');
    DbFactory.debugPath = '${dir.path}/db.sqlite';
    await DbFactory.debugReset();
  });

  tearDown(() async {
    await DbFactory.debugReset();
    DbFactory.debugPath = null;
    await dir.delete(recursive: true);
  });

  Future<List<String>> youtubeLists() async => [
        for (final p in await UserPlaylistsSql.all())
          if (p.name == 'YouTube') p.name
      ];

  test('los canales por defecto son direcciones de canal de YouTube', () {
    expect(defaultYoutubeChannels.map((c) => c.name), _names);
    expect(defaultYoutubeChannels.every((c) => isYoutubeChannelUrl(c.url)),
        isTrue);
    expect(defaultYoutubeChannels.first.url,
        'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg');
  });

  test('crea la lista YouTube con los cinco canales en orden', () async {
    await ensureYoutubeChannels();

    final list =
        (await UserPlaylistsSql.all()).singleWhere((p) => p.name == 'YouTube');
    final channels = await UserPlaylistsSql.channels(list.id);
    expect(channels.map((c) => c.name), _names);
    expect(
        channels.every((c) => isYoutubeChannelUrl(c.url) && !c.favorite), isTrue);
    expect(await Sql.getSetting(youtubeSeedSettingKey), '1');
  });

  test('llamarlo dos veces no duplica nada', () async {
    await ensureYoutubeChannels();
    await ensureYoutubeChannels();
    expect(await youtubeLists(), ['YouTube']);
    final list =
        (await UserPlaylistsSql.all()).singleWhere((p) => p.name == 'YouTube');
    expect((await UserPlaylistsSql.channels(list.id)).length, 5);
  });

  test('no vuelve a crear lo que el usuario borró', () async {
    await ensureYoutubeChannels();
    final list =
        (await UserPlaylistsSql.all()).singleWhere((p) => p.name == 'YouTube');
    final curwen =
        await Sql.channelByName('Curwen', sourceName: customSourceName);
    await UserPlaylistsSql.deleteManualChannel(curwen!);
    await UserPlaylistsSql.delete(list.id);

    await ensureYoutubeChannels();

    expect(await youtubeLists(), isEmpty);
    expect(await Sql.channelByName('Curwen', sourceName: customSourceName),
        isNull);
  });

  test('reutiliza una lista YouTube y un canal del mismo nombre ya existentes',
      () async {
    final existing = await UserPlaylistsSql.create('youtube');
    final mine = await UserPlaylistsSql.addManualChannel(
        name: 'Curwen', url: 'https://www.youtube.com/@curwen');
    await UserPlaylistsSql.add(existing, mine);

    await ensureYoutubeChannels();

    final lists = (await UserPlaylistsSql.all())
        .where((p) => p.name.toLowerCase() == 'youtube')
        .toList();
    expect(lists.length, 1);
    final channels = await UserPlaylistsSql.channels(lists.single.id);
    expect(channels.map((c) => c.name).toSet(), _names.toSet());
    expect(channels.length, 5);
    expect(channels.singleWhere((c) => c.name == 'Curwen').url,
        'https://www.youtube.com/@curwen',
        reason: 'se conserva la dirección que puso el usuario');
  });
}
