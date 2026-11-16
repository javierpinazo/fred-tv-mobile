import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/ondemand/pluto_vod_parser.dart';
import 'package:open_tv/backend/ondemand/uuid.dart';

final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Sesión anónima de Pluto TV: el token caduca (24 h), así que no se guarda
/// junto al catálogo.
class _PlutoSession {
  const _PlutoSession({
    required this.token,
    required this.vodBase,
    required this.stitcherBase,
    required this.stitcherParams,
  });

  final String token;
  final String vodBase;
  final String stitcherBase;
  final String stitcherParams;

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};
}

Future<List<OnDemandTitle>> _parseInIsolate(String json) =>
    compute(parsePlutoVodCatalog, json);

/// Películas gratuitas (con anuncios) de Pluto TV. API no oficial: sesión
/// anónima, catálogo de películas por categorías y URL de reproducción
/// resuelta al pulsar «Ver».
class PlutoVodProvider implements OnDemandProvider, OnDemandResolver {
  PlutoVodProvider({
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
  String get id => 'pluto';

  @override
  String get name => 'Pluto TV';

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on OnDemandUnavailableException {
      rethrow;
    } on TimeoutException {
      throw OnDemandUnavailableException('Pluto TV tardó demasiado.');
    } on http.ClientException catch (e) {
      throw OnDemandUnavailableException('Sin conexión con Pluto TV: $e');
    }
  }

  Future<_PlutoSession> _newSession() => _guard(() async {
        final uri = Uri.https('boot.pluto.tv', '/v4/start', {
          'appName': 'web',
          'appVersion': '9.0.0',
          'deviceVersion': '120.0.0',
          'deviceModel': 'web',
          'deviceMake': 'chrome',
          'deviceType': 'web',
          'clientID': newUuidV4(),
          'clientModelNumber': '1.0.0',
          'serverSideAds': 'false',
        });
        final res =
            await _client.get(uri).timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) {
          throw OnDemandUnavailableException(
              'Pluto TV respondió ${res.statusCode} al abrir sesión.');
        }
        final Object? json;
        try {
          json = jsonDecode(utf8.decode(res.bodyBytes));
        } on FormatException {
          throw OnDemandUnavailableException('Sesión de Pluto TV ilegible.');
        }
        final servers = json is Map ? json['servers'] : null;
        final token = json is Map ? json['sessionToken'] : null;
        final params = json is Map ? json['stitcherParams'] : null;
        final vod = servers is Map ? servers['vod'] : null;
        final stitcher = servers is Map ? servers['stitcher'] : null;
        if (token is! String ||
            token.isEmpty ||
            params is! String ||
            vod is! String ||
            stitcher is! String) {
          throw OnDemandUnavailableException('Sesión de Pluto TV incompleta.');
        }
        return _PlutoSession(
          token: token,
          vodBase: vod,
          stitcherBase: stitcher,
          stitcherParams: params,
        );
      });

  @override
  Future<List<OnDemandTitle>> titles() async {
    final cached = _cache;
    final at = _cachedAt;
    if (cached != null && at != null && _now().difference(at) < ttl) {
      return cached;
    }
    final session = await _newSession();
    final body = await _guard(() async {
      final res = await _client
          .get(
            Uri.parse('${session.vodBase}/v4/vod/categories'
                '?includeItems=true&offset=1000&page=1'),
            headers: session.authHeaders,
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw OnDemandUnavailableException(
            'Pluto TV respondió ${res.statusCode} al pedir el catálogo.');
      }
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    });
    final titles = await _parse(body);
    _cache = titles;
    _cachedAt = _now();
    return titles;
  }

  @override
  Future<OnDemandStream> resolve(OnDemandTitle title) async {
    final source = title.source;
    if (source is! PlutoSource || !_safeId.hasMatch(source.videoId)) {
      throw ArgumentError.value(title.id, 'title', 'no es una película de Pluto TV');
    }
    final session = await _newSession();
    return OnDemandStream(
      url: '${session.stitcherBase}/v2/stitch/hls/episode/${source.videoId}'
          '/master.m3u8?${session.stitcherParams}&jwt=${session.token}',
      headers: session.authHeaders,
    );
  }
}
