import 'dart:convert';

import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

String _str(Object? v) => v is String ? v.trim() : '';

String _poster(Map<String, dynamic> item) {
  final covers = item['covers'];
  if (covers is List) {
    String? first;
    for (final c in covers) {
      if (c is! Map) continue;
      final url = _str(c['url']);
      if (url.isEmpty) continue;
      first ??= url;
      // Cartel vertical (347:500); las demás son capturas horizontales.
      if (_str(c['aspectRatio']) == '347:500') return url;
    }
    if (first != null) return first;
  }
  final featured = item['featuredImage'];
  if (featured is Map) return _str(featured['path']);
  return '';
}

String _details(Map<String, dynamic> item) {
  final parts = <String>[];
  final genre = _str(item['genre']);
  if (genre.isNotEmpty) parts.add(genre);
  final rating = _str(item['rating']);
  if (rating.isNotEmpty) parts.add(rating);
  // La API la manda como número (o, a veces, como texto).
  final raw = item['originalContentDuration'];
  final ms = raw is num ? raw.toInt() : int.tryParse(_str(raw));
  if (ms != null && ms > 0) {
    parts.add('${(ms / 60000).round()} min.');
  }
  return parts.join(' · ');
}

/// Películas del catálogo de Pluto TV (`/v4/vod/categories?includeItems=true`):
/// solo `type == 'movie'`, cada una una sola vez aunque esté en varias
/// categorías. Lanza [OnDemandUnavailableException] si el JSON no tiene la
/// forma esperada o no trae ninguna película.
List<OnDemandTitle> parsePlutoVodCatalog(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw OnDemandUnavailableException('Pluto TV devolvió una respuesta ilegible.');
  }
  final categories = decoded is Map ? decoded['categories'] : null;
  if (categories is! List) {
    throw OnDemandUnavailableException('Pluto TV cambió su catálogo.');
  }
  final byId = <String, Map<String, dynamic>>{};
  final cats = <String, List<String>>{};
  for (final c in categories) {
    if (c is! Map) continue;
    final catName = _str(c['name']);
    final items = c['items'];
    if (items is! List) continue;
    for (final i in items) {
      if (i is! Map<String, dynamic>) continue;
      if (i['type'] != 'movie') continue;
      final id = _str(i['_id']);
      if (id.isEmpty || _str(i['name']).isEmpty) continue;
      byId.putIfAbsent(id, () => i);
      final list = cats.putIfAbsent(id, () => []);
      if (catName.isNotEmpty && !list.contains(catName)) list.add(catName);
    }
  }
  if (byId.isEmpty) {
    throw OnDemandUnavailableException('Pluto TV no trae películas.');
  }
  return [
    for (final e in byId.entries)
      OnDemandTitle(
        id: e.key,
        title: _str(e.value['name']),
        synopsis: _str(e.value['summary']).isNotEmpty
            ? _str(e.value['summary'])
            : _str(e.value['description']),
        posterUrl: _poster(e.value),
        details: _details(e.value),
        source: PlutoSource(e.key),
        categories: cats[e.key]!,
      ),
  ];
}
