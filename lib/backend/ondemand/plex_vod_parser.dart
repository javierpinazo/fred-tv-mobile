import 'dart:convert';

import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

String _str(Object? v) => v == null ? '' : v.toString().trim();

String _details(Map<dynamic, dynamic> item) {
  final parts = <String>[];
  final year = _str(item['year']);
  if (year.isNotEmpty) parts.add(year);
  final rating = _str(item['contentRating']);
  if (rating.isNotEmpty) parts.add(rating);
  final raw = item['duration'];
  final ms = raw is num ? raw.toInt() : int.tryParse(_str(raw));
  if (ms != null && ms > 0) parts.add('${(ms / 60000).round()} min.');
  return parts.join(' · ');
}

/// Películas de los estantes de Plex (`/hubs/sections/movies/<estante>`): solo
/// `type == 'movie'`, cada una una sola vez aunque esté en varios estantes, y
/// cada estante es una categoría. Un estante ilegible se ignora; lanza
/// [OnDemandUnavailableException] si no queda ninguna película.
List<OnDemandTitle> parsePlexHubs(List<({String title, String json})> hubs) {
  final byId = <String, Map<dynamic, dynamic>>{};
  final cats = <String, List<String>>{};
  for (final hub in hubs) {
    final Object? decoded;
    try {
      decoded = jsonDecode(hub.json);
    } on FormatException {
      continue;
    }
    final container = decoded is Map ? decoded['MediaContainer'] : null;
    final items = container is Map ? container['Metadata'] : null;
    if (items is! List) continue;
    for (final i in items) {
      if (i is! Map || i['type'] != 'movie') continue;
      final id = _str(i['ratingKey']);
      if (id.isEmpty || _str(i['title']).isEmpty) continue;
      byId.putIfAbsent(id, () => i);
      final list = cats.putIfAbsent(id, () => []);
      final name = hub.title.trim();
      if (name.isNotEmpty && !list.contains(name)) list.add(name);
    }
  }
  if (byId.isEmpty) {
    throw OnDemandUnavailableException('Plex no trae películas.');
  }
  return [
    for (final e in byId.entries)
      OnDemandTitle(
        id: e.key,
        title: _str(e.value['title']),
        synopsis: _str(e.value['summary']),
        posterUrl: _str(e.value['thumb']).isNotEmpty
            ? _str(e.value['thumb'])
            : _str(e.value['art']),
        details: _details(e.value),
        source: PlexSource(e.key),
        categories: cats[e.key]!,
      ),
  ];
}
