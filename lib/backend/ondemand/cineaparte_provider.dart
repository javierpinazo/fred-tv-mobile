import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:open_tv/backend/ondemand/cineaparte_page_parser.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

/// Películas gratuitas de Cineaparte (cine peruano y latinoamericano).
/// No hay API: el catálogo viene dentro de la portada, que se descarga y se
/// guarda en memoria [ttl].
class CineaparteProvider implements OnDemandProvider {
  CineaparteProvider({
    http.Client? client,
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 30),
  })  : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  static final _home = Uri.parse('https://www.cineaparte.com/');

  final http.Client _client;
  final DateTime Function() _now;
  final Duration ttl;

  List<OnDemandTitle>? _cache;
  DateTime? _cachedAt;

  @override
  String get id => 'cineaparte';

  @override
  String get name => 'Cineaparte';

  @override
  Future<List<OnDemandTitle>> titles() async {
    final cached = _cache;
    final at = _cachedAt;
    if (cached != null && at != null && _now().difference(at) < ttl) {
      return cached;
    }
    final String body;
    try {
      final res = await _client.get(_home, headers: const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 12; TV) AppleWebKit/537.36',
        'Accept-Language': 'es',
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw OnDemandUnavailableException(
            'Cineaparte respondió ${res.statusCode}.');
      }
      body = utf8.decode(res.bodyBytes, allowMalformed: true);
    } on OnDemandUnavailableException {
      rethrow;
    } on TimeoutException {
      throw OnDemandUnavailableException('Cineaparte tardó demasiado.');
    } on http.ClientException catch (e) {
      throw OnDemandUnavailableException('Sin conexión con Cineaparte: $e');
    }
    final titles = parseCineapartePage(body);
    _cache = titles;
    _cachedAt = _now();
    return titles;
  }
}
