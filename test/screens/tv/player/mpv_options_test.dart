import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/mpv_engine.dart';

void main() {
  test('HLS desactiva las conexiones persistentes (servidores que las cortan)',
      () {
    expect(mpvUrlOptions('https://x.test/a/index.m3u8'),
        {'demuxer-lavf-o': 'http_persistent=0'});
    expect(mpvUrlOptions('http://x.test/a/INDEX.M3U8?token=1'),
        {'demuxer-lavf-o': 'http_persistent=0'});
  });

  test('hwdec según el intento: automático, sin copia o software', () {
    expect(mpvHwdecFor(zeroCopy: false, hardwareDecoding: true), 'auto-safe');
    expect(mpvHwdecFor(zeroCopy: false, hardwareDecoding: false), 'no');
    expect(mpvHwdecFor(zeroCopy: true, hardwareDecoding: true), 'mediacodec');
    // Sin copia nunca se activa con la decodificación por software.
    expect(mpvHwdecFor(zeroCopy: true, hardwareDecoding: false), 'no');
  });

  test('RTSP va por TCP (cámaras de seguridad)', () {
    expect(mpvUrlOptions('rtsp://192.168.1.20/stream1'),
        {'demuxer-lavf-o': 'rtsp_transport=tcp'});
    expect(mpvUrlOptions('RTSP://cam.test/stream'),
        {'demuxer-lavf-o': 'rtsp_transport=tcp'});
  });

  test('otras URLs no llevan opciones extra', () {
    expect(mpvUrlOptions('http://x.test/stream.ts'), isEmpty);
    expect(mpvUrlOptions('rtmp://x.test/live'), isEmpty);
  });
}
