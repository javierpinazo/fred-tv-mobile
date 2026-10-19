import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';

List<(TvEngineKind, bool)> _p(List<TvPlaybackAttempt> plan) =>
    plan.map((a) => (a.engine, a.hardwareDecoding)).toList();

void main() {
  group('plan', () {
    test('http/https: ExoPlayer primero y mpv de respaldo (hardware y software)',
        () {
      const expected = [
        (TvEngineKind.exo, true),
        (TvEngineKind.mpv, true),
        (TvEngineKind.mpv, false),
      ];
      expect(_p(TvRetryPolicy.plan('http://a/b.m3u8')), expected);
      expect(_p(TvRetryPolicy.plan('HTTPS://a/b.mpd')), expected);
    });

    test('otros protocolos van directo a mpv', () {
      const expected = [(TvEngineKind.mpv, true), (TvEngineKind.mpv, false)];
      for (final u in [
        'rtmp://a/b',
        'udp://@239.1.1.1:1234',
        'rtsp://a/b',
        'mms://a/b',
        'srt://a:9',
        '/sdcard/x.mp4',
      ]) {
        expect(_p(TvRetryPolicy.plan(u)), expected, reason: u);
      }
    });

    test('modo "solo mpv" nunca usa ExoPlayer', () {
      expect(
        _p(TvRetryPolicy.plan('http://a/b.m3u8', mode: TvEngineMode.mpv)),
        [(TvEngineKind.mpv, true), (TvEngineKind.mpv, false)],
      );
    });

    test('prefer cambia el motor para este canal', () {
      expect(
        _p(TvRetryPolicy.plan('http://a/b', prefer: TvEngineKind.mpv)),
        [(TvEngineKind.mpv, true), (TvEngineKind.mpv, false)],
      );
      expect(
        _p(TvRetryPolicy.plan('http://a/b',
            mode: TvEngineMode.mpv, prefer: TvEngineKind.exo)),
        [
          (TvEngineKind.exo, true),
          (TvEngineKind.mpv, true),
          (TvEngineKind.mpv, false),
        ],
      );
      expect(
        _p(TvRetryPolicy.plan('rtmp://a/b', prefer: TvEngineKind.exo)),
        [(TvEngineKind.mpv, true), (TvEngineKind.mpv, false)],
        reason: 'ExoPlayer no abre rtmp',
      );
    });
  });

  test('next devuelve el siguiente intento o null', () {
    final plan = TvRetryPolicy.plan('http://a/b');
    expect(TvRetryPolicy.next(plan, 0)!.engine, TvEngineKind.mpv);
    expect(TvRetryPolicy.next(plan, 0)!.hardwareDecoding, isTrue);
    expect(TvRetryPolicy.next(plan, 1)!.hardwareDecoding, isFalse);
    expect(TvRetryPolicy.next(plan, 2), isNull);
  });

  test('tiempos y constantes', () {
    const exo = TvPlaybackAttempt(engine: TvEngineKind.exo);
    const mpv = TvPlaybackAttempt(engine: TvEngineKind.mpv);
    expect(TvRetryPolicy.firstFrameTimeout(exo), const Duration(seconds: 10));
    expect(TvRetryPolicy.firstFrameTimeout(mpv), const Duration(seconds: 15));
    expect(TvRetryPolicy.maxLiveReconnects, 3);
    expect(TvRetryPolicy.reconnectDelay, const Duration(seconds: 2));
    expect(tvFallbackUserAgent, 'VLC/3.0.21 LibVLC/3.0.21');
  });

  test('etiquetas de motor y modo', () {
    expect(TvEngineKind.exo.label, 'ExoPlayer');
    expect(TvEngineKind.mpv.label, 'mpv');
    expect(TvEngineMode.auto.label, 'Automático');
    expect(TvEngineMode.mpv.label, 'Solo mpv');
  });

  test('modo: alternar y leer desde texto', () {
    expect(TvEngineMode.auto.next, TvEngineMode.mpv);
    expect(TvEngineMode.mpv.next, TvEngineMode.auto);
    expect(TvEngineMode.fromName('mpv'), TvEngineMode.mpv);
    expect(TvEngineMode.fromName('auto'), TvEngineMode.auto);
    expect(TvEngineMode.fromName(null), TvEngineMode.auto);
    expect(TvEngineMode.fromName('zzz'), TvEngineMode.auto);
  });
}
