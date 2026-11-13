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

  testWidgets('sin logo muestra el icono de respaldo', (t) async {
    await pumpTv(t, card(image: ''));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.live_tv), findsOneWidget);
  });
}
