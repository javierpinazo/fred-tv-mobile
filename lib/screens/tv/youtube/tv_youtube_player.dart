import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/backend/youtube/youtube_program.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/screens/tv/widgets/tv_focusable.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';
import 'package:open_tv/screens/tv/youtube/youtube_player_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Donde se dibuja y se maneja la página del reproductor (una WebView).
abstract class YoutubePlayerSurface {
  Widget build(BuildContext context);
  Future<void> load(String html, String baseUrl);
  Future<void> run(String js);
  set onMessage(void Function(String message) handler);

  /// Detiene la reproducción y suelta la página.
  Future<void> dispose();
}

/// [YoutubePlayerSurface] real, sobre `webview_flutter`.
class WebViewYoutubeSurface implements YoutubePlayerSurface {
  WebViewYoutubeSurface() {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(youtubePlayerChannel,
          onMessageReceived: (m) => _handler?.call(m.message));
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      // Sin esto el vídeo no arranca solo: no hay «toque» con un mando.
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  final WebViewController _controller = WebViewController();
  void Function(String message)? _handler;

  @override
  Widget build(BuildContext context) =>
      // Las teclas las maneja la pantalla; la página no debe recibir toques.
      IgnorePointer(child: WebViewWidget(controller: _controller));

  @override
  Future<void> load(String html, String baseUrl) =>
      _controller.loadHtmlString(html, baseUrl: baseUrl);

  @override
  Future<void> run(String js) => _controller.runJavaScript(js);

  @override
  set onMessage(void Function(String message) handler) => _handler = handler;

  @override
  Future<void> dispose() async {
    _handler = null;
    // Una página en blanco corta el audio aunque la vista tarde en destruirse.
    await _controller.loadRequest(Uri.parse('about:blank'));
  }
}

/// Abre el vídeo en la app de YouTube de la tele.
Future<void> openInYoutubeApp(String videoId) async {
  await launchUrl(
    Uri.parse('https://www.youtube.com/watch?v=$videoId'),
    mode: LaunchMode.externalApplication,
  );
}

/// Abre el reproductor de YouTube con [program]; termina al cerrarlo.
Future<void> openTvYoutubePlayer(
    BuildContext context, Channel channel, YoutubeProgram program) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => TvYoutubePlayer(channel: channel, program: program),
    ),
  );
}

/// Reproductor oficial de YouTube a pantalla completa, manejado con el mando.
class TvYoutubePlayer extends StatefulWidget {
  const TvYoutubePlayer({
    super.key,
    required this.channel,
    required this.program,
    this.surface,
    this.openExternally,
    this.readyTimeout = const Duration(seconds: 20),
    this.keepAwake = true,
  });

  final Channel channel;
  final YoutubeProgram program;
  final YoutubePlayerSurface? surface;
  final Future<void> Function(String videoId)? openExternally;

  /// Tiempo máximo sin noticias del reproductor antes de darlo por fallido.
  final Duration readyTimeout;

  /// Mantener la pantalla encendida mientras se reproduce.
  final bool keepAwake;

  @override
  State<TvYoutubePlayer> createState() => _TvYoutubePlayerState();
}

class _TvYoutubePlayerState extends State<TvYoutubePlayer> {
  static const _overlayDuration = Duration(seconds: 4);

  late final YoutubePlayerSurface _surface;
  final FocusNode _keysNode = FocusNode(debugLabel: 'yt-player-keys');
  final FocusNode _failNode = FocusNode(debugLabel: 'yt-player-open-external');
  Timer? _readyTimer;
  Timer? _overlayTimer;

  YoutubePlayerState _state = YoutubePlayerState.loading;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLive = false;
  bool _started = false;
  bool _failed = false;
  bool _overlay = false;
  bool _loaded = false;
  bool _closing = false;
  String _quality = '';

