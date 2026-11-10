import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/iptv_org_catalog.dart';
import 'package:open_tv/backend/m3u.dart';
import 'package:open_tv/backend/pluto_tv.dart';

const _json = '''
[
 {"_id":"bbb","name":"Pokémon","number":1262,"category":"Anime","isStitched":true,
  "colorLogoPNG":{"path":"https://images.pluto.tv/bbb/logo.png"}},
 {"_id":"dup","name":"Pluto Tv Cine Estelar","number":0,"category":"Películas"},
 {"_id":"aaa","name":"Pluto TV \\"Cine\\", Estelar","number":18,"category":"Películas",
  "logo":{"path":"https://images.pluto.tv/aaa/logo.png"}},
 {"_id":"ccc","name":"Sin categoría","number":2000},
 {"_id":"off","name":"No emitido","number":5,"isStitched":false},
 {"name":"Sin id","number":7}
]''';

void main() {
  test('reconoce la URL de la API de Pluto TV', () {
    expect(isPlutoTvChannelsUrl(plutoTvChannelsUrl), isTrue);
    expect(isPlutoTvChannelsUrl('https://API.pluto.tv/v2/channels/?a=1'), isTrue);
    expect(isPlutoTvChannelsUrl('https://iptv-org.github.io/iptv/languages/spa.m3u'),
        isFalse);
    expect(isPlutoTvChannelsUrl('https://pluto.tv/latam/'), isFalse);
  });

  test('convierte los canales a M3U ordenados por número', () {
    final lines = plutoTvChannelsToM3u(_json).trim().split('\n');
    expect(lines.first, '#EXTM3U');
    expect(lines.length, 7); // cabecera + 3 canales válidos
    expect(lines[2], 'https://jmp2.uk/plu-aaa.m3u8');
    expect(lines[4], 'https://jmp2.uk/plu-bbb.m3u8');
    expect(lines[6], 'https://jmp2.uk/plu-ccc.m3u8');

    final estelar = getChannelFromLines(lines[1], lines[2])!;
    expect(estelar.name, "Pluto TV 'Cine', Estelar");
    expect(estelar.group, 'Películas');
    expect(estelar.image, 'https://images.pluto.tv/aaa/logo.png');

    final pokemon = getChannelFromLines(lines[3], lines[4])!;
    expect(pokemon.name, 'Pokémon');
    expect(pokemon.group, 'Anime');
    expect(pokemon.image, 'https://images.pluto.tv/bbb/logo.png');

    expect(getChannelFromLines(lines[5], lines[6])!.group, 'Pluto TV');
  });

  test('falla si la respuesta no trae canales', () {
    expect(() => plutoTvChannelsToM3u('[]'), throwsFormatException);
    expect(() => plutoTvChannelsToM3u('{"error":1}'), throwsFormatException);
  });

  test('el catálogo ofrece Pluto TV Latinoamérica', () {
    final pluto = IptvOrgCatalog.recommended
        .firstWhere((p) => p.kind == IptvOrgKind.pluto);
    expect(pluto.url, plutoTvChannelsUrl);
    expect(pluto.sourceName, 'Pluto TV Latinoamérica');
  });
}
