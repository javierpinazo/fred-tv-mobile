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

  test('otras URLs no llevan opciones extra', () {
    expect(mpvUrlOptions('http://x.test/stream.ts'), isEmpty);
    expect(mpvUrlOptions('rtmp://x.test/live'), isEmpty);
  });
}
