import 'package:flutter/material.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/ondemand/vimeo_player_page.dart';
import 'package:open_tv/screens/tv/youtube/tv_youtube_player.dart';

/// Reproductor que corresponde al origen de la película: Vimeo o YouTube.
Widget onDemandPlayerFor(OnDemandTitle title) {
  switch (title.source) {
    case PlutoSource():
      // Provisional (Task 5): Pluto necesita resolver la URL antes de abrir
      // el reproductor de películas.
      throw UnsupportedError('Pluto TV se reproduce resolviendo su URL.');
    case VimeoSource(:final videoId):
      return TvVimeoPlayer(videoId: videoId, title: title.title);
    case YoutubeSource(:final videoId):
      // El reproductor de YouTube pide un canal y un programa: se le da un
      // canal «Cineaparte» que solo existe para esto.
      return TvYoutubePlayer(
        channel: Channel(
          name: 'Cineaparte',
          url: 'https://www.cineaparte.com/',
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

/// Abre el reproductor de [title] a pantalla completa; termina al cerrarlo.
Future<void> playOnDemandTitle(BuildContext context, OnDemandTitle title) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => onDemandPlayerFor(title)),
  );
}
