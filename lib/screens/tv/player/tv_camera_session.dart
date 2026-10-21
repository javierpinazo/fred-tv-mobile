import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:open_tv/screens/tv/player/mpv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_camera.dart';
import 'package:open_tv/screens/tv/player/tv_engine.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';

enum TvCameraStatus { connecting, live, error }

/// Cámara de seguridad en el recuadro del reproductor: su propio mpv, aparte
/// del que reproduce el canal. Se conecta al mostrarla, se reconecta sola si
/// se corta y libera el decodificador al ocultarla.
class TvCameraSession extends ChangeNotifier {
  TvCameraSession({
    TvEngine Function()? engineFactory,
    Future<void> Function()? framePause,
    this.retryDelay = const Duration(seconds: 15),
    this.reconnectDelay = TvRetryPolicy.reconnectDelay,
  })  : _engineFactory = engineFactory ?? MpvEngine.new,
        _framePause =
            framePause ?? (() => WidgetsBinding.instance.endOfFrame);

  /// Espera antes de reintentar cuando no se pudo conectar.
  final Duration retryDelay;

  /// Espera antes de reconectar cuando la imagen se cortó.
  final Duration reconnectDelay;

  final TvEngine Function() _engineFactory;

  /// Deja salir del árbol el video viejo antes de liberar su motor.
  final Future<void> Function() _framePause;

  TvEngine? _engine;
  final List<StreamSubscription<dynamic>> _subs = [];
  List<TvPlaybackAttempt> _plan = const [];
  String? _url;
  int _generation = 0;
  int _currentAttempt = 0;
  bool _frameShown = false;
  bool _visible = false;
  bool _swapped = false;
  bool _disposed = false;
  TvCameraStatus _status = TvCameraStatus.connecting;
  TvCameraZoom _zoom = TvCameraZoom.none;
  Timer? _frameTimer;
  Timer? _stallTimer;
  Timer? _retryTimer;

  bool get visible => _visible;

  /// Dirección de la cámara mostrada (`null` si está oculta).
  String? get url => _visible ? _url : null;

  /// La cámara ocupa la pantalla grande y el canal pasa al recuadro.
  bool get swapped => _swapped;
  TvCameraStatus get status => _status;
  TvCameraZoom get zoom => _zoom;

  /// Video de la cámara; `null` mientras no hay motor.
  Widget? buildVideo() => _engine?.buildVideo(fill: false);

  // --- Mostrar / ocultar --------------------------------------------------

  Future<void> show(String url) async {
    if (_visible || _disposed) return;
    _visible = true;
    _swapped = false;
    _zoom = TvCameraZoom.none;
    _url = url;
    _plan = TvRetryPolicy.plan(url, mode: TvEngineMode.mpv);
    await _start(0);
  }

  Future<void> hide() async {
    if (!_visible) return;
    _visible = false;
    _swapped = false;
    _zoom = TvCameraZoom.none;
    _generation++;
    _cancelTimers();
    await _release();
    _notify();
  }

  void toggleSwap() {
    if (!_visible) return;
    _swapped = !_swapped;
    _notify();
  }

  /// Reintenta ya mismo si la cámara está sin señal.
  Future<void> retryNow() async {
    if (!_visible || _status != TvCameraStatus.error) return;
    _retryTimer?.cancel();
    await _start(0);
  }

  // --- Zoom ---------------------------------------------------------------

  void cycleZoom() {
    _zoom = _zoom.cycle();
    _notify();
  }

  void panZoom(double dx, double dy) {
    final next = _zoom.panBy(dx, dy);
    if (next == _zoom) return;
    _zoom = next;
    _notify();
  }

  // --- Conexión -----------------------------------------------------------

  Future<void> _start(int attempt) async {
    final generation = ++_generation;
    _currentAttempt = attempt;
    _cancelTimers();
    _frameShown = false;
    _status = TvCameraStatus.connecting;
    _notify();
    try {
      if (_engine == null) {
        final engine = _engineFactory();
        _engine = engine;
        _subs.addAll([
          engine.firstFrame.listen((_) => _onFirstFrame()),
          engine.errors.listen((e) => _onError(e)),
          engine.completed.listen((done) {
            if (done) _onStreamEnded();
          }),
        ]);
        _notify();
      }
      final plan = _plan[attempt];
      final timeout = TvRetryPolicy.firstFrameTimeout(plan);
      await _engine!
          .open(TvMedia(
            url: _url!,
            userAgent: tvFallbackUserAgent,
            // Poco buffer: una cámara se mira en directo, con el menor retraso.
            bufferSecs: 0,
            hardwareDecoding: plan.hardwareDecoding,
            mute: true,
          ))
          .timeout(timeout);
      if (generation != _generation) return;
      if (!_frameShown) {
        _frameTimer = Timer(timeout, () => _onFailure(generation, attempt));
      }
    } catch (e) {
      debugPrint('TvCameraSession: error abriendo la cámara: $e');
      if (generation == _generation) _onFailure(generation, attempt);
    }
  }

  void _onFirstFrame() {
    if (!_visible) return;
    _frameShown = true;
    _frameTimer?.cancel();
    if (_status != TvCameraStatus.live) {
      _status = TvCameraStatus.live;
      _notify();
    }
  }

  void _onError(String message) {
    debugPrint('TvCameraSession: error de mpv: $message');
    if (!_visible || _status == TvCameraStatus.error) return;
    final generation = _generation;
    if (_status == TvCameraStatus.connecting) {
      _onFailure(generation, _currentAttempt);
      return;
    }
    // Con imagen en pantalla mpv avisa de cortes sueltos que él mismo recupera:
    // solo se reconecta si la posición dejó de avanzar.
    final engine = _engine;
    if (engine == null || _stallTimer?.isActive == true) return;
    final before = engine.position;
    _stallTimer = Timer(TvRetryPolicy.stallCheckDelay, () {
      if (generation != _generation || !identical(engine, _engine)) return;
      if (engine.position <= before) _onFailure(generation, _currentAttempt);
    });
  }

  void _onStreamEnded() {
    if (!_visible || _status == TvCameraStatus.error) return;
    _onFailure(_generation, _currentAttempt);
  }

  /// Falló el intento [attempt]: prueba el siguiente (software tras hardware) o,
  /// si ya no quedan o la imagen se cortó estando en directo, espera y reconecta.
  void _onFailure(int generation, int attempt) {
    if (generation != _generation || !_visible) return;
    _cancelTimers();
    final wasLive = _status == TvCameraStatus.live;
    if (!wasLive && attempt + 1 < _plan.length) {
      _currentAttempt = attempt + 1;
      unawaited(_start(attempt + 1));
      return;
    }
    _currentAttempt = 0;
    _status = TvCameraStatus.error;
    _generation++;
    unawaited(_release().then((_) => _notify()));
    _notify();
    final delay = wasLive ? reconnectDelay : retryDelay;
    _retryTimer = Timer(delay, () {
      if (_visible && !_disposed) unawaited(_start(0));
    });
  }

  void _cancelTimers() {
    _frameTimer?.cancel();
    _stallTimer?.cancel();
    _retryTimer?.cancel();
  }

  /// Suelta el motor, dejando antes que su video salga del árbol.
  Future<void> _release() async {
    final old = _engine;
    final subs = List.of(_subs);
    _engine = null;
    _subs.clear();
    for (final s in subs) {
      await s.cancel();
    }
    if (old == null) return;
    _notify();
    await _framePause();
    await old.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _visible = false;
    _generation++;
    _cancelTimers();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _engine?.dispose();
    _engine = null;
    super.dispose();
  }
}
