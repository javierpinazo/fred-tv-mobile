import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_home.dart';
import 'package:open_tv/screens/tv/tv_links.dart';
import 'package:open_tv/screens/tv/tv_platform.dart';

import 'fakes.dart';

class FakePlatform extends TvPlatform {
  FakePlatform({this.initial});

  final String? initial;
  final StreamController<String> controller = StreamController.broadcast();
  final List<List<TvHomeItem>> published = [];

  @override
  Future<String?> initialLink() async => initial;

  @override
  Stream<String> get links => controller.stream;

  @override
  Future<void> publishFavorites(List<TvHomeItem> items) async =>
      published.add(items);
}

void main() {
  group('enlaces', () {
    test('un enlace de reproducción lleva el nombre y la lista', () {
      final link = tvPlayLink('HBO 2 Latin America HD (1080p)', 'IPTV Español');
      final parsed = parseTvLink(link);
      expect(parsed, isA<TvPlayLink>());
      parsed as TvPlayLink;
      expect(parsed.name, 'HBO 2 Latin America HD (1080p)');
      expect(parsed.source, 'IPTV Español');
    });

    test('ida y vuelta con símbolos que rompen una URL', () {
      final link = tvPlayLink('A&E: ¿Qué? #1 100%', 'Mi lista/ñ');
      final parsed = parseTvLink(link) as TvPlayLink;
      expect(parsed.name, 'A&E: ¿Qué? #1 100%');
      expect(parsed.source, 'Mi lista/ñ');
    });

    test('un enlace de búsqueda', () {
      final parsed = parseTvLink('fredtv://search?q=hbo%202') as TvSearchLink;
      expect(parsed.query, 'hbo 2');
    });

    test('enlaces desconocidos o rotos dan null', () {
      expect(parseTvLink(null), isNull);
      expect(parseTvLink(''), isNull);
      expect(parseTvLink('http://x.test/a'), isNull);
      expect(parseTvLink('fredtv://otra'), isNull);
      expect(parseTvLink('fredtv://play'), isNull); // sin nombre
      expect(parseTvLink('fredtv://search?q='), isNull);
      expect(parseTvLink('::no uri::'), isNull);
    });
  });

  group('elementos de la pantalla de inicio', () {
    test('buildHomeItems arma título, imagen y enlace por favorito', () {
      final a = fakeChannel(1)
        ..image = 'http://x/logo.png'
        ..sourceId = 7;
      final b = fakeChannel(2)..sourceId = 8;
      final items = buildHomeItems([a, b], {7: 'Lista A', 8: 'Lista B'});
      expect(items.map((i) => i.title), ['Canal 1', 'Canal 2']);
      expect(items.first.image, 'http://x/logo.png');
      expect(items.last.image, isNull);
      final link = parseTvLink(items.first.link) as TvPlayLink;
      expect(link.name, 'Canal 1');
      expect(link.source, 'Lista A');
    });

    test('un canal con una fuente desconocida se omite y se limita a 20', () {
      final chs = [
        for (var i = 1; i <= 30; i++) fakeChannel(i)..sourceId = 1,
        fakeChannel(99)..sourceId = 5,
      ];
      final items = buildHomeItems(chs, {1: 'L'});
      expect(items, hasLength(20));
      expect(items.any((i) => i.title == 'Canal 99'), isFalse);
    });
  });

  group('TVHome y los enlaces', () {
    testWidgets('un enlace de reproducción abre ese canal', (t) async {
      final data = FakeTvData(channels: [fakeChannel(1), fakeChannel(2)]);
      final platform = FakePlatform();
      final played = <List<Channel>>[];
      await pumpTv(
        t,
        TVHome(
          data: data,
          platform: platform,
          onPlay: (ctx, list, i) async {
            played.add(list);
            return null;
          },
        ),
      );
      platform.controller.add(tvPlayLink('Canal 2', 'S'));
      await t.pumpAndSettle();
      expect(played.single.single.name, 'Canal 2');
    });

    testWidgets('un enlace inicial (arranque desde la pantalla de inicio)',
        (t) async {
      final data = FakeTvData(channels: [fakeChannel(1)]);
      final platform = FakePlatform(initial: tvPlayLink('Canal 1', 'S'));
      final played = <List<Channel>>[];
      await pumpTv(
        t,
        TVHome(
          data: data,
          platform: platform,
          onPlay: (ctx, list, i) async {
            played.add(list);
            return null;
          },
        ),
      );
      await t.pumpAndSettle();
      expect(played.single.single.name, 'Canal 1');
    });

    testWidgets('un canal que ya no existe avisa en vez de fallar', (t) async {
      final data = FakeTvData(channels: [fakeChannel(1)]);
      final platform = FakePlatform();
      var played = 0;
      await pumpTv(
        t,
        TVHome(
          data: data,
          platform: platform,
          onPlay: (ctx, list, i) async {
            played++;
            return null;
          },
        ),
      );
      platform.controller.add(tvPlayLink('Canal Fantasma', 'S'));
      await t.pumpAndSettle();
      expect(played, 0);
      expect(find.text('Ese canal ya no está disponible'), findsOneWidget);
    });

    testWidgets('un enlace de búsqueda abre Buscar con la consulta', (t) async {
      final data = FakeTvData(channels: [fakeChannel(1), fakeChannel(12)]);
      final platform = FakePlatform();
      await pumpTv(t, TVHome(data: data, platform: platform));
      platform.controller.add('fredtv://search?q=canal%201');
      await t.pumpAndSettle();
      expect(data.channelCalls.last.query, 'canal 1');
      expect(find.text('Canal 1'), findsWidgets);
    });
  });
}
