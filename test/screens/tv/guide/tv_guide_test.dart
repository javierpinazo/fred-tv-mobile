import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';

// Filas reales de https://www.tvperu.gob.pe/programacion?fecha=19-10-2026
const _html = '''
<div id="table-programacion" class="table-responsive programacion"><table class="table table-striped"><tbody><tr ><td class='text-center'><h3>12:00 AM.</h3></td><td><div class='icono-play'><a >
              <img typeof='foaf:Image' src='https://tvperu.gob.pe/sites/default/files/app2-teatro-en-grande.jpg'>
            </a></div></td><td><h3><a href='https://www.tvperu.gob.pe/programas/teatro-en-grande'>Teatro en grande</a></h3><div><p>El Gran Teatro Nacional levantan el telón para recibir a los mejores exponentes artísticos &amp; más.</br><a href='/play' class='play_TV'><i class='fa fa-play-circle' aria-hidden='true'></i>Disponible en TVPerú Play</a></div><tr ><td class='text-center'><h3>02:00 PM.</h3></td><td><div class='icono-play'><a >
              <img src='x.jpg'>
            </a></div></td><td><h3><a href='https://tvperu.gob.pe/programas/con-sabor-a-peru'>Con sabor a Perú</a></h3><div><p>El chef Israel Laura nos lleva &quot;de paseo&quot;.</br><a href='/play' class='play_TV'>Disponible</a></div><tr ><td class='text-center'><h3>12:00 PM.</h3></td><td><div class='icono-play'><a >
              <img src='y.jpg'>
            </a></div></td><td><h3><a href='https://tvperu.gob.pe/programas/x'>Mediodía</a></h3><div><p>Programa de mediodía.</br></div><tr ><td class='text-center'><h3>11:00 PM.</h3></td><td><div class='icono-play'><a >
              <img src='z.jpg'>
            </a></div></td><td><h3><a>Abramos el corazón</a></h3></tbody></table></div>
''';

Channel _ch(String name) => Channel(
    name: name, mediaType: MediaType.livestream, sourceId: 1, favorite: true);

