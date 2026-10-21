import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/screens/tv/guide/tv_guide.dart';
import 'package:open_tv/screens/tv/player/exo_engine.dart';
import 'package:open_tv/screens/tv/player/tv_camera.dart';
import 'package:open_tv/screens/tv/player/tv_camera_session.dart';
import 'package:open_tv/screens/tv/player/mpv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_channel_number.dart';
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
  final TvChannelNumberBuffer _number = TvChannelNumberBuffer();
  Timer? _numberTimer;
  bool _frameShown = false;
  final FocusNode _focus = FocusNode();
  final FocusNode _retryFocus = FocusNode();

  // Cámara de seguridad en un recuadro (ver `TvCameraSession`). Las claves
  // permiten intercambiar canal y cámara sin recrear sus videos.
  final TvCameraSession _camera = TvCameraSession();
  final GlobalKey _channelVideoKey = GlobalKey();
  final GlobalKey _cameraVideoKey = GlobalKey();
  bool _cameraZoomMode = false;

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
    _camera.addListener(_onCameraChanged);
    _play(0);
    _showOverlay();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _numberTimer?.cancel();
    _firstFrameTimer?.cancel();
    _stallTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final s in _engineSubs) {
      s.cancel();
    }
    _engine?.dispose();
    _camera
      ..removeListener(_onCameraChanged)
      ..dispose();
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
        final zeroCopy = await widget.data.mpvZeroCopySetting();
        _plan = TvRetryPolicy.plan(channel.url!,
            mode: mode, prefer: _preferEngine, zeroCopy: zeroCopy);
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
            zeroCopy: attempt.zeroCopy,
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
    unawaited(_reportFailure(_channel));
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
    unawaited(_reportSuccess(_channel));
    _firstFrameTimer?.cancel();
    _liveReconnects = 0;
    if (mounted && (_loading || _hasError)) {
      setState(() {
        _loading = false;
        _hasError = false;
      });
    }
  }

  /// Cuenta el fallo; si el canal ya cuenta como caído, el zapping lo saltará.
  Future<void> _reportFailure(Channel channel) async {
    try {
      channel.dead = await widget.data.reportChannelFailure(channel);
    } catch (e) {
      debugPrint('TvPlayer: no se pudo guardar el fallo: $e');
    }
  }

  Future<void> _reportSuccess(Channel channel) async {
    channel.dead = false;
    try {
      await widget.data.reportChannelSuccess(channel);
    } catch (e) {
      debugPrint('TvPlayer: no se pudo guardar el éxito: $e');
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

  // --- Cámara -------------------------------------------------------------

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  void _notice(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  Future<void> _showCamera() async {
    final url = await widget.data.cameraUrlSetting();
    if (!mounted) return;
    if (url == null) {
      _notice(context.l10n.playerSetCameraFirst);
      return;
    }
    unawaited(_camera.show(url));
  }

  Future<void> _hideCamera() async {
    _cameraZoomMode = false;
    await _camera.hide();
  }

  void _enterZoomMode() {
    _overlayTimer?.cancel();
    setState(() {
      _cameraZoomMode = true;
      _overlayVisible = false;
    });
  }

  void _endZoomMode() {
    setState(() => _cameraZoomMode = false);
    _showOverlay();
  }

  /// En el modo zoom OK cambia el aumento, las flechas mueven la imagen y
  /// Atrás sale del modo.
  KeyEventResult _onZoomKey(LogicalKeyboardKey key, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.handled;
    final isOk = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
    const step = TvCameraZoom.panStep;
    if (isOk) {
      if (event is KeyDownEvent) _camera.cycleZoom();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _camera.panZoom(-step, 0);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _camera.panZoom(step, 0);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _camera.panZoom(0, -step);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _camera.panZoom(0, step);
    } else if (event is KeyDownEvent &&
        mapTvPlayerKey(key, isLive: true) == TvPlayerCommand.exit) {
      _endZoomMode();
    }
    return KeyEventResult.handled;
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

  void _zap(bool forward) =>
      _switchChannel(() => forward ? _cursor.next() : _cursor.previous());

  /// Cambia de canal con [move] (que mueve el cursor) y arranca el nuevo.
  void _switchChannel(VoidCallback move) {
    move();
    // Si el nuevo canal es la propia cámara, el recuadro sobra.
    if (_camera.visible && _channel.url == _camera.url) unawaited(_hideCamera());
    _preferEngine = null;
    _liveReconnects = 0;
    setState(() {});
    _play(0);
    _showOverlay();
  }

  void _onDigit(int digit) {
    _number.add(digit);
    _numberTimer?.cancel();
    _numberTimer = Timer(TvChannelNumberBuffer.timeout, _commitNumber);
    setState(() {});
    _showOverlay();
  }

  /// Salta al número tecleado (si existe en la lista) y limpia el buffer.
  void _commitNumber() {
    _numberTimer?.cancel();
    final index = _number.resolve(_cursor.channels.length);
    _number.clear();
    if (!mounted) return;
    if (index != null && index != _cursor.index) {
      _switchChannel(() => _cursor.jumpTo(index + 1));
    } else {
      setState(() {});
    }
  }

  void _goLast() {
    if (!_cursor.hasLast) {
      _showOverlay();
      return;
    }
    _switchChannel(_cursor.goToLast);
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
      case TvPlayerCommand.lastChannel:
        _goLast();
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
    if (_cameraZoomMode) return _onZoomKey(key, event);
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
        if (!wasLong) {
          // Con un número a medias, OK lo confirma en vez de mostrar el overlay.
          _number.isEmpty
              ? _run(mapTvPlayerKey(key, isLive: _isLive))
              : _commitNumber();
        }
        return KeyEventResult.handled;
      }
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final digit = digitForKey(key);
    if (digit != null && _isLive && event is KeyDownEvent) {
      _onDigit(digit);
      return KeyEventResult.handled;
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
    // La cámara no se ofrece en su propio canal (ya está en pantalla grande).
    final cameraUrl = await widget.data.cameraUrlSetting();
    if (!mounted) return;
    final showCameraOptions = cameraUrl == null || channel.url != cameraUrl;
    final l10n = context.l10n;
    final choice = await showTvOptions<String>(
      context,
      title: channel.name,
      options: [
        if (engine?.supportsTracks == true) (l10n.playerMenuAudio, 'audio'),
        if (engine?.supportsTracks == true)
          (l10n.playerMenuSubtitles, 'subs'),
        if (_cursor.hasLast) (l10n.playerMenuLast, 'last'),
        (l10n.playerMenuFit, 'fit'),
        if (widget.data.hasGuide(channel)) (l10n.menuShowGuide, 'guide'),
        (
          channel.favorite ? l10n.menuFavoriteRemove : l10n.menuFavoriteAdd,
          'fav'
        ),
        if (engine?.kind == TvEngineKind.exo)
          (l10n.playerMenuToMpv, 'to-mpv'),
        if (canSwitchToExo) (l10n.playerMenuToExo, 'to-exo'),
        if (showCameraOptions && !_camera.visible)
          (l10n.playerCamShow, 'cam-show'),
        if (showCameraOptions && _camera.visible) ...[
          (l10n.playerCamHide, 'cam-hide'),
          (
            _camera.swapped ? l10n.playerCamInBox : l10n.playerCamFull,
            'cam-swap'
          ),
          (l10n.playerCamZoom, 'cam-zoom'),
          if (_camera.status == TvCameraStatus.error)
            (l10n.playerCamRetry, 'cam-retry'),
        ],
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'audio':
        await _openTrackModal(
            l10n.playerMenuAudio, engine!.audioTracks(), engine.selectAudio);
      case 'subs':
        await _openTrackModal(l10n.playerMenuSubtitles,
            engine!.subtitleTracks(), engine.selectSubtitle);
      case 'last':
        _goLast();
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
      case 'cam-show':
        await _showCamera();
      case 'cam-hide':
        await _hideCamera();
      case 'cam-swap':
        _camera.toggleSwap();
      case 'cam-zoom':
        _enterZoomMode();
        return;
      case 'cam-retry':
        unawaited(_camera.retryNow());
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
    if (_cameraZoomMode) {
      _endZoomMode();
      return;
    }
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

  String _status(AppLocalizations l10n) {
    if (_loading) return l10n.playerLoading;
    if (!_playing) return l10n.playerPaused;
    return _isLive ? l10n.playerLive : '';
  }

  String _keyHint(AppLocalizations l10n) =>
      _isLive ? l10n.playerKeyHintLive : l10n.playerKeyHintVod;

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Video del canal, con clave propia para poder cambiarlo de sitio.
  Widget _channelLayer({required bool fill}) => KeyedSubtree(
        key: _channelVideoKey,
        child: _engine?.buildVideo(fill: fill) ?? const SizedBox.expand(),
      );

  /// Video de la cámara con su zoom y su estado (conectando / sin señal).
  Widget _cameraLayer() {
    final status = _camera.status;
    return KeyedSubtree(
      key: _cameraVideoKey,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TvCameraZoomView(
              zoom: _camera.zoom,
              child: _camera.buildVideo() ?? const SizedBox.expand(),
            ),
            if (status == TvCameraStatus.connecting)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      color: TvTheme.accent, strokeWidth: 3),
                ),
              ),
            if (status == TvCameraStatus.error)
              Center(
                child: Text(
                  context.l10n.playerCamNoSignal,
                  style: TextStyle(
                    fontSize: TvTheme.fontBody,
                    color: TvTheme.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Recuadro de la esquina superior derecha.
  Widget _buildPip(Widget content) {
    final width = MediaQuery.sizeOf(context).width * 0.3;
    return Positioned(
      key: const ValueKey('tv-player-pip'),
      top: 32,
      right: 48,
      width: width,
      height: width * 9 / 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(TvTheme.radius),
          border: Border.all(
            color: _cameraZoomMode ? TvTheme.accent : Colors.white54,
            width: _cameraZoomMode ? 3 : 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TvTheme.radius - 2),
          child: content,
        ),
      ),
    );
  }

  Widget _buildZoomHint() => Positioned(
        key: const ValueKey('tv-player-zoom-hint'),
        left: 0,
        right: 0,
        bottom: 32,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(TvTheme.radius),
            ),
            child: Text(
              context.l10n.playerZoomHint(_camera.zoom.label),
              style: const TextStyle(
                fontSize: TvTheme.fontBody,
                color: TvTheme.textPrimary,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cameraBig = _camera.visible && _camera.swapped;
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
              SizedBox.expand(
                child: cameraBig
                    ? _cameraLayer()
                    : _channelLayer(fill: _fill),
              ),
              if (_camera.visible)
                _buildPip(cameraBig ? _channelLayer(fill: false) : _cameraLayer()),
              if (_loading && !_hasError)
                const Center(
                  child: CircularProgressIndicator(color: TvTheme.accent),
                ),
              if (_hasError) _buildError(),
              if (_overlayVisible && !_hasError) _buildOverlay(),
              if (_cameraZoomMode) _buildZoomHint(),
              if (!_number.isEmpty)
                Positioned(
                  top: 32,
                  right: 48,
                  child: Container(
                    key: const ValueKey('tv-player-number'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(TvTheme.radius),
                    ),
                    child: Text(
                      context.l10n.playerChannelNumber(_number.value),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: TvTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Ahora: X  ·  08:30 AM: Y" o `null` si el canal no tiene guía.
  String? _guideLine(AppLocalizations l10n) {
    final g = _guideNow;
    if (g == null || (g.now == null && g.next == null)) return null;
    return [
      if (g.now != null) l10n.playerGuideNow(g.now!.title),
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
                  style: TextStyle(
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
                if (_status(context.l10n).isNotEmpty) _status(context.l10n),
                if (_engine != null) _engine!.kind.label,
              ].join('  ·  '),
              style: TextStyle(
                fontSize: TvTheme.fontBody,
                color: TvTheme.textSecondary,
              ),
            ),
            if (_guideLine(context.l10n) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _guideLine(context.l10n)!,
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
              _keyHint(context.l10n),
              style: TextStyle(
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
          Text(
            context.l10n.playerErrorTitle,
            style: const TextStyle(
              fontSize: TvTheme.fontTitle,
              fontWeight: FontWeight.bold,
              color: TvTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _channel.name,
            style: TextStyle(
              fontSize: TvTheme.fontBody,
              color: TvTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _errorButton(
                context.l10n.commonRetry,
                focusNode: _retryFocus,
                onSelect: () {
                  _liveReconnects = 0;
                  _play(0);
                },
              ),
              const SizedBox(width: 16),
              _errorButton(
                context.l10n.playerNextChannel,
                onSelect: () => _zap(true),
              ),
              const SizedBox(width: 16),
              _errorButton(context.l10n.playerBack, onSelect: _exit),
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
