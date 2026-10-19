import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/models/source_type.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_tv/backend/backup_sql.dart';
import 'package:open_tv/backend/channel_health_sql.dart';
import 'package:open_tv/backend/iptv_org_catalog.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/user_playlists_sql.dart';
import 'package:open_tv/backend/utils.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_http_headers.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/user_playlist.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';
import 'package:open_tv/screens/tv/guide/xmltv_guide.dart';
import 'package:open_tv/screens/tv/player/tv_buffer.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';
import 'package:open_tv/screens/tv/tv_appearance.dart';
import 'package:open_tv/screens/tv/tv_parental.dart';

const String _autoRefreshKey = 'tvAutoRefresh';
const String _bufferKey = 'tvBufferSecs';
const String _engineKey = 'tvEngine';
const String _hideDeadKey = 'tvHideDead';
const String _epgUrlKey = 'tvEpgUrl';
const String _epgShareBase = 'https://epgshare01.online/epgshare01/epg_ripper_';
const String _hideAdultKey = 'tvHideAdult';
const String _pinKey = 'tvParentalPin';
const String _textScaleKey = 'tvTextScale';
const String _contrastKey = 'tvHighContrast';
const String _channelEnginePrefix = 'tvEngine:';

/// Fachada inyectable sobre el backend para las pantallas de TV.
class TvData {
  const TvData();

  static final IptvOrgCatalog _catalog = IptvOrgCatalog();
  static final XmltvGuide _xmltv = XmltvGuide(urls: _epgUrls);
  static final TvGuide _guide = TvGuide(providers: [TvPeruGuide(), _xmltv]);

  /// XMLTV a descargar: el de cada país de tus favoritos y vistos (por defecto
  /// Perú) y la URL personalizada, si la hay.
  static Future<List<String>> _epgUrls() async {
    final countries = await Sql.watchedCountries();
    final urls = [
      for (final c in countries.isEmpty ? const ['pe'] : countries)
        '$_epgShareBase${c.toUpperCase()}1.xml.gz',
    ];
    final custom = (await Sql.getSetting(_epgUrlKey))?.trim();
    if (custom != null && custom.isNotEmpty) urls.add(custom);
    return urls;
  }

  /// Descarga y prepara las guías en segundo plano (no lanza).
  Future<void> warmUpGuide() async {
    try {
      await _xmltv.load();
    } catch (e) {
      debugPrint('TvData: no se pudo preparar la guía: $e');
    }
  }

  Future<String?> epgUrlSetting() async {
    final v = (await Sql.getSetting(_epgUrlKey))?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  /// Guarda la URL XMLTV personalizada (`null` la quita) y recarga las guías.
  Future<void> setEpgUrlSetting(String? url) async {
    await Sql.setSetting(_epgUrlKey, url?.trim() ?? '');
    unawaited(_xmltv.load(force: true).catchError((Object e) {
      debugPrint('TvData: no se pudo recargar la guía: $e');
    }));
  }

  // --- Guía de programación -----------------------------------------------

  /// Si algún proveedor de guía reconoce el canal.
  bool hasGuide(Channel channel) => _guide.providerFor(channel) != null;

  /// Programas del día [limaDay] (fecha de Lima, sin hora). Lanza
  /// [GuideException] si no se pudo cargar.
  Future<List<GuideProgram>> guideDay(Channel channel, DateTime limaDay) async {
    final provider = _guide.providerFor(channel);
    return provider == null ? const [] : provider.day(channel, limaDay);
  }

  /// Programa actual y siguiente; `null` si no hay guía o no se pudo cargar.
  Future<GuideNowNext?> guideNowNext(Channel channel) =>
      _guide.nowNext(channel);

  // --- Canales ------------------------------------------------------------

  Future<List<int>> enabledSourceIds() async =>
      (await Sql.getEnabledSourcesMinimal()).map((x) => x.id).toList();

  Future<List<Channel>> searchChannels(Filters f) async {
    // Solo Canales y Búsqueda ocultan los caídos; Favoritos e historial no.
    if (f.viewType == ViewType.all) f.hideDead = await hideDeadSetting();
    f.hideAdult = await hideAdultSetting();
    return Sql.search(f);
  }

  // --- Copia de seguridad -------------------------------------------------

  /// Carpeta de copias: la externa de la app (accesible desde un PC o un
  /// gestor de archivos) o, si no hay, la interna.
  Future<Directory> _backupDir() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {}
    base ??= Directory(await Utils.appDir);
    final dir = Directory('${base.path}/backups');
    await dir.create(recursive: true);
    return dir;
  }

