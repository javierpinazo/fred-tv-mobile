import 'package:flutter/foundation.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/utils.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';

/// Se incrementa cada vez que cambian las fuentes (agregar, borrar, activar o
/// refrescar con éxito) para que la UI sepa que debe recargar.
final ValueNotifier<int> tvSourcesVersion = ValueNotifier<int>(0);

String _lastRefreshKey(int sourceId) => 'lastRefresh_$sourceId';

Future<DateTime?> readLastRefresh(int sourceId) async {
  final raw = await Sql.getSetting(_lastRefreshKey(sourceId));
  final ms = raw == null ? null : int.tryParse(raw);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

Future<void> writeLastRefresh(int sourceId, DateTime at) => Sql.setSetting(
    _lastRefreshKey(sourceId), at.millisecondsSinceEpoch.toString());

class SourceRefreshResult {
  const SourceRefreshResult({
    required this.refreshed,
    required this.failedNames,
    this.alreadyRunning = false,
  });

  final int refreshed;
  final List<String> failedNames;
  final bool alreadyRunning;
}

/// Refresca las fuentes de forma secuencial y sin solaparse: una segunda
/// llamada mientras hay una ejecución en curso recibe la misma `Future`.
class SourceRefresher {
  SourceRefresher({
    required this.loadSources,
    required this.refreshOne,
    required this.lastRefresh,
    required this.saveRefresh,
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  static final SourceRefresher instance = SourceRefresher(
    loadSources: Sql.getSources,
    refreshOne: Utils.refreshSource,
    lastRefresh: readLastRefresh,
    saveRefresh: writeLastRefresh,
  );

  static const Duration autoInterval = Duration(hours: 24);

  final Future<List<Source>> Function() loadSources;
  final Future<void> Function(Source source) refreshOne;
  final Future<DateTime?> Function(int sourceId) lastRefresh;
  final Future<void> Function(int sourceId, DateTime at) saveRefresh;
  final DateTime Function() _now;

  Future<SourceRefreshResult>? _running;

  bool get isRunning => _running != null;

  static bool isRefreshable(Source s) =>
      s.enabled &&
      s.name != customSourceName &&
      (s.url ?? '').isNotEmpty &&
      (s.sourceType == SourceType.m3uUrl || s.sourceType == SourceType.xtream);

  Future<SourceRefreshResult> refreshAll({
    bool onlyStale = false,
    int? onlySourceId,
  }) {
    final existing = _running;
    if (existing != null) return existing;
    final run = _run(onlyStale, onlySourceId).whenComplete(() {
      _running = null;
    });
    _running = run;
    return run;
  }

  Future<SourceRefreshResult> _run(bool onlyStale, int? onlySourceId) async {
    final sources = await loadSources();
    var refreshed = 0;
    final failed = <String>[];
    for (final source in sources) {
      if (!isRefreshable(source)) continue;
      if (onlySourceId != null && source.id != onlySourceId) continue;
      if (onlyStale) {
        final last = await lastRefresh(source.id!);
        if (last != null && _now().difference(last) < autoInterval) continue;
      }
      try {
        await refreshOne(source);
        await saveRefresh(source.id!, _now());
        refreshed++;
      } catch (e) {
        debugPrint('SourceRefresher: error refrescando "${source.name}": $e');
        failed.add(source.name);
      }
    }
    if (refreshed > 0) tvSourcesVersion.value++;
    return SourceRefreshResult(refreshed: refreshed, failedNames: failed);
  }
}
