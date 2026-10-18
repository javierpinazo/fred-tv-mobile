import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/player/tv_player_keys.dart';
import 'package:open_tv/screens/tv/player/tv_playlist.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';
import 'package:open_tv/select_dialog.dart';

/// Abre el reproductor TV y devuelve el índice del último canal reproducido.
Future<int?> openTvPlayer(
  BuildContext context, {
  required List<Channel> playlist,
  required int index,
  TvData data = const TvData(),
}) {
  return Navigator.of(context).push<int>(
    MaterialPageRoute<int>(
      builder: (_) => TvPlayer(
        playlist: playlist,
        initialIndex: index,
        data: data,
      ),
    ),
  );
}

class TvPlayer extends StatefulWidget {
  const TvPlayer({
    super.key,
    required this.playlist,
    required this.initialIndex,
    this.data = const TvData(),
  });

  final List<Channel> playlist;
  final int initialIndex;
  final TvData data;

  @override
  State<TvPlayer> createState() => _TvPlayerState();
}

class _TvPlayerState extends State<TvPlayer> {
  static const _overlayDuration = Duration(seconds: 4);
  static const _seekStep = Duration(seconds: 10);

  late final TvPlaylistCursor _cursor;
  final mk.Player _player = mk.Player();
  late final VideoController _video;
  final FocusNode _focus = FocusNode();
  final List<StreamSubscription<dynamic>> _subs = [];

  Timer? _overlayTimer;
  Timer? _firstFrameTimer;
  Timer? _reconnectTimer;

  bool _exiting = false;
  bool _loading = true;
  bool _hasError = false;
  bool _playing = true;
  bool _overlayVisible = true;
  bool _fill = false;
  bool _okPressed = false;
  bool _okLong = false;
  int _attemptIndex = 0;
  int _liveReconnects = 0;
  int _generation = 0;

