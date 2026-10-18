import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/tv_retry_policy.dart';

void main() {
  test('primero decodificación por hardware, luego software', () {
    expect(TvRetryPolicy.attempts.first.hardwareDecoding, isTrue);
    expect(TvRetryPolicy.next(0)!.hardwareDecoding, isFalse);
    expect(TvRetryPolicy.next(1), isNull);
  });

  test('constantes de la política', () {
    expect(TvRetryPolicy.firstFrameTimeout, const Duration(seconds: 15));
    expect(TvRetryPolicy.maxLiveReconnects, 3);
    expect(TvRetryPolicy.reconnectDelay, const Duration(seconds: 2));
    expect(tvFallbackUserAgent, 'VLC/3.0.21 LibVLC/3.0.21');
  });
}
