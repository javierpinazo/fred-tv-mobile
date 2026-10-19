import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';
import 'package:open_tv/screens/tv/player/exo_engine.dart';
import 'package:open_tv/screens/tv/player/mpv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_player_keys.dart';
import 'package:open_tv/screens/tv/player/tv_playlist.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:open_tv/screens/tv/widgets/tv_dialogs.dart';
import 'package:open_tv/screens/tv/widgets/tv_guide_dialog.dart';
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
  TvEngine? _engine;
  final List<StreamSubscription<dynamic>> _engineSubs = [];
  List<TvPlaybackAttempt> _plan = const [];
  TvEngineKind? _preferEngine;
  GuideNowNext? _guideNow;
  bool _frameShown = false;
  final FocusNode _focus = FocusNode();
  final FocusNode _retryFocus = FocusNode();

  Timer? _overlayTimer;
  Timer? _firstFrameTimer;
  Timer? _stallTimer;
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
    _play(0);
    _showOverlay();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _firstFrameTimer?.cancel();
    _stallTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final s in _engineSubs) {
      s.cancel();
    }
    _engine?.dispose();
    _focus.dispose();
    _retryFocus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // --- Reproducción -------------------------------------------------------

  Future<void> _play(int attemptIndex) async {
    final generation = ++_generation;
    final channel = _channel;
    _attemptIndex = attemptIndex;
    _frameShown = false;
    _firstFrameTimer?.cancel();
    _stallTimer?.cancel();
    _reconnectTimer?.cancel();
    if (mounted) {
      final hadError = _hasError;
      setState(() {
        _loading = true;
        _hasError = false;
      });
      if (hadError) {
        WidgetsBinding.instance.endOfFrame.then((_) {
          if (mounted && !_hasError) _focus.requestFocus();
        });
      }
    }
    try {
      // El id puede haber cambiado si la fuente se refrescó después de listar
      // el canal; si ya no existe se muestra el error directamente.
      final id = await widget.data.resolveChannelId(channel);
      if (!mounted || generation != _generation) return;
      if (id == null) {
        _showError();
        return;
      }
      final headers = await widget.data.channelHeaders(id);
      final userAgent = headers?.userAgent ?? tvFallbackUserAgent;
      final extraHeaders = {
        if (headers?.referrer != null) 'Referer': headers!.referrer!,
        if (headers?.httpOrigin != null) 'Origin': headers!.httpOrigin!,
      };
      if (attemptIndex == 0) {
        unawaited(_loadGuide(channel));
        await widget.data.addToHistory(id);
        final mode = await widget.data.videoEngineMode();
        // Lo que el usuario eligió para este canal manda sobre el ajuste.
        _preferEngine ??= await widget.data.channelEngine(channel.url!);
        _plan = TvRetryPolicy.plan(channel.url!,
            mode: mode, prefer: _preferEngine);
      }
      final attempt = _plan[attemptIndex];
      final bufferSecs = await widget.data.bufferSeconds();
      final seconds = channel.mediaType == MediaType.movie
          ? await Sql.getPosition(id)
          : null;
      if (!mounted || generation != _generation) return;
      await _useEngine(attempt.engine);
      if (!mounted || generation != _generation) return;
      final timeout = TvRetryPolicy.firstFrameTimeout(attempt);
      await _engine!
          .open(TvMedia(
            url: channel.url!,
            userAgent: userAgent,
            headers: extraHeaders,
            start: seconds != null ? Duration(seconds: seconds) : null,
            bufferSecs: bufferSecs,
            hardwareDecoding: attempt.hardwareDecoding,
          ))
          .timeout(timeout);
      if (!mounted || generation != _generation) return;
      if (!_frameShown) {
        _firstFrameTimer = Timer(timeout, () => _onFailure(generation));
      }
    } catch (e) {
      debugPrint('TvPlayer: error abriendo ${channel.name}: $e');
      _onFailure(generation);
    }
  }

  /// Cambia de motor (ExoPlayer o mpv) liberando el anterior.
  Future<void> _useEngine(TvEngineKind kind) async {
    if (_engine?.kind == kind) return;
    for (final s in _engineSubs) {
      await s.cancel();
    }
    _engineSubs.clear();
    final old = _engine;
    _engine = null;
    if (mounted) setState(() {});
    // El widget de video viejo debe salir del árbol antes de liberarlo.
    await WidgetsBinding.instance.endOfFrame;
    await old?.dispose();
    if (!mounted) return;
    final engine = kind == TvEngineKind.exo ? ExoEngine() : MpvEngine();
    _engine = engine;
    _engineSubs.addAll([
      engine.firstFrame.listen(_onFirstFrame),
      engine.errors.listen(_onPlayerError),
      engine.completed.listen(_onCompleted),
      engine.playing.listen((playing) {
        if (mounted) setState(() => _playing = playing);
      }),
    ]);
    setState(() {});
  }

  /// Muestra el error y le da el foco a "Reintentar" (el `autofocus` pierde
  /// frente al Focus raíz del reproductor).
  void _showError() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasError = true;
      _overlayVisible = true;
    });
    // Con el error en pantalla no se reintenta solo: los reintentos en segundo
    // plano devolvían el foco a "Reintentar" y se comían las pulsaciones.
    _overlayTimer?.cancel();
    _firstFrameTimer?.cancel();
    _reconnectTimer?.cancel();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted && _hasError) _retryFocus.requestFocus();
    });
  }

  void _onFailure(int generation) {
    if (!mounted || _exiting || generation != _generation) return;
    _firstFrameTimer?.cancel();
    if (TvRetryPolicy.next(_plan, _attemptIndex) != null) {
      _play(_attemptIndex + 1);
      return;
    }
    _showError();
  }

  void _onFirstFrame(void _) {
    _frameShown = true;
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
    debugPrint('TvPlayer: error de ${_engine?.kind.label}: $message');
    if (_exiting || _hasError) return;
    if (_loading) {
      _onFailure(_generation);
    } else if (_isLive) {
      final engine = _engine;
      if (engine != null &&
          TvRetryPolicy.errorIsTransientWhilePlaying(engine.kind)) {
        _checkStall(engine);
      } else {
        _reconnectLive();
      }
    }
  }

  /// Tras un error de mpv con imagen en pantalla: solo se reconecta si la
  /// reproducción realmente se detuvo (la posición no avanzó).
  void _checkStall(TvEngine engine) {
    if (_stallTimer?.isActive == true) return;
    final before = engine.position;
    final generation = _generation;
    _stallTimer = Timer(TvRetryPolicy.stallCheckDelay, () {
      if (!mounted ||
          _exiting ||
          _hasError ||
          _loading ||
          generation != _generation ||
          !identical(engine, _engine)) {
        return;
      }
      if (engine.position <= before) _reconnectLive();
    });
  }

  void _onCompleted(bool completed) {
    if (completed && _isLive && !_exiting && !_loading && !_hasError) {
      _reconnectLive();
    }
  }

  void _reconnectLive() {
    if (_exiting || _hasError || _reconnectTimer?.isActive == true) return;
    if (_liveReconnects >= TvRetryPolicy.maxLiveReconnects) {
      _showError();
      return;
    }
    _liveReconnects++;
    _reconnectTimer = Timer(TvRetryPolicy.reconnectDelay, () => _play(0));
  }

  // --- Comandos -----------------------------------------------------------

  /// Programa actual y siguiente (solo canales con guía); falla en silencio.
  Future<void> _loadGuide(Channel channel) async {
    if (!widget.data.hasGuide(channel)) {
      if (_guideNow != null && mounted) setState(() => _guideNow = null);
      return;
    }
    final result = await widget.data.guideNowNext(channel);
    if (mounted && identical(channel, _channel)) {
      setState(() => _guideNow = result);
    }
  }

  void _showOverlay() {
    _overlayTimer?.cancel();
    if (!_overlayVisible && mounted) {
      unawaited(_loadGuide(_channel));
      setState(() => _overlayVisible = true);
    }
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
    _preferEngine = null;
    _liveReconnects = 0;
    setState(() {});
    _play(0);
    _showOverlay();
  }

  void _seek(Duration delta) {
    final engine = _engine;
    if (engine != null) engine.seek(engine.position + delta);
    _showOverlay();
  }

  void _run(TvPlayerCommand command) {
    switch (command) {
      case TvPlayerCommand.none:
        break;
      case TvPlayerCommand.togglePlayPause:
        _engine?.playOrPause();
        _showOverlay();
      case TvPlayerCommand.play:
        _engine?.play();
        _showOverlay();
      case TvPlayerCommand.pause:
        _engine?.pause();
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
    // Atrás lo gestiona el PopScope (evita procesarlo dos veces).
    if (isSystemBackKey(key)) return KeyEventResult.ignored;
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
    final engine = _engine;
    final canSwitchToExo = engine?.kind == TvEngineKind.mpv &&
        TvRetryPolicy.exoCanOpen(channel.url ?? '');
    final choice = await showTvOptions<String>(
      context,
      title: channel.name,
      options: [
        if (engine?.supportsTracks == true) ('Audio', 'audio'),
        if (engine?.supportsTracks == true) ('Subtítulos', 'subs'),
        ('Ajustar imagen', 'fit'),
        if (widget.data.hasGuide(channel)) ('Ver programación', 'guide'),
        (
          channel.favorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
          'fav'
        ),
        if (engine?.kind == TvEngineKind.exo)
          ('Usar mpv en este canal (audio y subtítulos)', 'to-mpv'),
        if (canSwitchToExo) ('Usar ExoPlayer en este canal', 'to-exo'),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'audio':
        await _openTrackModal('Audio', engine!.audioTracks(), engine.selectAudio);
      case 'subs':
        await _openTrackModal(
            'Subtítulos', engine!.subtitleTracks(), engine.selectSubtitle);
      case 'guide':
        await showTvGuide(context, data: widget.data, channel: channel);
      case 'fit':
        setState(() => _fill = !_fill);
      case 'fav':
        final id = await widget.data.resolveChannelId(channel);
        if (id != null) {
          await widget.data.setFavorite(id, !channel.favorite);
          channel.favorite = !channel.favorite;
        }
      case 'to-mpv':
      case 'to-exo':
        _preferEngine =
            choice == 'to-mpv' ? TvEngineKind.mpv : TvEngineKind.exo;
        await widget.data.setChannelEngine(channel.url!, _preferEngine!);
        _liveReconnects = 0;
        unawaited(_play(0));
    }
    if (mounted) _showOverlay();
  }

  Future<void> _openTrackModal(
    String title,
    List<IdData<String>> tracks,
    Future<void> Function(int index) select,
  ) {
    return showDialog(
      context: context,
      builder: (ctx) => SelectDialog(
        title: title,
        action: (id) async {
          select(id);
          Navigator.of(ctx).pop();
        },
        data: tracks,
      ),
    );
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    _generation++;
    if (_channel.mediaType == MediaType.movie) {
      unawaited(_savePosition(_channel, _engine?.position.inSeconds ?? 0));
    }
    if (!mounted) return;
    Navigator.of(context).pop(_cursor.index);
  }

  Future<void> _savePosition(Channel channel, int seconds) async {
    try {
      final id = await widget.data.resolveChannelId(channel);
      if (id != null) await Sql.setPosition(id, seconds);
    } catch (e) {
      debugPrint('TvPlayer: error guardando la posición: $e');
    }
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
              _engine?.buildVideo(fill: _fill) ?? const SizedBox.expand(),
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

  /// "Ahora: X  ·  08:30 AM: Y" o `null` si el canal no tiene guía.
  String? _guideLine() {
    final g = _guideNow;
    if (g == null || (g.now == null && g.next == null)) return null;
    return [
      if (g.now != null) 'Ahora: ${g.now!.title}',
      if (g.next != null) '${g.next!.timeLabel}: ${g.next!.title}',
    ].join('  ·  ');
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
                if (_engine != null) _engine!.kind.label,
              ].join('  ·  '),
              style: const TextStyle(
                fontSize: TvTheme.fontBody,
                color: TvTheme.textSecondary,
              ),
            ),
            if (_guideLine() != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _guideLine()!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: TvTheme.fontBody,
                    color: TvTheme.textPrimary,
                  ),
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
      stream: _engine?.positionStream,
      initialData: _engine?.position ?? Duration.zero,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final total = _engine?.duration ?? Duration.zero;
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
                focusNode: _retryFocus,
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
    FocusNode? focusNode,
    required VoidCallback onSelect,
  }) {
    return TvFocusable(
      focusNode: focusNode,
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
