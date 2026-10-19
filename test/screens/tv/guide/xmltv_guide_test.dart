import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';
import 'package:open_tv/screens/tv/guide/xmltv_guide.dart';

// Recorte del XMLTV real de epgshare01 (epg_ripper_PE1).
const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="test">
  <channel id="HBO.2.HD.(HBO.2.HD).pe">
    <display-name>HBO 2 HD (HBO 2 HD)</display-name>
  </channel>
  <channel id="A&amp;E.HD.(A&amp;E.HD).pe">
    <display-name>A&amp;E HD (A&amp;E HD)</display-name>
  </channel>
  <channel id="FOX.SPORTS.(FoxSports).pe">
    <display-name>FOX SPORTS (FoxSports)</display-name>
  </channel>
  <channel id="FOX.SPORTS.2.(FoxSports2).pe">
    <display-name>FOX SPORTS 2 (FoxSports2)</display-name>
  </channel>
  <channel id="ATV.(ATV).pe">
    <display-name>ATV (ATV)</display-name>
  </channel>
  <programme start="20261019010000 +0000" stop="20261019030000 +0000" channel="HBO.2.HD.(HBO.2.HD).pe">
    <title lang="es">Gemelos &amp; más</title>
    <desc lang="es">Dos hombres descubren que son hermanos.</desc>
    <date>1988</date>
  </programme>
  <programme start="20261019030000 +0000" stop="20261019060000 +0000" channel="HBO.2.HD.(HBO.2.HD).pe">
    <title lang="es">Segunda película</title>
  </programme>
  <programme start="20261019140000 +0000" stop="20261019160000 +0000" channel="HBO.2.HD.(HBO.2.HD).pe">
    <title lang="es">Tarde</title>
  </programme>
  <programme start="20261019100000 -0500" stop="20261019110000 -0500" channel="ATV.(ATV).pe">
    <title lang="es">Noticias ATV</title>
  </programme>
