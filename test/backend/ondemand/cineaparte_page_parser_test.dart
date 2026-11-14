import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/ondemand/cineaparte_page_parser.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

String iframe(String src) =>
    "<div style='width:100%'><iframe class='vidembclass' id='videmb-1' "
    "src='$src' frameborder='0' allowfullscreen></iframe></div>";

/// Arma una portada como la real: una línea `aTodoX.push(...)` por dato,
/// algunas sin `;` final.
String page(List<Map<String, Object>> rows) {
  final b = StringBuffer('<html><script>\n');
  for (final r in rows) {
    b.writeln('aTodoIds.push(${r['id'] ?? 1})');
    b.writeln('aTodoTitulo.push("${r['title'] ?? 'Peli'}");');
    b.writeln('aTodoURL.push("/p/1/peli")');
    b.writeln('aTodoAficheURL.push("https://x/${r['id'] ?? 1}.jpg");');
    b.writeln('aTodoSinopsisCortada.push("${r['syn'] ?? 'Sinopsis'}");');
    b.writeln('aTodoTipo.push("Largometraje, 2018, 77 min.");');
    b.writeln('aTodoDisponible.push("${r['disp'] ?? ''}");');
    b.writeln('aTodoAccesoVOD.push(${r['vod'] ?? 1});');
    b.writeln('aTodoVideoEmbedURL.push("${(r['embed'] as String? ?? '').replaceAll('"', r'\"')}");');
  }
  b.writeln('</script></html>');
  return b.toString();
}

String vimeo(String id) =>
    iframe('https://player.vimeo.com/video/$id?color=ee8822&title=0');

void main() {
  test('vimeo gratis → VimeoSource', () {
    final t = parseCineapartePage(page([
      {'id': 7, 'embed': vimeo('1229366069')},
    ]));
    expect(t, hasLength(1));
    expect(t.single.id, '7');
    expect((t.single.source as VimeoSource).videoId, '1229366069');
    expect(t.single.details, 'Largometraje, 2018, 77 min.');
    expect(t.single.posterUrl, 'https://x/7.jpg');
  });

  test('youtube gratis → YoutubeSource (www y sin www)', () {
    final t = parseCineapartePage(page([
      {'embed': iframe('https://www.youtube.com/embed/B4yhLGy9-z8?rel=0')},
      {'embed': iframe('https://youtube.com/embed/5-Vfhvz5OqY')},
    ]));
    expect(t.map((e) => (e.source as YoutubeSource).videoId),
        ['B4yhLGy9-z8', '5-Vfhvz5OqY']);
  });

  test('ignora /d/embed/, AccesoVOD 0 y embed vacío', () {
    final t = parseCineapartePage(page([
      {'embed': iframe('https://www.cineaparte.com/d/embed/4523/598226847')},
      {'vod': 0, 'embed': vimeo('1')},
      {'embed': ''},
      {'embed': vimeo('2')},
    ]));
    expect(t, hasLength(1));
    expect((t.single.source as VimeoSource).videoId, '2');
  });

  test('territorio: excluye «excepto PE», admite vacío y «Disponible en PE»', () {
    final t = parseCineapartePage(page([
      {'id': 1, 'disp': 'Disponible en todo el mundo excepto PE', 'embed': vimeo('1')},
      {'id': 2, 'disp': '', 'embed': vimeo('2')},
      {'id': 3, 'disp': 'Disponible en PE', 'embed': vimeo('3')},
      {'id': 4, 'disp': 'Disponible en todo el mundo excepto ES', 'embed': vimeo('4')},
    ]));
    expect(t.map((e) => e.id), ['2', '3', '4']);
  });

  test('decodifica escapes JS y tildes', () {
    final t = parseCineapartePage(page([
      {
        'title': r'''Vuelve \"Ña\" ''' r'\u' r'''00f1 \/ it\'s''',
        'embed': vimeo('1'),
      },
    ]));
    expect(t.single.title, 'Vuelve "Ña" ñ / it\'s');
  });

  test('matrices de distinto largo: usa el menor, sin lanzar', () {
    final html = '${page([
      {'embed': vimeo('1')},
      {'embed': vimeo('2')},
    ])}\naTodoSlug.push("x")\n';
    final extra = '$html\naTodoTitulo.push("sobra");';
    expect(() => parseCineapartePage(extra), returnsNormally);
    expect(parseCineapartePage(extra), hasLength(2));
  });

  test('sin matrices aTodo* → OnDemandUnavailableException', () {
    expect(() => parseCineapartePage('<html>nada</html>'),
        throwsA(isA<OnDemandUnavailableException>()));
  });
}
