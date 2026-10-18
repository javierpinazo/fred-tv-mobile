import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/sql.dart' show pageSize;
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_http_headers.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/screens/tv/tv_data.dart';

Channel fakeChannel(
  int i, {
  String? group,
  bool favorite = false,
  MediaType type = MediaType.livestream,
  int sourceId = 1,
}) =>
    Channel(
      id: i,
      name: 'Canal $i',
      url: 'http://test/$i.m3u8',
      mediaType: type,
      sourceId: sourceId,
      favorite: favorite,
      group: group,
    );

class FakeTvData extends TvData {
  FakeTvData({
    this.groups = const [],
    this.channels = const [],
    this.onSearchChannels,
  });

  final List<String> groups;
  final List<Channel> channels;
  final Future<List<Channel>> Function(Filters f)? onSearchChannels;

  final List<Filters> channelCalls = [];
  final List<Filters> groupCalls = [];
  final List<(int, bool)> favoriteCalls = [];
  final List<int> historyCalls = [];

  @override
  Future<List<int>> enabledSourceIds() async => [1];

  @override
  Future<List<Channel>> searchGroups(Filters f) async {
    groupCalls.add(f);
    return groups
        .map((g) => Channel(
            name: g,
            mediaType: MediaType.group,
            sourceId: -1,
            favorite: false))
        .toList();
  }

  @override
  Future<List<Channel>> searchChannels(Filters f) async {
    channelCalls.add(f);
    if (onSearchChannels != null) return onSearchChannels!(f);
    Iterable<Channel> r = channels;
    if (f.groupName != null) r = r.where((c) => c.group == f.groupName);
    if (f.viewType == ViewType.favorites) r = r.where((c) => c.favorite);
    final words = (f.query ?? '')
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty);
    r = r.where((c) => words.every((w) => c.name.toLowerCase().contains(w)));
    final list = r.toList();
    final start = (f.page - 1) * pageSize;
    if (start >= list.length) return [];
    final end = (start + pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  @override
  Future<void> setFavorite(int channelId, bool favorite) async {
    favoriteCalls.add((channelId, favorite));
    for (final c in channels) {
      if (c.id == channelId) c.favorite = favorite;
    }
  }

  @override
  Future<void> addToHistory(int channelId) async => historyCalls.add(channelId);

  @override
  Future<ChannelHttpHeaders?> channelHeaders(int channelId) async => null;
}

Future<void> pumpTv(WidgetTester t, Widget child) async {
  t.view.physicalSize = const Size(1920, 1080);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: child),
  ));
  await t.pumpAndSettle();
}
