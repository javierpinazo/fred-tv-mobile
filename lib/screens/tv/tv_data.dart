import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_http_headers.dart';
import 'package:open_tv/models/filters.dart';

/// Fachada inyectable sobre el backend para las pantallas de TV.
class TvData {
  const TvData();

  Future<List<int>> enabledSourceIds() async =>
      (await Sql.getEnabledSourcesMinimal()).map((x) => x.id).toList();

  Future<List<Channel>> searchChannels(Filters f) => Sql.search(f);

  Future<List<Channel>> searchGroups(Filters f) => Sql.searchGroupNames(f);

  Future<void> setFavorite(int channelId, bool favorite) =>
      Sql.favoriteChannel(channelId, favorite);

  Future<void> addToHistory(int channelId) => Sql.addToHistory(channelId);

  Future<ChannelHttpHeaders?> channelHeaders(int channelId) =>
      Sql.getChannelHeaders(channelId);
}
