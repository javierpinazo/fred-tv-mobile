import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Tarjeta de canal: logo, nombre (2 líneas) y estrella si es favorito.
class TvChannelCard extends StatelessWidget {
  const TvChannelCard({
    super.key,
    required this.channel,
    required this.focused,
  });

  final Channel channel;
  final bool focused;

  Widget _fallbackIcon() =>
      const Icon(Icons.live_tv, color: TvTheme.textSecondary, size: 40);

  @override
  Widget build(BuildContext context) {
    final image = channel.image;
    return Container(
      decoration: BoxDecoration(
        color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
        borderRadius: BorderRadius.circular(TvTheme.radius - 2),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Center(
                    child: image != null && image.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => _fallbackIcon(),
                            errorWidget: (_, __, ___) => _fallbackIcon(),
                          )
                        : _fallbackIcon(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  channel.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: TvTheme.fontSmall,
                    color: TvTheme.textPrimary,
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
