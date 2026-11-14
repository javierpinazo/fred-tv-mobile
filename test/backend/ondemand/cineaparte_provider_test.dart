import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/backend/ondemand/cineaparte_provider.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';

String html(String title) => '''
aTodoIds.push(1)
aTodoTitulo.push("$title");
aTodoAficheURL.push("https://x/1.jpg");
aTodoSinopsisCortada.push("s");
aTodoTipo.push("t");
aTodoDisponible.push("");
aTodoAccesoVOD.push(1);
aTodoVideoEmbedURL.push("<iframe src='https://player.vimeo.com/video/99?x=1'></iframe>");
''';

void main() {
  test('descarga una vez y reutiliza la caché dentro de 30 min', () async {
    var calls = 0;
    final now = DateTime(2026, 11, 14, 12);
    final p = CineaparteProvider(
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes(utf8.encode(html('A')), 200);
      }),
      now: () => now,
    );
    await p.titles();
    await p.titles();
    expect(calls, 1);
  });

  test('vuelve a descargar pasados 30 min', () async {
    var calls = 0;
    var now = DateTime(2026, 11, 14, 12);
    final p = CineaparteProvider(
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes(utf8.encode(html('A')), 200);
      }),
      now: () => now,
    );
    await p.titles();
    now = now.add(const Duration(minutes: 31));
    await p.titles();
    expect(calls, 2);
  });

  test('decodifica UTF-8 aunque la respuesta no declare charset', () async {
    final p = CineaparteProvider(
      client: MockClient((_) async => http.Response.bytes(
          utf8.encode(html('Tú, ñandú')), 200,
          headers: {'content-type': 'text/html'})),
    );
    expect((await p.titles()).single.title, 'Tú, ñandú');
  });

  test('HTTP 500 → OnDemandUnavailableException y no se cachea', () async {
    var fail = true;
    final p = CineaparteProvider(
      client: MockClient((_) async => fail
          ? http.Response('x', 500)
          : http.Response.bytes(utf8.encode(html('A')), 200)),
    );
    await expectLater(
        p.titles(), throwsA(isA<OnDemandUnavailableException>()));
    fail = false;
    expect(await p.titles(), hasLength(1));
  });

  test('error de red → OnDemandUnavailableException', () async {
    final p = CineaparteProvider(
      client: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await expectLater(
        p.titles(), throwsA(isA<OnDemandUnavailableException>()));
  });

  test('id y nombre', () {
    final p = CineaparteProvider(client: MockClient((_) async => http.Response('', 200)));
    expect(p.id, 'cineaparte');
    expect(p.name, 'Cineaparte');
  });
}
