import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/ondemand/tv_vod_player.dart';
import 'package:open_tv/screens/tv/ondemand/vimeo_player_page.dart';
import 'package:open_tv/screens/tv/widgets/tv_button.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_player.dart';

/// Reproductor que corresponde al origen de la película: Vimeo o YouTube.
Widget onDemandPlayerFor(OnDemandTitle title) {
  switch (title.source) {
    case PlutoSource() || ArchiveSource() || PlexSource():
      // Estos servicios resuelven la URL antes de abrir el reproductor de
      // películas (ver `playOnDemandTitle`).
      throw UnsupportedError('Este servicio se reproduce resolviendo su URL.');
    case VimeoSource(:final videoId):
      return TvVimeoPlayer(videoId: videoId, title: title.title);
    case YoutubeSource(:final videoId):
      // El reproductor de YouTube pide un canal y un programa: se le da un
      // canal genérico que solo existe para esto (Cineaparte, YouTube…).
      return TvYoutubePlayer(
        channel: Channel(
          name: 'On demand',
          url: 'https://www.youtube.com/',
          mediaType: MediaType.movie,
          sourceId: -1,
          favorite: false,
        ),
        program: YoutubeProgram(
          videoId: videoId,
          title: title.title,
          kind: YoutubeProgramKind.video,
        ),
      );
  }
}

/// Reproductor de vídeo directo: recibe el vídeo ya resuelto y el título.
typedef VodPlayerBuilder = Widget Function(OnDemandStream stream, String title);

Widget _defaultVodPlayer(OnDemandStream stream, String title) =>
    TvVodPlayer(stream: stream, title: title);

/// Abre el reproductor de [title] a pantalla completa; termina al cerrarlo.
///
/// Vimeo y YouTube abren su página; Pluto primero resuelve la URL con
/// [provider] (muestra «Preparando…», y si falla ofrece reintentar) y abre el
/// reproductor de vídeo directo. [playerBuilder] es solo para pruebas.
Future<void> playOnDemandTitle(
  BuildContext context,
  OnDemandProvider provider,
  OnDemandTitle title, {
  VodPlayerBuilder playerBuilder = _defaultVodPlayer,
}) async {
  final navigator = Navigator.of(context);
  if (title.source is VimeoSource || title.source is YoutubeSource) {
    await navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => onDemandPlayerFor(title)),
    );
    return;
  }
  if (provider is! OnDemandResolver) {
    throw UnsupportedError('${provider.name} no sabe resolver sus películas.');
  }
  final resolver = provider as OnDemandResolver;
  final stream = await _resolveWithDialog(navigator, resolver, title);
  if (stream == null || !navigator.mounted) return;
  await navigator.push<void>(MaterialPageRoute<void>(
      builder: (_) => playerBuilder(stream, title.title)));
}

/// Resuelve el vídeo mostrando «Preparando…». `null` si falla y el usuario
/// elige «Volver».
Future<OnDemandStream?> _resolveWithDialog(
    NavigatorState navigator, OnDemandResolver resolver, OnDemandTitle title) async {
  final nav = Navigator.of(navigator.context, rootNavigator: true);
  while (true) {
    unawaited(showDialog<void>(
      // ignore: use_build_context_synchronously
      context: nav.context, // `nav.mounted` se comprueba antes de repetir
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: _PreparingDialog()),
    ));
    try {
      final stream = await resolver.resolve(title);
      if (nav.mounted) nav.pop(); // «Preparando…»
      return stream;
    } catch (e) {
      // Cualquier fallo (red, TLS, id raro…) vuelve al usuario al aviso: un
      // diálogo «Preparando…» sin salida obligaría a matar la app.
      debugPrint('playOnDemandTitle: $e');
      if (!nav.mounted) return null;
      nav.pop(); // «Preparando…»
      final retry = await showDialog<bool>(
        // ignore: use_build_context_synchronously
        context: nav.context, // se comprobó `nav.mounted` justo antes
        builder: (_) => const _ResolveErrorDialog(),
      );
      if (retry == true && nav.mounted) continue;
      return null;
    }
  }
}

class _PreparingDialog extends StatelessWidget {
  const _PreparingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TvTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(context.l10n.onDemandResolving,
                style: const TextStyle(
                    fontSize: TvTheme.fontBody, color: TvTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ResolveErrorDialog extends StatelessWidget {
  const _ResolveErrorDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: TvTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.onDemandLoadError,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: TvTheme.fontBody, color: TvTheme.textPrimary)),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvButton(
                    label: l10n.commonRetry,
                    primary: true,
                    autofocus: true,
                    onSelect: () => Navigator.of(context).pop(true)),
                const SizedBox(width: 20),
                TvButton(
                    label: l10n.ytBack,
                    onSelect: () => Navigator.of(context).pop(false)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
