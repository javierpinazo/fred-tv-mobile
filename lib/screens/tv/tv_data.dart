import 'package:open_tv/backend/iptv_org_catalog.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/utils.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_http_headers.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/source.dart';

const String _autoRefreshKey = 'tvAutoRefresh';

/// Fachada inyectable sobre el backend para las pantallas de TV.
class TvData {
  const TvData();

  static final IptvOrgCatalog _catalog = IptvOrgCatalog();

  // --- Canales ------------------------------------------------------------

  Future<List<int>> enabledSourceIds() async =>
      (await Sql.getEnabledSourcesMinimal()).map((x) => x.id).toList();

  Future<List<Channel>> searchChannels(Filters f) => Sql.search(f);

  Future<List<Channel>> searchGroups(Filters f) => Sql.searchGroupNames(f);

  Future<void> setFavorite(int channelId, bool favorite) =>
      Sql.favoriteChannel(channelId, favorite);

  Future<void> addToHistory(int channelId) => Sql.addToHistory(channelId);

  Future<ChannelHttpHeaders?> channelHeaders(int channelId) =>
      Sql.getChannelHeaders(channelId);

  // --- Fuentes ------------------------------------------------------------

  Future<List<Source>> sources() => Sql.getSources();

  /// Agrega y descarga una fuente. Lanza `StateError('duplicate')` si ya
  /// existe una fuente con ese nombre.
  Future<void> addSource(Source source) async {
    if (await Sql.sourceNameExists(source.name)) {
      throw StateError('duplicate');
    }
    await Utils.processSource(source);
    final saved =
        (await Sql.getSources()).where((s) => s.name == source.name).firstOrNull;
    if (saved?.id != null) {
      await writeLastRefresh(saved!.id!, DateTime.now());
    }
    tvSourcesVersion.value++;
  }

  Future<void> deleteSource(int id) async {
    await Sql.deleteSource(id);
    tvSourcesVersion.value++;
  }

  Future<void> setSourceEnabled(int id, bool enabled) async {
    await Sql.setSourceEnabled(enabled, id);
    tvSourcesVersion.value++;
  }

  Future<SourceRefreshResult> refreshSources({
    bool onlyStale = false,
    int? onlySourceId,
  }) =>
      SourceRefresher.instance
          .refreshAll(onlyStale: onlyStale, onlySourceId: onlySourceId);

  bool get isRefreshing => SourceRefresher.instance.isRunning;

  Future<DateTime?> lastRefresh(int sourceId) => readLastRefresh(sourceId);

  Future<bool> autoRefreshEnabled() async =>
      (await Sql.getSetting(_autoRefreshKey)) != '0';

  Future<void> setAutoRefreshEnabled(bool value) =>
      Sql.setSetting(_autoRefreshKey, value ? '1' : '0');

  IptvOrgCatalog get catalog => _catalog;
}
