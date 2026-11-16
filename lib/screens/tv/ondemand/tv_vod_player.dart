import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/ondemand/on_demand_provider.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/player/exo_engine.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';
import 'package:open_tv/screens/tv/widgets/tv_button.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';
import 'package:open_tv/screens/tv/youtube/youtube_player_page.dart';

/// Reproductor de películas de vídeo directo (HLS/MP4) a pantalla completa,
/// sobre ExoPlayer: OK pausa o reanuda, ←/→ saltan 10 s, Atrás sale. Termina
/// solo al acabar la película.
class TvVodPlayer extends StatefulWidget {
  const TvVodPlayer({
    super.key,
    required this.stream,
    this.title,
    this.engine,
    this.readyTimeout = const Duration(seconds: 20),
  });

  final OnDemandStream stream;
  final String? title;

  /// Solo para pruebas; por defecto [ExoEngine].
  final TvEngine? engine;

  /// Tiempo máximo hasta el primer fotograma antes de darlo por fallido.
  final Duration readyTimeout;

  @override
  State<TvVodPlayer> createState() => _TvVodPlayerState();
}

class _TvVodPlayerState extends State<TvVodPlayer> {
  static const _skip = Duration(seconds: 10);
  static const _overlayDuration = Duration(seconds: 4);

  late final TvEngine _engine = widget.engine ?? ExoEngine();
  final FocusNode _keysNode = FocusNode(debugLabel: 'vod-keys');
  final FocusNode _retryNode = FocusNode(debugLabel: 'vod-retry');
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _readyTimer;
  Timer? _overlayTimer;

  bool _started = false;
  bool _failed = false;
  bool _paused = false;
  bool _overlay = false;
  bool _closing = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_engine.firstFrame.listen((_) {
        _readyTimer?.cancel();
        if (mounted && !_started) setState(() => _started = true);
      }))
      ..add(_engine.errors.listen((e) {
        debugPrint('TvVodPlayer: error del motor: $e');
        _fail();
      }))
      ..add(_engine.completed.listen((_) => _close()))
      ..add(_engine.playing.listen((p) {
        if (mounted) setState(() => _paused = !p);
      }))
      ..add(_engine.positionStream.listen((p) {
        _position = p;
        if (mounted && _overlay) setState(() {});
      }));
    _open();
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _overlayTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _keysNode.dispose();
    _retryNode.dispose();
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    _readyTimer?.cancel();
    _readyTimer = Timer(widget.readyTimeout, _fail);
    try {
      await _engine.open(TvMedia(
        url: widget.stream.url,
        userAgent: tvFallbackUserAgent,
        headers: widget.stream.headers,
      ));
    } catch (e) {
      debugPrint('TvVodPlayer: no se pudo abrir: $e');
      _fail();
    }
  }

  void _fail() {
    if (!mounted || _failed) return;
    _readyTimer?.cancel();
    setState(() => _failed = true);
    // El foco estaba en las teclas del reproductor: se lleva al aviso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retryNode.requestFocus();
    });
  }

  void _retry() {
    setState(() {
      _failed = false;
      _started = false;
      _paused = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keysNode.requestFocus();
    });
    _open();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  Duration _target(int sign) {
    final p = _engine.position;
    final d = _engine.duration;
    var to = p + _skip * sign;
    if (to < Duration.zero) to = Duration.zero;
    if (d > Duration.zero && to > d) to = d;
    return to;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_failed) return KeyEventResult.ignored;
    final command = youtubeKeyCommand(event.logicalKey);
    if (command == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      switch (command) {
        case YoutubeKeyCommand.toggle:
          unawaited(_engine.playOrPause());
        case YoutubeKeyCommand.back30:
          unawaited(_engine.seek(_target(-1)));
        case YoutubeKeyCommand.forward30:
          unawaited(_engine.seek(_target(1)));
      }
      _showOverlay();
    }
    return KeyEventResult.handled;
  }

  void _showOverlay() {
    _overlayTimer?.cancel();
    setState(() {
      _overlay = true;
      _position = _engine.position;
    });
    _overlayTimer = Timer(_overlayDuration, () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _keysNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_failed) _engine.buildVideo(fill: false),
            if (!_failed && !_started)
              const Center(child: CircularProgressIndicator()),
            if (!_failed && (_overlay || _paused)) _bar(),
            if (_failed) _failure(context),
          ],
        ),
      ),
    );
  }

  Widget _bar() {
    return Align(
      alignment: const Alignment(0, 0.8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xD9000000),
          borderRadius: BorderRadius.circular(TvTheme.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_paused ? Icons.pause : Icons.play_arrow,
                color: TvTheme.textPrimary, size: 28),
            const SizedBox(width: 12),
            Text('${_clock(_position)} / ${_clock(_engine.duration)}',
                style: const TextStyle(
                    fontSize: TvTheme.fontBody, color: TvTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _failure(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: TvTheme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 72, color: TvTheme.error),
            const SizedBox(height: 18),
            Text(l10n.ytPlayerFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: TvTheme.fontTitle, color: TvTheme.textPrimary)),
            if (widget.title != null) ...[
              const SizedBox(height: 8),
              Text(widget.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: TvTheme.fontBody,
                      color: TvTheme.textSecondary)),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvButton(
                    key: const ValueKey('vod-retry'),
                    label: l10n.commonRetry,
                    onSelect: _retry,
                    primary: true,
                    focusNode: _retryNode),
                const SizedBox(width: 20),
                TvButton(
                    key: const ValueKey('vod-back'),
                    label: l10n.ytBack,
                    onSelect: _close),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
