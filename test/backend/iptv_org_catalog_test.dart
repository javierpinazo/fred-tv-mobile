import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/iptv_org_catalog.dart';

void main() {
  test('parsea países y arma la URL', () {
    final l = parseIptvOrgCountries(
        '[{"name":"Peru","code":"PE","languages":["spa"],"flag":"🇵🇪"},'
        '{"name":"Chile","code":"CL","languages":[],"flag":"🇨🇱"},'
        '{"name":"Sin código","languages":[]}]');
    expect(l.map((p) => p.code), ['CL', 'PE']);
    expect(l[1].kind, IptvOrgKind.country);
    expect(l[1].flag, '🇵🇪');
    expect(l[1].url, 'https://iptv-org.github.io/iptv/countries/pe.m3u');
    expect(l[1].sourceName, 'iptv-org · Peru');
  });

  test('categorías sin xxx y con su URL', () {
    final l = parseIptvOrgCategories(
        '[{"id":"news","name":"News"},{"id":"xxx","name":"XXX"},{"id":"auto","name":"Auto"}]');
    expect(l.map((p) => p.code), ['auto', 'news']);
    expect(l.last.url, 'https://iptv-org.github.io/iptv/categories/news.m3u');
    expect(l.last.kind, IptvOrgKind.category);
  });

  test('recomendado de idioma usa /languages/', () {
    final lang = IptvOrgCatalog.recommended
        .firstWhere((p) => p.kind == IptvOrgKind.language);
    expect(lang.url, 'https://iptv-org.github.io/iptv/languages/spa.m3u');
    expect(lang.name, 'Todo en español');
  });

  test('recomendados: orden exacto', () {
    expect(
      IptvOrgCatalog.recommended.map((p) => '${p.kind.name}:${p.code}').toList(),
      [
        'country:pe', 'country:mx', 'country:ar', 'country:co', 'country:cl',
        'country:es', 'country:ve', 'country:ec', 'country:us',
        'language:spa',
        'category:news', 'category:sports', 'category:kids',
        'category:movies', 'category:music', 'category:documentary',
      ],
    );
    expect(IptvOrgCatalog.recommended.first.name, 'Perú');
    expect(IptvOrgCatalog.recommended.first.url,
        'https://iptv-org.github.io/iptv/countries/pe.m3u');
  });

  test('countries() cachea tras el primer éxito', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.toString(), 'https://iptv-org.github.io/api/countries.json');
      return http.Response('[{"name":"Peru","code":"PE"}]', 200);
    });
    final catalog = IptvOrgCatalog(client: client);
    expect((await catalog.countries()).single.code, 'PE');
    expect((await catalog.countries()).single.code, 'PE');
    expect(calls, 1);
  });

  test('categories() lanza si la API responde con error', () async {
    final catalog =
        IptvOrgCatalog(client: MockClient((_) async => http.Response('x', 500)));
    expect(catalog.categories(), throwsA(isA<Exception>()));
  });

  test('un error no se cachea: el siguiente intento vuelve a la red', () async {
    var calls = 0;
    final catalog = IptvOrgCatalog(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('x', 500)
            : http.Response('[{"id":"news","name":"News"}]', 200);
      }),
    );
    await expectLater(catalog.categories(), throwsA(isA<Exception>()));
    expect((await catalog.categories()).single.code, 'news');
  });
}