  /// Guarda una copia en la carpeta de copias y devuelve su ruta.
  Future<String> exportBackupToFile() async {
    final data = await BackupSql.export();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
    final file = File('${(await _backupDir()).path}/fred-tv-$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  /// Copias guardadas, la más reciente primero.
  Future<List<String>> listBackupFiles() async {
    final files = (await _backupDir())
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .map((f) => f.path)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return files;
  }

  Future<BackupResult> importBackupFromFile(String path) async =>
      _importBackup(BackupSql.parse(await File(path).readAsString()));

  Future<BackupResult> importBackupFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      throw BackupFormatException('La dirección no es válida');
    }
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw BackupFormatException(
          'No se pudo descargar (HTTP ${res.statusCode})');
    }
    return _importBackup(BackupSql.parse(utf8.decode(res.bodyBytes)));
  }

  /// Elegir un archivo del dispositivo; `null` si se cancela o no hay selector
  /// (muchos Android TV no lo traen).
  Future<String?> pickBackupFile() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      return r?.files.single.path;
    } catch (e) {
      debugPrint('TvData: no se pudo abrir el selector de archivos: $e');
      return null;
    }
  }

  Future<BackupResult> _importBackup(Map<String, dynamic> data) async {
    var added = 0;
    for (final s in await BackupSql.sourcesToAdd(data)) {
      try {
        await addSource(Source(
          name: s['name'] as String,
          url: s['url'] as String,
          sourceType: SourceType.m3uUrl,
          enabled: true,
        ));
        added++;
      } catch (e) {
        debugPrint('TvData: no se pudo añadir la lista "${s['name']}": $e');
      }
    }
    final result = await BackupSql.restore(data);
    tvSourcesVersion.value++;
    return result.copyWith(sourcesAdded: added);
  }

  // --- Control parental ---------------------------------------------------

  Future<bool> hideAdultSetting() async =>
      await Sql.getSetting(_hideAdultKey) == '1';

  Future<void> setHideAdultSetting(bool value) =>
      Sql.setSetting(_hideAdultKey, value ? '1' : '0');

  Future<bool> parentalPinSet() async =>
      (await Sql.getSetting(_pinKey))?.isNotEmpty ?? false;

  /// Guarda el PIN (solo su hash con sal); `null` lo quita.
  Future<void> setParentalPin(String? pin) =>
      Sql.setSetting(_pinKey, pin == null ? '' : TvParental.encode(pin));

  Future<bool> verifyParentalPin(String pin) async =>
      TvParental.verify(pin, await Sql.getSetting(_pinKey));

  /// Países con canales (de más a menos), para el filtro de Búsqueda.
  Future<List<({String code, int count})>> countries() async =>
      Sql.countries(await enabledSourceIds());

  // --- Estado de los canales ----------------------------------------------

  Future<bool> hideDeadSetting() async =>
      await Sql.getSetting(_hideDeadKey) == '1';

  Future<void> setHideDeadSetting(bool value) =>
      Sql.setSetting(_hideDeadKey, value ? '1' : '0');

  /// Cuenta un fallo de reproducción; `true` si el canal ya cuenta como caído.
  Future<bool> reportChannelFailure(Channel channel) async {
    await ChannelHealthSql.recordFailure(channel.sourceId, channel.name);
    return ChannelHealthSql.isDead(channel.sourceId, channel.name);
  }

  Future<void> reportChannelSuccess(Channel channel) =>
      ChannelHealthSql.recordSuccess(channel.sourceId, channel.name);

  Future<void> markChannelDead(Channel channel) =>
      ChannelHealthSql.markDead(channel.sourceId, channel.name);

  Future<void> clearChannelDead(Channel channel) =>
      ChannelHealthSql.clear(channel.sourceId, channel.name);

  Future<int> deadChannelCount() => ChannelHealthSql.deadCount();

  Future<void> clearDeadChannels() => ChannelHealthSql.clearAll();

  /// Si hay canales vistos recientemente (historial de hasta 36).
  Future<bool> hasRecents() async {
    final ids = await enabledSourceIds();
    if (ids.isEmpty) return false;
    final r = await Sql.search(Filters(
      viewType: ViewType.history,
      sourceIds: ids,
      mediaTypes: [MediaType.livestream],
      page: 1,
    ));
    return r.isNotEmpty;
  }

  Future<List<Channel>> searchGroups(Filters f) async {
    f.hideAdult = await hideAdultSetting();
    return Sql.searchGroupNames(f);
  }

  /// Id vigente del canal (puede haber cambiado si su fuente se refrescó
  /// después de mostrarlo); `null` si el canal ya no existe.
  Future<int?> resolveChannelId(Channel channel) =>
      Sql.channelIdByKey(channel.sourceId, channel.name);

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
    final saved = (await Sql.getSources())
        .where((s) => s.name == source.name)
        .firstOrNull;
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

  Future<int> bufferSeconds() async {
    final raw = await Sql.getSetting(_bufferKey);
    return int.tryParse(raw ?? '') ?? TvBuffer.defaultSeconds;
  }

  Future<void> setBufferSeconds(int seconds) =>
      Sql.setSetting(_bufferKey, '$seconds');

  /// Motor elegido para un canal concreto (p. ej. uno con audio que
  /// ExoPlayer no decodifica); `null` si sigue el ajuste general.
  Future<TvEngineKind?> channelEngine(String url) async {
    final raw = await Sql.getSetting('$_channelEnginePrefix$url');
    return switch (raw) {
      'exo' => TvEngineKind.exo,
      'mpv' => TvEngineKind.mpv,
      _ => null,
    };
  }

  Future<void> setChannelEngine(String url, TvEngineKind kind) =>
      Sql.setSetting('$_channelEnginePrefix$url', kind.name);

  // --- Accesibilidad ------------------------------------------------------

  Future<double> textScaleSetting() async =>
      TvAppearance.parseScale(await Sql.getSetting(_textScaleKey));

  Future<void> setTextScaleSetting(double value) =>
      Sql.setSetting(_textScaleKey, '$value');

  Future<bool> highContrastSetting() async =>
      await Sql.getSetting(_contrastKey) == '1';

  Future<void> setHighContrastSetting(bool value) =>
      Sql.setSetting(_contrastKey, value ? '1' : '0');

  Future<TvEngineMode> videoEngineMode() async =>
      TvEngineMode.fromName(await Sql.getSetting(_engineKey));

  Future<void> setVideoEngineMode(TvEngineMode mode) =>
      Sql.setSetting(_engineKey, mode.name);

  IptvOrgCatalog get catalog => _catalog;

  // --- Listas propias -----------------------------------------------------

  Future<List<UserPlaylist>> userPlaylists() => UserPlaylistsSql.all();

  Future<int> createUserPlaylist(String name) => UserPlaylistsSql.create(name);

  Future<void> renameUserPlaylist(int id, String name) =>
      UserPlaylistsSql.rename(id, name);

  Future<void> deleteUserPlaylist(int id) => UserPlaylistsSql.delete(id);

  Future<bool> addToUserPlaylist(int playlistId, Channel channel) =>
      UserPlaylistsSql.add(playlistId, channel);

  Future<void> removeFromUserPlaylist(int playlistId, Channel channel) =>
      UserPlaylistsSql.remove(playlistId, channel);

  Future<void> moveInUserPlaylist(int playlistId, Channel channel, int delta) =>
      UserPlaylistsSql.move(playlistId, channel, delta);

  Future<List<Channel>> userPlaylistChannels(int playlistId) =>
      UserPlaylistsSql.channels(playlistId);

  Future<int?> customSourceId() => UserPlaylistsSql.customSourceId();

  Future<void> deleteManualChannel(Channel channel) =>
      UserPlaylistsSql.deleteManualChannel(channel);

  Future<Channel> addManualChannel({
    required String name,
    required String url,
  }) =>
      UserPlaylistsSql.addManualChannel(name: name, url: url);
}
