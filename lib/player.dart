import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkvideo;
import 'package:open_tv/select_dialog.dart';

class Player extends StatefulWidget {
  final Channel channel;
  const Player({super.key, required this.channel});
  @override
  State<StatefulWidget> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late mk.Player player = mk.Player();
  late mkvideo.VideoController videoController =
      mkvideo.VideoController(player);
  late final GlobalKey<VideoState> key = GlobalKey<VideoState>();
  late final FocusNode _focusNode;
  bool exiting = false;
  bool fill = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    mk.MediaKit.ensureInitialized();
    initAsync();
  }

  Future<void> initAsync() async {
    final headers = await Sql.getChannelHeaders(widget.channel.id!);
    final seconds = widget.channel.mediaType == MediaType.movie
        ? await Sql.getPosition(widget.channel.id!)
        : null;
    await player.open(mk.Media(widget.channel.url!,
        start: seconds != null ? Duration(seconds: seconds) : null,
        httpHeaders: headers != null
            ? {
                if (headers.referrer != null) "Referer": headers.referrer!,
                if (headers.httpOrigin != null) "Origin": headers.httpOrigin!,
                if (headers.userAgent != null) "User-Agent": headers.userAgent!,
              }
            : null));
    await key.currentState?.enterFullscreen();
    player.setPlaylistMode(mk.PlaylistMode.single);
  }

  @override
  void dispose() {
    player.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> openSubtitlesModal() async {
    await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => SelectDialog(
            title: "Select subtitles",
            action: (id) async {
              player.setSubtitleTrack(player.state.tracks.subtitle[id]);
              Navigator.of(context).pop();
            },
            data: player.state.tracks.subtitle
                .asMap()
                .entries
                .map((entry) => IdData(
                    id: entry.key,
                    data: entry.value.language != null
                        ? "${entry.value.language} - ${entry.value.id}"
                        : entry.value.id))
                .toList()));
  }

  Future<void> openAudioModal() async {
    await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => SelectDialog(
            title: "Select audio",
            action: (id) async {
              player.setAudioTrack(player.state.tracks.audio[id]);
              Navigator.of(context).pop();
            },
            data: player.state.tracks.audio
                .asMap()
                .entries
                .map((entry) => IdData(
                    id: entry.key,
                    data: entry.value.title ??
                        entry.value.language ??
                        entry.value.id))
                .toList()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          onExit();
        },
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (KeyEvent event) {
            if (event is KeyDownEvent) {
              // Control remoto: Media Controls
              if (event.logicalKey == LogicalKeyboardKey.mediaPlay) {
                player.play();
              } else if (event.logicalKey == LogicalKeyboardKey.mediaPause) {
                player.pause();
              } else if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
                player.playOrPause();
              } else if (event.logicalKey == LogicalKeyboardKey.mediaStop) {
                onExit();
              }
              // D-Pad: Avance y retroceso
              else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.mediaRewind) {
                // Retroceder 10 segundos
                final currentPos = player.state.position;
                player.seek(currentPos - Duration(seconds: 10));
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.mediaFastForward) {
                // Avanzar 10 segundos
                final currentPos = player.state.position;
                player.seek(currentPos + Duration(seconds: 10));
              }
              // D-Pad: Volumen
              else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                // Subir volumen
                final currentVolume = player.state.volume;
                player.setVolume((currentVolume + 10).clamp(0, 100));
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                // Bajar volumen
                final currentVolume = player.state.volume;
                player.setVolume((currentVolume - 10).clamp(0, 100));
              }
              // Botón Select/Enter: Play/Pause
              else if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                player.playOrPause();
              }
              // Botón Back: Salir
              else if (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                onExit();
              }
            }
          },
          child: Scaffold(
              backgroundColor: Colors.black,
              body: MaterialVideoControlsTheme(
                normal: getThemeData(context),
                fullscreen: getThemeData(context),
                child: Video(
                  key: key,
                  controller: videoController,
                  onExitFullscreen: () async => onExit(),
                ),
              )),
        ));
  }

  void onExit() async {
    if (exiting) return;
    exiting = true;
    if (widget.channel.mediaType == MediaType.movie) {
      Sql.setPosition(widget.channel.id!, player.state.position.inSeconds);
    }
    if (key.currentState!.isFullscreen()) {
      await key.currentState!.exitFullscreen();
    }
    Navigator.of(context).pop();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void toggleZoom() {
    final videoAspectRatio = player.state.width! / player.state.height!;
    final deviceAspectRatio = MediaQuery.of(context).size.aspectRatio;
    key.currentState!
        .update(aspectRatio: fill ? videoAspectRatio : deviceAspectRatio);
    setState(() {
      fill = !fill;
    });
  }

  MaterialVideoControlsThemeData getThemeData(BuildContext context) {
    return MaterialVideoControlsThemeData(
        speedUpOnLongPress: false,
        seekOnDoubleTap: widget.channel.mediaType != MediaType.livestream,
        displaySeekBar: widget.channel.mediaType != MediaType.livestream,
        seekBarMargin: const EdgeInsets.only(bottom: 60),
        seekBarThumbSize: 20,
        seekBarHeight: 10,
        seekGesture: widget.channel.mediaType != MediaType.livestream,
        // Botones más grandes para TV
        buttonBarButtonSize: 40,
        topButtonBar: [
          Focus(
            autofocus: false,
            child: IconButton(
              onPressed: onExit,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.channel.name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        bottomButtonBar: [
          Focus(
            child: IconButton(
              onPressed: openSubtitlesModal,
              icon: const Icon(Icons.subtitles, color: Colors.white, size: 36),
            ),
          ),
          SizedBox(width: 24),
          Focus(
            child: IconButton(
              onPressed: openAudioModal,
              icon: const Icon(Icons.music_note, color: Colors.white, size: 36),
            ),
          ),
          SizedBox(width: 24),
          Focus(
            child: IconButton(
              icon: Icon(Icons.aspect_ratio_outlined,
                  color: Colors.white, size: 36),
              onPressed: toggleZoom,
            ),
          ),
        ]);
  }
}
