import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/plex_vod_parser.dart';
import 'package:open_tv/backend/ondemand/uuid.dart';

const _vodBase = 'https://vod.provider.plex.tv';
final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

typedef PlexHubs = List<({String title, String json})>;

/// Elige el vídeo HLS en el JSON de `/library/metadata/<ratingKey>` y arma su
/// URL con el token. Lanza [OnDemandUnavailableException] si no hay HLS o el
/// JSON no tiene la forma esperada.
OnDemandStream pickPlexStream(
    String ratingKey, String token, String metadataJson) {
  final Object? decoded;
  try {
    decoded = jsonDecode(metadataJson);
  } on FormatException {
    throw OnDemandUnavailableException('Plex devolvió una respuesta ilegible.');
  }
  final container = decoded is Map ? decoded['MediaContainer'] : null;
  final metadata = container is Map ? container['Metadata'] : null;
  final item = metadata is List && metadata.isNotEmpty ? metadata.first : null;
  final media = item is Map ? item['Media'] : null;
  if (media is List) {
    for (final m in media) {
      if (m is! Map || m['protocol'] != 'hls') continue;
      final parts = m['Part'];
      final key = parts is List && parts.isNotEmpty && parts.first is Map
          ? (parts.first as Map)['key']
          : null;
      if (key is String && key.startsWith('/')) {
        return OnDemandStream(
          url: '$_vodBase$key?X-Plex-Token=$token',
          headers: {'X-Plex-Token': token},
        );
      }
    }
  }
  throw OnDemandUnavailableException('Esta película no tiene vídeo HLS en Plex.');
}

Future<List<OnDemandTitle>> _parseInIsolate(PlexHubs hubs) =>
    compute(parsePlexHubs, hubs);

/// Películas gratuitas (con anuncios) de Plex. Sesión anónima, estantes de
/// `/hubs/promoted` como categorías y URL HLS resuelta al pulsar «Ver».
class PlexVodProvider implements OnDemandProvider, OnDemandResolver {
  PlexVodProvider({
    http.Client? client,
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 30),
    Future<List<OnDemandTitle>> Function(PlexHubs hubs)? parse,
  })  : _client = client ?? http.Client(),
        _now = now ?? DateTime.now,
        _parse = parse ?? _parseInIsolate;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration ttl;
  final Future<List<OnDemandTitle>> Function(PlexHubs hubs) _parse;

  List<OnDemandTitle>? _cache;
  DateTime? _cachedAt;

  @override
  String get id => 'plex';

  @override
  String get name => 'Plex';

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on OnDemandUnavailableException {
      rethrow;
    } on TimeoutException {
      throw OnDemandUnavailableException('Plex tardó demasiado.');
    } on http.ClientException catch (e) {
      throw OnDemandUnavailableException('Sin conexión con Plex: $e');
    }
  }

  Future<String> _newToken() => _guard(() async {
        final res = await _client.post(
          Uri.parse('https://clients.plex.tv/api/v2/users/anonymous'),
          headers: {
            'X-Plex-Client-Identifier': newUuidV4(),
            'X-Plex-Product': 'Plex Web',
            'X-Plex-Version': '4.145.1',
            'X-Plex-Platform': 'Chrome',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 20));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw OnDemandUnavailableException(
              'Plex respondió ${res.statusCode} al abrir sesión.');
        }
        final Object? json;
        try {
          json = jsonDecode(utf8.decode(res.bodyBytes));
        } on FormatException {
          throw OnDemandUnavailableException('Sesión de Plex ilegible.');
        }
        final token = json is Map ? json['authToken'] : null;
        if (token is! String || token.isEmpty) {
          throw OnDemandUnavailableException('Sesión de Plex incompleta.');
        }
        return token;
      });

  Future<String> _getJson(String path, String token, [Duration? timeout]) =>
      _guard(() async {
        final res = await _client.get(Uri.parse('$_vodBase$path'), headers: {
          'X-Plex-Token': token,
          'Accept': 'application/json',
        }).timeout(timeout ?? const Duration(seconds: 20));
        if (res.statusCode != 200) {
          throw OnDemandUnavailableException(
              'Plex respondió ${res.statusCode}.');
        }
        return utf8.decode(res.bodyBytes, allowMalformed: true);
      });

  @override
  Future<List<OnDemandTitle>> titles() async {
    final cached = _cache;
    final at = _cachedAt;
    if (cached != null && at != null && _now().difference(at) < ttl) {
      return cached;
    }
    final token = await _newToken();
    final promoted = await _getJson('/hubs/promoted', token);
    final Object? decoded;
    try {
      decoded = jsonDecode(promoted);
    } on FormatException {
      throw OnDemandUnavailableException('Plex devolvió estantes ilegibles.');
    }
    final container = decoded is Map ? decoded['MediaContainer'] : null;
    final hubs = container is Map ? container['Hub'] : null;
    if (hubs is! List) {
      throw OnDemandUnavailableException('Plex cambió sus estantes.');
    }
    final wanted = <({String title, String key})>[
      for (final h in hubs.take(12))
        if (h is Map &&
            h['title'] is String &&
            h['key'] is String &&
            (h['key'] as String).startsWith('/'))
          (title: h['title'] as String, key: h['key'] as String),
    ];
    // Los estantes se piden en paralelo; uno que falle no tumba al resto.
    final results = await Future.wait([
      for (final h in wanted) _hub(h.title, h.key, token),
    ]);
    final ok = <({String title, String json})>[
      for (final r in results)
        if (r != null) r
    ];
    if (ok.isEmpty) {
      throw OnDemandUnavailableException('Plex no devolvió ningún estante.');
    }
    final titles = await _parse(ok);
    _cache = titles;
    _cachedAt = _now();
    return titles;
  }

  Future<({String title, String json})?> _hub(
      String title, String key, String token) async {
    try {
      final json =
          await _getJson('$key?count=100', token, const Duration(seconds: 30));
      return (title: title, json: json);
    } on OnDemandUnavailableException catch (e) {
      debugPrint('PlexVodProvider: estante «$title» omitido: $e');
      return null;
    }
  }

  @override
  Future<OnDemandStream> resolve(OnDemandTitle title) async {
    final source = title.source;
    if (source is! PlexSource || !_safeId.hasMatch(source.videoId)) {
      throw ArgumentError.value(title.id, 'title', 'no es una película de Plex');
    }
    final token = await _newToken();
    final body = await _getJson('/library/metadata/${source.videoId}', token);
    return pickPlexStream(source.videoId, token, body);
  }
}