  @override
  void initState() {
    super.initState();
    _isLive = widget.program.isLive;
    _surface = widget.surface ?? WebViewYoutubeSurface();
    _surface.onMessage = _onMessage;
    _readyTimer = Timer(widget.readyTimeout, _fail);
    if (widget.keepAwake) unawaited(WakelockPlus.enable());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final language = Localizations.localeOf(context).languageCode;
    try {
      unawaited(_surface.load(
          youtubePlayerHtml(widget.program.videoId, language: language),
          youtubePlayerOrigin));
    } on ArgumentError catch (e) {
      debugPrint('TvYoutubePlayer: $e');
      scheduleMicrotask(_fail);
    }
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _overlayTimer?.cancel();
    _keysNode.dispose();
    _failNode.dispose();
    unawaited(_surface.dispose());
    if (widget.keepAwake) unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _fail() {
    if (!mounted || _failed) return;
    _readyTimer?.cancel();
    setState(() => _failed = true);
    // El foco estaba en las teclas del reproductor: hay que llevarlo al aviso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _failNode.requestFocus();
    });
  }

  void _onMessage(String message) {
    if (!mounted || _failed) return;
    final event = parseYoutubePlayerEvent(message);
    switch (event) {
      case null:
        return;
      case YoutubeErrorEvent(:final code):
        debugPrint('TvYoutubePlayer: error $code en ${widget.program.videoId}');
        _fail();
      case YoutubeStateEvent():
        _readyTimer?.cancel();
        if (event.state == YoutubePlayerState.ended) {
          _close();
          return;
        }
        if (event.quality != _quality && event.quality.isNotEmpty) {
          debugPrint('TvYoutubePlayer: calidad ${event.quality}');
        }
        setState(() {
          _state = event.state;
          _position = event.position;
          _duration = event.duration;
          _isLive = event.isLive || widget.program.isLive;
          _quality = event.quality;
          if (event.state == YoutubePlayerState.playing) _started = true;
        });
    }
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_failed) return KeyEventResult.ignored;
    final command = youtubeKeyCommand(event.logicalKey);
    if (command == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      unawaited(_surface.run(youtubeCommandJs(command)));
      _showOverlay();
    }
    return KeyEventResult.handled;
  }

  void _showOverlay() {
    _overlayTimer?.cancel();
    setState(() => _overlay = true);
    _overlayTimer = Timer(_overlayDuration, () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  Future<void> _openExternally() async {
    final open = widget.openExternally ?? openInYoutubeApp;
    try {
      await open(widget.program.videoId);
    } catch (e) {
      debugPrint('TvYoutubePlayer: no se pudo abrir YouTube: $e');
    }
    _close();
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final paused = _state == YoutubePlayerState.paused;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _keysNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Con el reproductor roto se retira la página: nada sigue sonando.
            if (!_failed) _surface.build(context),
            if (!_failed && !_started)
              const Center(child: CircularProgressIndicator()),
            if (!_failed && (_overlay || paused)) _bar(context, paused),
            if (_failed) _failure(context),
          ],
        ),
      ),
    );
  }

  /// Estado y posición en una pastilla compacta. El título no se repite: el
  /// reproductor de YouTube ya lo muestra arriba al pausar o saltar, y abajo
  /// pone sus propios elementos, que esta pastilla deja libres.
  Widget _bar(BuildContext context, bool paused) {
    final l10n = context.l10n;
    return Align(
      alignment: const Alignment(0, 0.72),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xD9000000),
          borderRadius: BorderRadius.circular(TvTheme.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(paused ? Icons.pause : Icons.play_arrow,
                color: TvTheme.textPrimary, size: 28),
            const SizedBox(width: 12),
            if (_isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: TvTheme.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.ytLive,
                  style: const TextStyle(
                    fontSize: TvTheme.fontSmall,
                    fontWeight: FontWeight.w700,
                    color: TvTheme.textPrimary,
                  ),
                ),
              )
            else
              Text(
                '${_clock(_position)} / ${_clock(_duration)}',
                style: const TextStyle(
                    fontSize: TvTheme.fontBody, color: TvTheme.textPrimary),
              ),
            if (paused) ...[
              const SizedBox(width: 18),
              Text(
                l10n.ytPaused,
                style: TextStyle(
                    fontSize: TvTheme.fontBody, color: TvTheme.textSecondary),
              ),
            ],
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
            Text(
              l10n.ytPlayerFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: TvTheme.fontTitle, color: TvTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              widget.program.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: TvTheme.fontBody, color: TvTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _button(l10n.ytOpenInYoutube,
                    onSelect: _openExternally,
                    primary: true,
                    focusNode: _failNode),
                const SizedBox(width: 20),
                _button(l10n.ytBack, onSelect: _close),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label,
      {required VoidCallback onSelect,
      bool primary = false,
      FocusNode? focusNode}) {
    return TvFocusable(
      focusNode: focusNode,
      onSelect: onSelect,
      builder: (context, focused) => Container(
        constraints: const BoxConstraints(minWidth: 160, minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary
              ? TvTheme.accent
              : (focused ? TvTheme.surfaceRaised : TvTheme.surface),
          borderRadius: BorderRadius.circular(TvTheme.radius - 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: TvTheme.fontBody, color: TvTheme.textPrimary),
        ),
      ),
    );
  }
}