  Channel get _channel => _cursor.current;
  bool get _isLive => _channel.mediaType == MediaType.livestream;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _cursor = TvPlaylistCursor(widget.playlist, widget.initialIndex);
    _video = VideoController(_player);
    _subs.addAll([
      _player.stream.width.listen(_onWidth),
      _player.stream.error.listen(_onPlayerError),
      _player.stream.completed.listen(_onCompleted),
      _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _playing = playing);
      }),
    ]);
    _play(0);
    _showOverlay();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _firstFrameTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    _focus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // --- Reproducción -------------------------------------------------------

  Future<void> _play(int attemptIndex) async {
    final generation = ++_generation;
    final channel = _channel;
    _attemptIndex = attemptIndex;
    _firstFrameTimer?.cancel();
    _reconnectTimer?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      if (attemptIndex == 0) {
        await widget.data.addToHistory(channel.id!);
      }
      final headers = await widget.data.channelHeaders(channel.id!);
      final seconds = channel.mediaType == MediaType.movie
          ? await Sql.getPosition(channel.id!)
          : null;
      if (!mounted || generation != _generation) return;
      final platform = _player.platform;
      if (platform is mk.NativePlayer) {
        final attempt = TvRetryPolicy.attempts[attemptIndex];
        await platform.setProperty(
            'hwdec', attempt.hardwareDecoding ? 'auto-safe' : 'no');
        await platform.setProperty('network-timeout', '15');
      }
      await _player.open(
        mk.Media(
          channel.url!,
          start: seconds != null ? Duration(seconds: seconds) : null,
          httpHeaders: {
            if (headers?.referrer != null) 'Referer': headers!.referrer!,
            if (headers?.httpOrigin != null) 'Origin': headers!.httpOrigin!,
            'User-Agent': headers?.userAgent ?? tvFallbackUserAgent,
          },
        ),
      );
      if (!mounted || generation != _generation) return;
      _firstFrameTimer = Timer(
        TvRetryPolicy.firstFrameTimeout,
        () => _onFailure(generation),
      );
    } catch (e) {
      debugPrint('TvPlayer: error abriendo ${channel.name}: $e');
      _onFailure(generation);
    }
  }

  void _onFailure(int generation) {
    if (!mounted || _exiting || generation != _generation) return;
    _firstFrameTimer?.cancel();
    if (TvRetryPolicy.next(_attemptIndex) != null) {
      _play(_attemptIndex + 1);
      return;
    }
    setState(() {
      _loading = false;
      _hasError = true;
      _overlayVisible = true;
    });
    _overlayTimer?.cancel();
  }

  void _onWidth(int? width) {
    if (width == null || width <= 0) return;
    _firstFrameTimer?.cancel();
    _liveReconnects = 0;
    if (mounted && (_loading || _hasError)) {
      setState(() {
        _loading = false;
        _hasError = false;
      });
    }
  }

  void _onPlayerError(String message) {
    debugPrint('TvPlayer: error de mpv: $message');
    if (_exiting) return;
    if (_loading) {
      _onFailure(_generation);
    } else if (_isLive) {
      _reconnectLive();
    }
  }

  void _onCompleted(bool completed) {
    if (completed && _isLive && !_exiting && !_loading) _reconnectLive();
  }

  void _reconnectLive() {
    if (_exiting || _reconnectTimer?.isActive == true) return;
    if (_liveReconnects >= TvRetryPolicy.maxLiveReconnects) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _overlayVisible = true;
        });
      }
      return;
    }
    _liveReconnects++;
    _reconnectTimer = Timer(TvRetryPolicy.reconnectDelay, () => _play(0));
  }

  // --- Comandos -----------------------------------------------------------

  void _showOverlay() {
    _overlayTimer?.cancel();
    if (!_overlayVisible && mounted) setState(() => _overlayVisible = true);
    if (_hasError) return;
    _overlayTimer = Timer(_overlayDuration, () {
      if (mounted && !_hasError) setState(() => _overlayVisible = false);
    });
  }

  void _toggleOverlay() {
    if (_overlayVisible && !_hasError) {
      _overlayTimer?.cancel();
      setState(() => _overlayVisible = false);
    } else {
      _showOverlay();
    }
  }

  void _zap(bool forward) {
    forward ? _cursor.next() : _cursor.previous();
    _liveReconnects = 0;
    setState(() {});
    _play(0);
    _showOverlay();
  }

  void _seek(Duration delta) {
    _player.seek(_player.state.position + delta);
    _showOverlay();
  }

  void _run(TvPlayerCommand command) {
    switch (command) {
      case TvPlayerCommand.none:
        break;
      case TvPlayerCommand.togglePlayPause:
        _player.playOrPause();
        _showOverlay();
      case TvPlayerCommand.play:
        _player.play();
        _showOverlay();
      case TvPlayerCommand.pause:
        _player.pause();
        _showOverlay();
      case TvPlayerCommand.seekBack:
        _seek(-_seekStep);
      case TvPlayerCommand.seekForward:
        _seek(_seekStep);
      case TvPlayerCommand.previousChannel:
        _zap(false);
      case TvPlayerCommand.nextChannel:
        _zap(true);
      case TvPlayerCommand.showOverlay:
        _showOverlay();
      case TvPlayerCommand.toggleOverlay:
        _toggleOverlay();
      case TvPlayerCommand.openOptions:
        _openOptions();
      case TvPlayerCommand.exit:
        _exit();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isOk = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
    if (_hasError) {
      // Con el error en pantalla las flechas/OK navegan sus botones.
      if (event is KeyDownEvent &&
          mapTvPlayerKey(key, isLive: _isLive) == TvPlayerCommand.exit) {
        _exit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (isOk) {
      if (event is KeyDownEvent) {
        _okPressed = true;
        _okLong = false;
        return KeyEventResult.handled;
      }
      if (event is KeyRepeatEvent) {
        if (_okPressed && !_okLong) {
          _okLong = true;
          _openOptions();
        }
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        if (!_okPressed) return KeyEventResult.ignored;
        final wasLong = _okLong;
        _okPressed = false;
        _okLong = false;
        if (!wasLong) _run(mapTvPlayerKey(key, isLive: _isLive));
        return KeyEventResult.handled;
      }
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final command = mapTvPlayerKey(key, isLive: _isLive);
    if (command == TvPlayerCommand.none) return KeyEventResult.ignored;
    _run(command);
    return KeyEventResult.handled;
  }

  Future<void> _openOptions() async {
    _overlayTimer?.cancel();
    final channel = _channel;
    final choice = await showTvOptions<String>(
      context,
      title: channel.name,
      options: [
        ('Audio', 'audio'),
        ('Subtítulos', 'subs'),
        ('Ajustar imagen', 'fit'),
        (
          channel.favorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
          'fav'
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'audio':
        await _openAudioModal();
      case 'subs':
        await _openSubtitlesModal();
      case 'fit':
        setState(() => _fill = !_fill);
      case 'fav':
        await widget.data.setFavorite(channel.id!, !channel.favorite);
        channel.favorite = !channel.favorite;
    }
    if (mounted) _showOverlay();
  }

  Future<void> _openSubtitlesModal() {
    final tracks = _player.state.tracks.subtitle;
    return showDialog(
      context: context,
      builder: (ctx) => SelectDialog(
        title: 'Subtítulos',
        action: (id) async {
          _player.setSubtitleTrack(tracks[id]);
          Navigator.of(ctx).pop();
        },
        data: tracks
            .asMap()
            .entries
            .map((e) => IdData(
                id: e.key,
                data: e.value.language != null
                    ? '${e.value.language} - ${e.value.id}'
                    : e.value.id))
            .toList(),
      ),
    );
  }

  Future<void> _openAudioModal() {
    final tracks = _player.state.tracks.audio;
    return showDialog(
      context: context,
      builder: (ctx) => SelectDialog(
        title: 'Audio',
        action: (id) async {
          _player.setAudioTrack(tracks[id]);
          Navigator.of(ctx).pop();
        },
        data: tracks
            .asMap()
            .entries
            .map((e) => IdData(
                id: e.key,
                data: e.value.title ?? e.value.language ?? e.value.id))
            .toList(),
      ),
    );
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    _generation++;
    if (_channel.mediaType == MediaType.movie) {
      Sql.setPosition(_channel.id!, _player.state.position.inSeconds);
    }
    if (!mounted) return;
    Navigator.of(context).pop(_cursor.index);
  }

  // --- UI -----------------------------------------------------------------

  String _status() {
    if (_loading) return 'Cargando…';
    if (!_playing) return 'Pausado';
    return _isLive ? 'En vivo' : '';
  }

  String _keyHint() => _isLive
      ? '↑↓ Cambiar canal  ·  OK Info  ·  Mantén OK Opciones  ·  Atrás Salir'
      : '←→ 10 s  ·  OK Pausa  ·  Mantén OK Opciones  ·  Atrás Salir';

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Video(
                controller: _video,
                controls: NoVideoControls,
                fit: _fill ? BoxFit.cover : BoxFit.contain,
                wakelock: true,
              ),
              if (_loading && !_hasError)
                const Center(
                  child: CircularProgressIndicator(color: TvTheme.accent),
                ),
              if (_hasError) _buildError(),
              if (_overlayVisible && !_hasError) _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final channel = _channel;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(48, 48, 48, 27),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xDD000000)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: TvTheme.fontTitle,
                      fontWeight: FontWeight.bold,
                      color: TvTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _cursor.positionLabel,
                  style: const TextStyle(
                    fontSize: TvTheme.fontBody,
                    color: TvTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (channel.group != null && channel.group!.isNotEmpty)
                  channel.group!,
                if (_status().isNotEmpty) _status(),
              ].join('  ·  '),
              style: const TextStyle(
                fontSize: TvTheme.fontBody,
                color: TvTheme.textSecondary,
              ),
            ),
            if (!_isLive) _buildProgress(),
            const SizedBox(height: 10),
            Text(
              _keyHint(),
              style: const TextStyle(
                fontSize: TvTheme.fontSmall,
                color: TvTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      initialData: _player.state.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final total = _player.state.duration;
        final value = total.inMilliseconds > 0
            ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Text(
                _fmt(position),
                style: const TextStyle(color: TvTheme.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: value,
                  color: TvTheme.accent,
                  backgroundColor: TvTheme.surfaceRaised,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _fmt(total),
                style: const TextStyle(color: TvTheme.textPrimary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xCC000000),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: TvTheme.error, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No se pudo reproducir este canal',
            style: TextStyle(
              fontSize: TvTheme.fontTitle,
              fontWeight: FontWeight.bold,
              color: TvTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _channel.name,
            style: const TextStyle(
              fontSize: TvTheme.fontBody,
              color: TvTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _errorButton(
                'Reintentar',
                autofocus: true,
                onSelect: () {
                  _liveReconnects = 0;
                  _play(0);
                },
              ),
              const SizedBox(width: 16),
              _errorButton(
                'Siguiente canal',
                onSelect: () => _zap(true),
              ),
              const SizedBox(width: 16),
              _errorButton('Volver', onSelect: _exit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorButton(
    String label, {
    bool autofocus = false,
    required VoidCallback onSelect,
  }) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      builder: (context, focused) => Container(
        constraints: const BoxConstraints(minWidth: 160, minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? TvTheme.surfaceRaised : TvTheme.surface,
          borderRadius: BorderRadius.circular(TvTheme.radius - 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: TvTheme.fontBody,
            color: TvTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