</tv>''';

Channel _ch(String name) => Channel(
    name: name, mediaType: MediaType.livestream, sourceId: 1, favorite: false);

void main() {
  group('parseXmltv', () {
    final data = parseXmltv(_xml);

    test('lee los canales con sus nombres (decodificando entidades)', () {
      expect(data.names.keys, hasLength(5));
      expect(data.names['A&E.HD.(A&E.HD).pe'], ['A&E HD (A&E HD)']);
    });

    test('lee los programas con su hora UTC, título y descripción', () {
      final hbo = data.programs['HBO.2.HD.(HBO.2.HD).pe']!;
      expect(hbo.map((p) => p.title),
          ['Gemelos & más', 'Segunda película', 'Tarde']);
      expect(hbo.first.start, DateTime.utc(2026, 10, 19, 1));
      expect(hbo.first.description, 'Dos hombres descubren que son hermanos.');
      expect(hbo[1].description, isNull);
    });

    test('respeta el desfase horario del programa', () {
      final atv = data.programs['ATV.(ATV).pe']!;
      expect(atv.single.start, DateTime.utc(2026, 10, 19, 15)); // 10:00 -0500
    });

    test('guarda el fin de cada programa', () {
      final hbo = data.programs['HBO.2.HD.(HBO.2.HD).pe']!;
      expect(hbo.first.end, DateTime.utc(2026, 10, 19, 3));
    });

    test('un XML vacío o roto no lanza', () {
      expect(parseXmltv('').names, isEmpty);
      expect(parseXmltv('<tv><programme').programs, isEmpty);
    });
  });

  group('normalizeChannelName', () {
    test('quita calidad, tildes y paréntesis', () {
      expect(normalizeChannelName('HBO 2 Latin America HD (1080p)'),
          'hbo 2 latin america');
      expect(normalizeChannelName('Canal Perú [Not 24/7]'), 'canal peru');
    });
  });

  group('XmltvIndex.match', () {
    final data = parseXmltv(_xml);
    final index = XmltvIndex(data.names);

    test('un canal de iptv-org empareja con el XMLTV por sus palabras', () {
      expect(index.match('HBO 2 Latin America HD (1080p)'),
          'HBO.2.HD.(HBO.2.HD).pe');
    });

    test('elige el nombre más específico', () {
      expect(index.match('Fox Sports 2 (720p)'), 'FOX.SPORTS.2.(FoxSports2).pe');
      expect(index.match('Fox Sports (720p)'), 'FOX.SPORTS.(FoxSports).pe');
    });

    test('un nombre de una sola palabra solo empareja si es idéntico', () {
      expect(index.match('ATV (1080p)'), 'ATV.(ATV).pe');
      expect(index.match('ATV Noticias'), isNull);
    });

    test('entidades y símbolos: A&E', () {
      expect(index.match('A&E (720p)'), 'A&E.HD.(A&E.HD).pe');
    });

    test('canales sin equivalente no emparejan', () {
      expect(index.match('Canal Desconocido'), isNull);
      expect(index.match('HBO'), isNull); // una palabra no es HBO 2
    });
  });

  group('XmltvIndex.match: sin falsos positivos', () {
    final index = XmltvIndex({
      'AMERICA.TELEVISION.pe': ['AMERICA TELEVISION (America TV)'],
      'ATV.pe': ['ATV (ATV)'],
      'ATV+.pe': ['ATV+ (ATV+)'],
      'CARTOON.pe': ['CARTOON NETWORK (CartoonNetwork)'],
      'COMEDY.pe': ['COMEDY CENTRAL HD (ComedyCentralHD)'],
      'ORBE.pe': ['ORBE 21 (Orbe21)'],
      'DISNEY.pe': ['DISNEY JUNIOR (DisneyJunior)'],
    });

    test('"TV" suelta de otro canal no lo empareja con América TV', () {
      expect(index.match('Alkarma TV North America & Canada (1080p)'), isNull);
      expect(index.match('Almagd TV North America (1080p)'), isNull);
      expect(index.match('America TV (720p)'), 'AMERICA.TELEVISION.pe');
    });

    test('el "+" distingue ATV+ de ATV', () {
      expect(index.match('ATV+ (1080p)'), 'ATV+.pe');
      expect(index.match('ATV (Peru) (1080p)'), 'ATV.pe');
    });

    test('versiones de otra región (en el nombre o entre paréntesis) no valen',
        () {
      expect(index.match('Cartoon Network (United States) (720p)'), isNull);
      expect(index.match('Cartoon Network Latin America Brazil (720p)'), isNull);
      expect(index.match('Disney Junior (United States) (480p)'), isNull);
      expect(index.match('Comedy Central (United States) CA'), isNull);
    });

    test('la versión latinoamericana sí vale', () {
      expect(index.match('Cartoon Network Latin America'), 'CARTOON.pe');
      expect(index.match('Comedy Central Latin America (1080p)'), 'COMEDY.pe');
    });

    test('palabras de más que no son de relleno descartan el emparejamiento', () {
      expect(index.match('Comedy Central Animation'), isNull);
      expect(index.match('Comedy Central South Park'), isNull);
    });

    test('"Canal" de relleno no impide emparejar', () {
      expect(index.match('Canal Orbe 21'), 'ORBE.pe');
    });
  });

  group('XmltvGuide', () {
    List<int> gz(String s) => gzip.encode(utf8.encode(s));

    XmltvGuide guide(MockClient client) => XmltvGuide(
          urls: () async => ['https://epg.test/pe.xml.gz'],
          client: client,
          parser: (text) async => parseXmltv(text),
        );

    test('descarga (gzip), reconoce el canal y devuelve su día', () async {
      final g = guide(MockClient((_) async => http.Response.bytes(gz(_xml), 200)));
      await g.load();
      final hbo = _ch('HBO 2 Latin America HD (1080p)');
      expect(g.matches(hbo), isTrue);
      expect(g.matches(_ch('Canal Desconocido')), isFalse);
      // 19-oct en Lima = 05:00 UTC del 19 hasta 05:00 UTC del 20.
      final day = await g.day(hbo, DateTime(2026, 10, 19));
      expect(day.map((p) => p.title), ['Segunda película', 'Tarde']);
    });

    test('también acepta XML sin comprimir', () async {
      final g = guide(MockClient((_) async => http.Response.bytes(utf8.encode(_xml), 200)));
      await g.load();
      expect(g.matches(_ch('ATV (1080p)')), isTrue);
    });

    test('antes de cargar nada empareja', () {
      final g = guide(MockClient((_) async => http.Response.bytes(utf8.encode(_xml), 200)));
      expect(g.matches(_ch('ATV (1080p)')), isFalse);
    });

    test('un programa que cruza la medianoche de Lima se incluye al inicio',
        () async {
      final g = guide(MockClient((_) async => http.Response.bytes(utf8.encode(_xml), 200)));
      await g.load();
      final hbo = _ch('HBO 2 Latin America HD (1080p)');
      // El 19 en Lima empieza a las 05:00 UTC: "Segunda película" (03:00-06:00
      // UTC) está en emisión a esa hora, así que abre la lista del día.
      final d19 = await g.day(hbo, DateTime(2026, 10, 19));
      expect(d19.first.title, 'Segunda película');
      // "Gemelos" (01:00-03:00 UTC) ya había terminado: no entra en el 19.
      expect(d19.map((p) => p.title), isNot(contains('Gemelos & más')));
      // El 18 en Lima: de 05:00 UTC del 18 a 05:00 UTC del 19.
      final d18 = await g.day(hbo, DateTime(2026, 10, 18));
      expect(d18.map((p) => p.title), ['Gemelos & más', 'Segunda película']);
    });

    test('un error de descarga se salta sin romper y deja todo sin guía',
        () async {
      final g = guide(MockClient((_) async => http.Response('no', 500)));
      await g.load();
      expect(g.matches(_ch('ATV (1080p)')), isFalse);
    });

    test('day lanza GuideException si el canal no está en la guía', () async {
      final g = guide(MockClient((_) async => http.Response.bytes(utf8.encode(_xml), 200)));
      await g.load();
      expect(g.day(_ch('Canal Desconocido'), DateTime(2026, 10, 19)),
          throwsA(isA<GuideException>()));
    });

    test('load no vuelve a descargar mientras la caché es reciente', () async {
      var calls = 0;
      final g = guide(MockClient((_) async {
        calls++;
        return http.Response.bytes(utf8.encode(_xml), 200);
      }));
      await g.load();
      await g.load();
      expect(calls, 1);
    });
  });
}