void main() {
  final day = DateTime(2026, 10, 19);

  group('parseTvPeruDay', () {
    final programs = parseTvPeruDay(_html, day);

    test('lee todas las filas en orden cronológico', () {
      expect(programs.map((p) => p.title).toList(), [
        'Teatro en grande',
        'Mediodía',
        'Con sabor a Perú',
        'Abramos el corazón',
      ]);
    });

    test('las horas se interpretan en hora de Lima (UTC-5)', () {
      expect(programs[0].start, DateTime.utc(2026, 10, 19, 5, 0)); // 12:00 AM
      expect(programs[1].start, DateTime.utc(2026, 10, 19, 17, 0)); // 12:00 PM
      expect(programs[2].start, DateTime.utc(2026, 10, 19, 19, 0)); // 02:00 PM
      expect(programs[3].start, DateTime.utc(2026, 10, 20, 4, 0)); // 11:00 PM
    });

    test('descripción: sin etiquetas, con entidades y sin el enlace de Play',
        () {
      expect(programs[0].description,
          'El Gran Teatro Nacional levantan el telón para recibir a los '
          'mejores exponentes artísticos & más.');
      expect(programs[2].description,
          'El chef Israel Laura nos lleva "de paseo".');
    });

    test('una fila sin descripción da null y el título sin enlace funciona',
        () {
      expect(programs[3].description, isNull);
      expect(programs[3].title, 'Abramos el corazón');
    });

    test('etiqueta de hora en Lima', () {
      expect(programs[0].timeLabel, '12:00 AM');
      expect(programs[2].timeLabel, '02:00 PM');
      expect(programs[3].timeLabel, '11:00 PM');
    });

    test('una página sin tabla devuelve lista vacía', () {
      expect(parseTvPeruDay('<html>nada</html>', day), isEmpty);
    });
  });

  group('guideNowNext', () {
    final programs = parseTvPeruDay(_html, day);

    test('a las 14:30 de Lima emite "Con sabor a Perú"', () {
      final r = guideNowNext(programs, DateTime.utc(2026, 10, 19, 19, 30));
      expect(r.now!.title, 'Con sabor a Perú');
      expect(r.next!.title, 'Abramos el corazón');
    });

    test('antes del primer programa no hay "ahora" y el siguiente es el primero',
        () {
      final r = guideNowNext(programs, DateTime.utc(2026, 10, 19, 4, 0));
      expect(r.now, isNull);
      expect(r.next!.title, 'Teatro en grande');
    });

    test('después del último programa no hay siguiente', () {
      final r = guideNowNext(programs, DateTime.utc(2026, 10, 20, 4, 30));
      expect(r.now!.title, 'Abramos el corazón');
      expect(r.next, isNull);
    });

    test('lista vacía no rompe', () {
      final r = guideNowNext(const [], DateTime.utc(2026, 10, 19));
      expect(r.now, isNull);
      expect(r.next, isNull);
    });
  });

  group('TvPeruGuide.matches', () {
    final guide = TvPeruGuide();

    test('reconoce TV Perú con y sin tilde y con sufijos de calidad', () {
      expect(guide.matches(_ch('TV Peru (1080p)')), isTrue);
      expect(guide.matches(_ch('TV Perú')), isTrue);
      expect(guide.matches(_ch('TVPerú HD [Not 24/7]')), isTrue);
    });

    test('no confunde con otros canales parecidos', () {
      expect(guide.matches(_ch('TV Peru Noticias (1080p)')), isFalse);
      expect(guide.matches(_ch('Nacional Tv Peru (720p)')), isFalse);
      expect(guide.matches(_ch('TV Peruanisima (720p)')), isFalse);
      expect(guide.matches(_ch('HBO 2')), isFalse);
    });
  });

  group('TvPeruGuide.day', () {
    test('pide la fecha con el formato del sitio y un User-Agent de navegador',
        () async {
      Uri? url;
      String? ua;
      final client = MockClient((req) async {
        url = req.url;
        ua = req.headers['User-Agent'];
        return http.Response(_html, 200,
            headers: {'content-type': 'text/html; charset=utf-8'});
      });
      final guide = TvPeruGuide(client: client);
      final programs = await guide.day(day);
      expect(programs, hasLength(4));
      expect(url.toString(),
          'https://www.tvperu.gob.pe/programacion?fecha=19-10-2026');
      expect(ua, startsWith('Mozilla/5.0'));
    });

    test('guarda el día en caché', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(_html, 200);
      });
      final guide = TvPeruGuide(client: client);
      await guide.day(day);
      await guide.day(day);
      expect(calls, 1);
      await guide.day(DateTime(2026, 10, 20));
      expect(calls, 2);
    });

    test('un error HTTP lanza excepción y no se cachea', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return calls == 1 ? http.Response('no', 403) : http.Response(_html, 200);
      });
      final guide = TvPeruGuide(client: client);
      await expectLater(guide.day(day), throwsA(isA<GuideException>()));
      expect(await guide.day(day), hasLength(4));
    });
  });

  group('TvGuide', () {
    test('providerFor devuelve el proveedor que reconoce el canal', () {
      final guide = TvGuide(providers: [TvPeruGuide()]);
      expect(guide.providerFor(_ch('TV Peru (1080p)')), isNotNull);
      expect(guide.providerFor(_ch('HBO 2')), isNull);
    });

    test('limaDay usa la fecha de Lima, no la UTC', () {
      // 03:00 UTC del 20 es todavía el 19 en Lima.
      expect(limaDay(DateTime.utc(2026, 10, 20, 3)), DateTime(2026, 10, 19));
      expect(limaDay(DateTime.utc(2026, 10, 20, 6)), DateTime(2026, 10, 20));
    });
  });
}
