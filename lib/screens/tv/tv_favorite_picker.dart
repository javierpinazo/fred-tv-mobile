import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/tv_channel_browser.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Pantalla para elegir un canal entre los favoritos; devuelve el elegido o
/// `null` si se sale con Atrás.
Future<Channel?> pickFavoriteChannel(BuildContext context, TvData data) {
  return Navigator.of(context).push<Channel>(
    MaterialPageRoute<Channel>(
      builder: (_) => Scaffold(
        backgroundColor: TvTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.playerPickFavorite,
                    style: const TextStyle(
                      fontSize: TvTheme.fontTitle,
                      fontWeight: FontWeight.bold,
                      color: TvTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TVChannelBrowser(
                  favoritesOnly: true,
                  autofocusFirst: true,
                  data: data,
                  // Elegir un canal cierra la pantalla en vez de reproducirlo.
                  onPlay: (ctx, playlist, index) async {
                    Navigator.of(ctx).pop(playlist[index]);
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
