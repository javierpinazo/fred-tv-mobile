import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/source_refresher.dart';
import 'package:open_tv/backend/sql.dart' show customSourceName;
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';

Source _src(
  int id,
  String name, {
  SourceType type = SourceType.m3uUrl,
  bool enabled = true,
  String url = 'http://example.com/list.m3u',
}) =>
    Source(id: id, name: name, url: url, sourceType: type, enabled: enabled);

final _now = DateTime(2026, 10, 18, 12);

class _Harness {
  _Harness(this.sources, {this.failing = const {}, this.gate});

  final List<Source> sources;
  final Set<String> failing;
  final Completer<void>? gate;
  final List<String> refreshed = [];
  final Map<int, DateTime> last = {};
  final Map<int, DateTime> saved = {};

  late final SourceRefresher refresher = SourceRefresher(
    loadSources: () async => sources,
    refreshOne: (s) async {
      refreshed.add(s.name);
      if (gate != null) await gate!.future;
      if (failing.contains(s.name)) throw Exception('boom ${s.name}');
    },
    lastRefresh: (id) async => last[id],
    saveRefresh: (id, at) async => saved[id] = at,
    now: () => _now,
  );
}

void main() {
  test('solo refresca fuentes válidas', () async {
    final h = _Harness([
      _src(1, 'A'),
      _src(2, 'B', type: SourceType.xtream),
      _src(3, 'C', enabled: false),
      _src(4, customSourceName, type: SourceType.m3u, url: ''),
      _src(5, 'E', url: ''),
      _src(6, 'F', type: SourceType.m3u),
    ]);
    final result = await h.refresher.refreshAll();
    expect(h.refreshed, ['A', 'B']);
    expect(result.refreshed, 2);
    expect(result.failedNames, isEmpty);
  });

  test('onlyStale salta las actualizadas hace menos de 24 h', () async {
    final h = _Harness([_src(1, 'A'), _src(2, 'B'), _src(3, 'C')]);
    h.last[1] = _now.subtract(const Duration(hours: 2));
    h.last[2] = _now.subtract(const Duration(hours: 30));
    // C nunca se actualizó
    await h.refresher.refreshAll(onlyStale: true);
    expect(h.refreshed, ['B', 'C']);
  });

  test('onlySourceId limita a esa fuente', () async {
    final h = _Harness([_src(1, 'A'), _src(2, 'B')]);
    await h.refresher.refreshAll(onlySourceId: 2);
    expect(h.refreshed, ['B']);
  });

  test('un fallo no corta el resto', () async {
    final h = _Harness([_src(1, 'A'), _src(2, 'B')], failing: {'A'});
    final result = await h.refresher.refreshAll();
    expect(h.refreshed, ['A', 'B']);
    expect(result.failedNames, ['A']);
    expect(result.refreshed, 1);
    expect(h.saved.keys, [2], reason: 'solo se guarda la hora de las que salieron bien');
  });

  test('llamadas simultáneas comparten la ejecución', () async {
    final gate = Completer<void>();
    final h = _Harness([_src(1, 'A'), _src(2, 'B')], gate: gate);
    expect(h.refresher.isRunning, isFalse);
    final f1 = h.refresher.refreshAll();
    final f2 = h.refresher.refreshAll();
    expect(identical(f1, f2), isTrue);
    expect(h.refresher.isRunning, isTrue);
    gate.complete();
    await Future.wait([f1, f2]);
    expect(h.refreshed, ['A', 'B']);
    expect(h.refresher.isRunning, isFalse);
    // Terminada la ejecución se puede lanzar otra.
    await h.refresher.refreshAll();
    expect(h.refreshed.length, 4);
  });

  test('incrementa tvSourcesVersion solo si refrescó algo', () async {
    final h = _Harness([_src(1, 'A')]);
    final before = tvSourcesVersion.value;
    await h.refresher.refreshAll();
    expect(tvSourcesVersion.value, before + 1);

    final none = _Harness([_src(1, 'A', enabled: false)]);
    final mid = tvSourcesVersion.value;
    await none.refresher.refreshAll();
    expect(tvSourcesVersion.value, mid);
  });

  test('guarda la hora de refresco', () async {
    final h = _Harness([_src(1, 'A')]);
    await h.refresher.refreshAll();
    expect(h.saved[1], _now);
  });

  test('isRefreshable', () {
    expect(SourceRefresher.isRefreshable(_src(1, 'A')), isTrue);
    expect(SourceRefresher.isRefreshable(_src(1, 'A', enabled: false)), isFalse);
    expect(SourceRefresher.isRefreshable(_src(1, customSourceName)), isFalse);
    expect(SourceRefresher.isRefreshable(_src(1, 'A', type: SourceType.m3u)), isFalse);
    expect(SourceRefresher.isRefreshable(_src(1, 'A', url: '')), isFalse);
  });
}
