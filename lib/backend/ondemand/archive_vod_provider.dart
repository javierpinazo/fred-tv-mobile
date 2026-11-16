import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/backend/ondemand/archive_vod_parser.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

final _safeId = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

/// Orden de preferencia de los formatos MP4 de Archive: `h.264` (derivado
/// nativo), `MPEG4`, `512Kb MPEG4` y, al final, cualquier otro `.mp4`.
int _formatRank(String format) {
  final f = format.toLowerCase();
  if (f.contains('512kb')) return 2;
  if (f.contains('h.264')) return 0;
  if (f.contains('mpeg4')) return 1;
  return 3;
}

/// Codifica un segmento de ruta; `encodeComponent` deja pasar `( ) ' ! *`.
String _encodeSegment(String s) => Uri.encodeComponent(s)
    .replaceAll('(', '%28')
    .replaceAll(')', '%29')
    .replaceAll("'", '%27')
    .replaceAll('!', '%21')
    .replaceAll('*', '%2A');

/// Elige el MP4 de la película en el JSON de `archive.org/metadata/<id>` y
/// arma su URL de descarga. Lanza [OnDemandUnavailableException] si no hay
/// ningún `.mp4` o el JSON no tiene la forma esperada.
OnDemandStream pickArchiveStream(String identifier, String metadataJson) {
  final Object? decoded;
  try {
    decoded = jsonDecode(metadataJson);
  } on FormatException {
    throw OnDemandUnavailableException(
        'Internet Archive devolvió una respuesta ilegible.');
  }
  final files = decoded is Map ? decoded['files'] : null;
  if (files is! List) {
    throw OnDemandUnavailableException('Internet Archive cambió sus archivos.');
  }
  String? best;
  var bestRank = 99;
  for (final f in files) {
    if (f is! Map) continue;
    final name = f['name'];
    if (name is! String || !name.toLowerCase().endsWith('.mp4')) continue;
    final rank = _formatRank('${f['format'] ?? ''}');
    if (rank < bestRank) {
      best = name;
      bestRank = rank;
    }
  }
  if (best == null) {
    throw OnDemandUnavailableException('Esta película no tiene vídeo MP4.');
  }
  final path = best.split('/').map(_encodeSegment).join('/');
  return OnDemandStream(url: 'https://archive.org/download/$identifier/$path');
}

Future<List<OnDemandTitle>> _parseInIsolate(String json) =>
    compute(parseArchiveSearch, json);

/// Largometrajes en español de Internet Archive (colección `feature_films`).
/// Sin cuenta ni cabeceras: el vídeo es un MP4 directo.
class ArchiveVodProvider implements OnDemandProvider, OnDemandResolver {
  ArchiveVodProvider({
    http.Client? client,
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 30),
    Future<List<OnDemandTitle>> Function(String json)? parse,
  })  : _client = client ?? http.Client(),
        _now = now ?? DateTime.now,
        _parse = parse ?? _parseInIsolate;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration ttl;
  final Future<List<OnDemandTitle>> Function(String json) _parse;

  List<OnDemandTitle>? _cache;
  DateTime? _cachedAt;

  @override
  String get id => 'archive';

  @override
  String get name => 'Internet Archive';

  Future<String> _get(Uri uri, Duration timeout) async {
    try {
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode != 200) {
        throw OnDemandUnavailableException(
            'Internet Archive respondió ${res.statusCode}.');
      }
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    } on OnDemandUnavailableException {
      rethrow;
    } on TimeoutException {
      throw OnDemandUnavailableException('Internet Archive tardó demasiado.');
    } on http.ClientException catch (e) {
      throw OnDemandUnavailableException('Sin conexión con Internet Archive: $e');
    }
  }

  @override
  Future<List<OnDemandTitle>> titles() async {
    final cached = _cache;
    final at = _cachedAt;
    if (cached != null && at != null && _now().difference(at) < ttl) {
      return cached;
    }
    final body = await _get(
      Uri.https('archive.org', '/advancedsearch.php', {
        'q': 'mediatype:movies AND collection:feature_films '
            'AND language:(spanish OR Spanish OR spa)',
        'fl[]': ['identifier', 'title', 'year', 'description', 'subject'],
        'rows': '2000',
        'output': 'json',
        'sort[]': 'downloads desc',
      }),
      const Duration(seconds: 60),
    );
    final titles = await _parse(body);
    _cache = titles;
    _cachedAt = _now();
    return titles;
  }

  @override
  Future<OnDemandStream> resolve(OnDemandTitle title) async {
    final source = title.source;
    if (source is! ArchiveSource || !_safeId.hasMatch(source.videoId)) {
      throw ArgumentError.value(
          title.id, 'title', 'no es una película de Internet Archive');
    }
    final body = await _get(
      Uri.https('archive.org', '/metadata/${source.videoId}'),
      const Duration(seconds: 20),
    );
    return pickArchiveStream(source.videoId, body);
  }
}
