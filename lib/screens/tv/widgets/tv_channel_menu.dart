import 'package:flutter/material.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';

/// Menú de OK largo sobre un canal.
Future<void> showTvChannelMenu(
  BuildContext context, {
  required Channel channel,
  required VoidCallback onPlay,
  required VoidCallback onToggleFavorite,
  VoidCallback? onAddToPlaylist,
}) async {
  final choice = await showTvOptions<int>(
    context,
    title: channel.name,
    options: [
      ('Reproducir', 0),
      (channel.favorite ? 'Quitar de favoritos' : 'Agregar a favoritos', 1),
      if (onAddToPlaylist != null) ('Agregar a una lista…', 2),
    ],
  );
  switch (choice) {
    case 0:
      onPlay();
    case 1:
      onToggleFavorite();
    case 2:
      onAddToPlaylist?.call();
  }
}
