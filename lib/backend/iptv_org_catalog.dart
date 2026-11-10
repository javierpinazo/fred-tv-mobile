import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:open_tv/backend/m3u.dart' show HttpStatusException;
import 'package:open_tv/backend/pluto_tv.dart';

/// [pluto] no es de iptv-org: es el catálogo completo de Pluto TV, que se
/// ofrece junto a los recomendados.
enum IptvOrgKind { country, language, category, pluto }

const String _playlistBase = 'https://iptv-org.github.io/iptv';
const String _apiBase = 'https://iptv-org.github.io/api';

class IptvOrgPlaylist {
  const IptvOrgPlaylist({
    required this.kind,
    required this.code,
    required this.name,
    this.flag,
  });

  final IptvOrgKind kind;
  final String code;
  final String name;
  final String? flag;

  String get url {
    switch (kind) {
      case IptvOrgKind.country:
        return '$_playlistBase/countries/${code.toLowerCase()}.m3u';
      case IptvOrgKind.language:
        return '$_playlistBase/languages/$code.m3u';
      case IptvOrgKind.category:
        return '$_playlistBase/categories/$code.m3u';
      case IptvOrgKind.pluto:
        return plutoTvChannelsUrl;
    }
  }

  String get sourceName =>
      kind == IptvOrgKind.pluto ? name : 'iptv-org · $name';
}

List<IptvOrgPlaylist> parseIptvOrgCountries(String json) {
  final list = (jsonDecode(json) as List)
      .whereType<Map<String, dynamic>>()
      .where((m) => m['code'] is String && m['name'] is String)
      .map((m) => IptvOrgPlaylist(
            kind: IptvOrgKind.country,
            code: m['code'] as String,
            name: m['name'] as String,
            flag: m['flag'] as String?,
          ))
      .toList();
  list.sort((a, b) => a.name.compareTo(b.name));
  return list;
}

List<IptvOrgPlaylist> parseIptvOrgCategories(String json) {
  final list = (jsonDecode(json) as List)
      .whereType<Map<String, dynamic>>()
      .where((m) =>
          m['id'] is String && m['name'] is String && m['id'] != 'xxx')
      .map((m) => IptvOrgPlaylist(
            kind: IptvOrgKind.category,
            code: m['id'] as String,
            name: m['name'] as String,
          ))
      .toList();
  list.sort((a, b) => a.name.compareTo(b.name));
  return list;
}

/// Catálogo de listas automáticas de iptv-org.
class IptvOrgCatalog {
  IptvOrgCatalog({http.Client? client}) : _client = client;

  final http.Client? _client;
  List<IptvOrgPlaylist>? _countries;
  List<IptvOrgPlaylist>? _categories;

  static const List<IptvOrgPlaylist> recommended = [
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'pe', name: 'Perú', flag: '🇵🇪'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'mx', name: 'México', flag: '🇲🇽'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'ar', name: 'Argentina', flag: '🇦🇷'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'co', name: 'Colombia', flag: '🇨🇴'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'cl', name: 'Chile', flag: '🇨🇱'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'es', name: 'España', flag: '🇪🇸'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 've', name: 'Venezuela', flag: '🇻🇪'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'ec', name: 'Ecuador', flag: '🇪🇨'),
    IptvOrgPlaylist(kind: IptvOrgKind.country, code: 'us', name: 'Estados Unidos', flag: '🇺🇸'),
    IptvOrgPlaylist(kind: IptvOrgKind.language, code: 'spa', name: 'Todo en español'),
    IptvOrgPlaylist(kind: IptvOrgKind.pluto, code: 'latam', name: plutoTvSourceName),
    IptvOrgPlaylist(kind: IptvOrgKind.category, code: 'news', name: 'Noticias'),
    IptvOrgPlaylist(kind: IptvOrgKind.category, code: 'sports', name: 'Deportes'),
    IptvOrgPlaylist(kind: IptvOrgKind.category, code: 'kids', name: 'Infantil'),
    IptvOrgPlaylist(kind: IptvOrgKind.category, code: 'movies', name: 'Películas'),
    IptvOrgPlaylist(kind: IptvOrgKind.category, code: 'music', name: 'Música'),
    IptvOrgPlaylist(kind: IptvOrgKind.category, code: 'documentary', name: 'Documentales'),
  ];

  Future<String> _get(String url) async {
    final client = _client ?? http.Client();
    try {
      final response =
          await client.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw HttpStatusException(response.statusCode);
      }
      return utf8.decode(response.bodyBytes);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<List<IptvOrgPlaylist>> countries() async =>
      _countries ??= parseIptvOrgCountries(await _get('$_apiBase/countries.json'));

  Future<List<IptvOrgPlaylist>> categories() async => _categories ??=
      parseIptvOrgCategories(await _get('$_apiBase/categories.json'));
}
