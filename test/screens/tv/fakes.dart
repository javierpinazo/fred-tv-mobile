import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/iptv_org_catalog.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/backend/sql.dart' show pageSize;
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_http_headers.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/user_playlist.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';

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
    List<Source>? sources,
    IptvOrgCatalog? catalog,
  })  : sourcesList = sources ?? [],
        _fakeCatalog = catalog ?? IptvOrgCatalog();

  final List<String> groups;
  final List<Channel> channels;
  final Future<List<Channel>> Function(Filters f)? onSearchChannels;

  // --- Fuentes (en memoria) ---
  final List<Source> sourcesList;
  final IptvOrgCatalog _fakeCatalog;
  final List<Source> addedSources = [];
  final List<int> deletedIds = [];
  final List<(int, bool)> enabledCalls = [];
  final List<({bool onlyStale, int? onlySourceId})> refreshCalls = [];
  final Map<int, DateTime> lastRefreshes = {};
  bool autoRefresh = true;
  bool refreshing = false;
  Object? addSourceError;
  SourceRefreshResult refreshResult =
      const SourceRefreshResult(refreshed: 0, failedNames: []);
  int _nextSourceId = 100;

  final List<Filters> channelCalls = [];
  final List<Filters> groupCalls = [];
  final List<(int, bool)> favoriteCalls = [];
  final List<int> historyCalls = [];

  @override
  Future<List<int>> enabledSourceIds() async => [1];

  @override
  Future<List<Channel>> searchGroups(Filters f) async {
    groupCalls.add(f);
    final start = (f.page - 1) * pageSize;
    if (start >= groups.length) return [];
    final end = (start + pageSize).clamp(0, groups.length);
    return groups
        .sublist(start, end)
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

  /// Simula una actualización de fuente: ids nuevos por nombre de canal.
  final Map<String, int> resolvedIds = {};

  /// Nombres de canales que ya no existen tras la "actualización".
  final Set<String> vanished = {};

  @override
  Future<int?> resolveChannelId(Channel channel) async {
    if (vanished.contains(channel.name)) return null;
    return resolvedIds[channel.name] ?? channel.id;
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

  @override
  Future<List<Source>> sources() async => List.of(sourcesList);

  @override
  Future<void> addSource(Source source) async {
    if (addSourceError != null) throw addSourceError!;
    if (sourcesList.any((s) => s.name == source.name)) {
      throw StateError('duplicate');
    }
    source.id ??= _nextSourceId++;
    sourcesList.add(source);
    addedSources.add(source);
    lastRefreshes[source.id!] = DateTime.now();
    tvSourcesVersion.value++;
  }

  @override
  Future<void> deleteSource(int id) async {
    deletedIds.add(id);
    sourcesList.removeWhere((s) => s.id == id);
    tvSourcesVersion.value++;
  }

  @override
  Future<void> setSourceEnabled(int id, bool enabled) async {
    enabledCalls.add((id, enabled));
    for (final s in sourcesList) {
      if (s.id == id) s.enabled = enabled;
    }
    tvSourcesVersion.value++;
  }

  @override
  Future<SourceRefreshResult> refreshSources({
    bool onlyStale = false,
    int? onlySourceId,
  }) async {
    refreshCalls.add((onlyStale: onlyStale, onlySourceId: onlySourceId));
    return refreshResult;
  }

  @override
  bool get isRefreshing => refreshing;

  @override
  Future<DateTime?> lastRefresh(int sourceId) async => lastRefreshes[sourceId];

  @override
  Future<bool> autoRefreshEnabled() async => autoRefresh;

  @override
  Future<void> setAutoRefreshEnabled(bool value) async => autoRefresh = value;

  @override
  IptvOrgCatalog get catalog => _fakeCatalog;

  // --- Listas propias (en memoria; misma semántica que el SQL real) ---
  final Map<int, String> playlistNames = {};
  final Map<int, List<Channel>> playlistItems = {};
  int _nextPlaylistId = 1;
  int _nextManualId = 9000;

  bool _nameTaken(String name, {int? exceptId}) => playlistNames.entries.any(
      (e) => e.key != exceptId && e.value.toLowerCase() == name.toLowerCase());

  bool _sameChannel(Channel a, Channel b) =>
      a.sourceId == b.sourceId && a.name == b.name;

  @override
  Future<List<UserPlaylist>> userPlaylists() async {
    final list = playlistNames.entries
        .map((e) => UserPlaylist(
            id: e.key,
            name: e.value,
            channelCount: playlistItems[e.key]!.length))
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<int> createUserPlaylist(String name) async {
    if (_nameTaken(name)) throw StateError('duplicate');
    final id = _nextPlaylistId++;
    playlistNames[id] = name;
    playlistItems[id] = [];
    return id;
  }

  @override
  Future<void> renameUserPlaylist(int id, String name) async {
    if (_nameTaken(name, exceptId: id)) throw StateError('duplicate');
    playlistNames[id] = name;
  }

  @override
  Future<void> deleteUserPlaylist(int id) async {
    playlistNames.remove(id);
    playlistItems.remove(id);
  }

  @override
  Future<bool> addToUserPlaylist(int playlistId, Channel channel) async {
    final items = playlistItems[playlistId]!;
    if (items.any((c) => _sameChannel(c, channel))) return false;
    items.add(channel);
    return true;
  }

  @override
  Future<void> removeFromUserPlaylist(int playlistId, Channel channel) async {
    playlistItems[playlistId]!.removeWhere((c) => _sameChannel(c, channel));
  }

  @override
  Future<void> moveInUserPlaylist(
      int playlistId, Channel channel, int delta) async {
    final items = playlistItems[playlistId]!;
    final i = items.indexWhere((c) => _sameChannel(c, channel));
    final j = i + delta;
    if (i < 0 || j < 0 || j >= items.length) return;
    final tmp = items[i];
    items[i] = items[j];
    items[j] = tmp;
  }

  @override
  Future<List<Channel>> userPlaylistChannels(int playlistId) async =>
      List.of(playlistItems[playlistId] ?? const <Channel>[]);

  @override
  Future<Channel> addManualChannel({
    required String name,
    required String url,
  }) async {
    return Channel(
      id: _nextManualId++,
      name: name,
      url: url,
      mediaType: MediaType.livestream,
      sourceId: 0,
      favorite: false,
      group: 'Mis canales',
    );
  }
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

/// `true` si el [TvFocusable] con esa key (o dentro del widget con esa key) tiene el foco.
bool isFocused(WidgetTester t, Key key) {
  final f = find.descendant(
    of: find.byKey(key),
    matching: find.byType(TvFocusable),
    matchRoot: true,
  );
  if (f.evaluate().isEmpty) return false;
  return t.state<TvFocusableState>(f.first).hasFocus;
}

/// Inyecta la tecla Atrás (el simulador no la soporta); devuelve si algún
/// widget la consumió.
bool injectBackKey() {
  final handled = HardwareKeyboard.instance.handleKeyEvent(KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.browserBack,
    logicalKey: LogicalKeyboardKey.goBack,
    timeStamp: Duration.zero,
  ));
  HardwareKeyboard.instance.handleKeyEvent(KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.browserBack,
    logicalKey: LogicalKeyboardKey.goBack,
    timeStamp: Duration.zero,
  ));
  return handled;
}

/// Da el foco al [TvFocusable] con esa key.
Future<void> focusKey(WidgetTester t, String key) async {
  final f = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TvFocusable),
    matchRoot: true,
  );
  t.state<TvFocusableState>(f.first).focusNode.requestFocus();
  await t.pump();
}
