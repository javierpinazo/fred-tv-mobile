import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';

/// Menú de OK largo sobre un canal.
Future<void> showTvChannelMenu(
  BuildContext context, {
  required Channel channel,
  required VoidCallback onPlay,
  required VoidCallback onToggleFavorite,
  VoidCallback? onAddToPlaylist,
  VoidCallback? onShowGuide,
  VoidCallback? onToggleDead,
}) async {
  final l10n = context.l10n;
  final choice = await showTvOptions<int>(
    context,
    title: channel.name,
    options: [
      (l10n.commonPlay, 0),
      (channel.favorite ? l10n.menuFavoriteRemove : l10n.menuFavoriteAdd, 1),
      if (onAddToPlaylist != null) (l10n.menuAddToList, 2),
      if (onShowGuide != null) (l10n.menuShowGuide, 3),
      if (onToggleDead != null)
        (channel.dead ? l10n.menuDeadClear : l10n.menuDeadMark, 4),
    ],
  );
  switch (choice) {
    case 0:
      onPlay();
    case 1:
      onToggleFavorite();
    case 2:
      onAddToPlaylist?.call();
    case 3:
      onShowGuide?.call();
    case 4:
      onToggleDead?.call();
  }
}
