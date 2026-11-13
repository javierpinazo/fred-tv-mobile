import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_channel_label.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Tarjeta de canal: logo sobre una placa, nombre limpio (2 líneas), calidad
/// en una píldora y estrella si es favorito.
class TvChannelCard extends StatelessWidget {
  const TvChannelCard({
    super.key,
    required this.channel,
    required this.focused,
  });

  final Channel channel;
  final bool focused;

  Widget _fallbackIcon() =>
      Icon(Icons.live_tv, color: TvTheme.textSecondary, size: 40);

  Widget _logo(BuildContext context, String image) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: TvTheme.logoPlate,
        borderRadius: BorderRadius.circular(6),
      ),
      child: CachedNetworkImage(
        imageUrl: image,
        fit: BoxFit.contain,
        // Se decodifica al tamaño de la tarjeta, no al del archivo (un logo
        // grande ocupa varios MB).
        memCacheWidth:
            (TvTheme.tileMaxExtent * MediaQuery.devicePixelRatioOf(context))
                .round(),
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => _fallbackIcon(),
        errorWidget: (_, __, ___) => _fallbackIcon(),
      ),
    );
  }

  Widget _qualityPill(String quality) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          quality,
          style: TextStyle(fontSize: 12, color: TvTheme.textSecondary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final image = channel.image;
    final label = tvChannelLabel(channel.name);
    return Container(
      decoration: BoxDecoration(
        color: focused ? TvTheme.surfaceFocused : TvTheme.surface,
        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
      ),
      child: Stack(
        children: [
          if (channel.dead)
            const Positioned(
              left: 8,
              top: 8,
              child: Icon(Icons.link_off, color: TvTheme.error, size: 22),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Stack(
                    children: [
                      Center(
                        child: image != null && image.isNotEmpty
                            ? _logo(context, image)
                            : _fallbackIcon(),
                      ),
                      if (label.quality != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: _qualityPill(label.quality!),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  label.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TvTheme.fontSmall,
                    color:
                        focused ? TvTheme.textPrimary : TvTheme.textSecondary,
                    fontWeight: focused ? FontWeight.w600 : FontWeight.normal,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          if (channel.favorite)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.star, color: TvTheme.favorite, size: 22),
            ),
        ],
      ),
    );
  }
}
