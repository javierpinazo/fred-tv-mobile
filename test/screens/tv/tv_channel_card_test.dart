import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/widgets/tv_channel_card.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

import 'fakes.dart';

Widget card({
  String name = 'Canal',
  String? image,
  bool focused = false,
}) =>
    Center(
      child: SizedBox(
        width: 200,
        height: 150,
        child: TvChannelCard(
          channel: Channel(
            name: name,
            image: image,
            url: 'http://test/a.m3u8',
            mediaType: MediaType.livestream,
            sourceId: 1,
            favorite: false,
          ),
          focused: focused,
        ),
      ),
    );

void main() {
  testWidgets('el logo se decodifica al ancho de la tarjeta', (t) async {
    await pumpTv(t, card(image: 'https://x.test/logo.png'));
    final img = t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(img.memCacheWidth, (TvTheme.tileMaxExtent * 2).round()); // dpr 2
    expect(img.fadeInDuration, Duration.zero);
    expect(img.fadeOutDuration, Duration.zero);
  });

  testWidgets('la tarjeta muestra el nombre limpio y la calidad aparte',
      (t) async {
    await pumpTv(t, card(name: 'ADN TV (720p) [Not 24/7]', image: ''));
    expect(find.text('ADN TV'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);
  });

  testWidgets('el nombre resalta con foco', (t) async {
    await pumpTv(t, card(name: 'ADN TV', image: '', focused: true));
    expect(t.widget<Text>(find.text('ADN TV')).style!.color,
        TvTheme.textPrimary);
    await pumpTv(t, card(name: 'ADN TV', image: '', focused: false));
    expect(t.widget<Text>(find.text('ADN TV')).style!.color,
        TvTheme.textSecondary);
  });

  testWidgets('a tamaño de TV el icono de respaldo no pisa un nombre de 2 líneas',
      (t) async {
    await pumpTv(
      t,
      Center(
        child: SizedBox(
          width: 112,
          height: 84,
          child: TvChannelCard(
            channel: Channel(
              name: 'Carlos León Moya',
              image: '',
              url: 'http://test/a.m3u8',
              mediaType: MediaType.livestream,
              sourceId: 1,
              favorite: false,
            ),
            focused: false,
          ),
        ),
      ),
    );
    final icon = t.getRect(find.byIcon(Icons.live_tv));
    final name = t.getRect(find.text('Carlos León Moya'));
    // El icono debe encogerse (cuadrado) y caber encima del nombre; si solo se
    // recorta su caja, el glifo se dibuja a 40 px y pisa el texto.
    expect((icon.width - icon.height).abs(), lessThan(0.5));
    expect(icon.bottom, lessThanOrEqualTo(name.top + 0.5));
  });

  testWidgets('sin logo muestra el icono de respaldo', (t) async {
    await pumpTv(t, card(image: ''));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.live_tv), findsOneWidget);
  });
}
