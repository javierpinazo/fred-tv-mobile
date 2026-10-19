import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/screens/tv/player/hls_probe.dart';

void main() {
  group('hlsDropsAudio', () {
    test('CODECS solo con video: ExoPlayer descartaría el audio', () {
      const body = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=6750000,CODECS="avc1.640029"\n'
          'tracks-v1a1/mono.ts.m3u8\n';
      expect(hlsDropsAudio(body), isTrue);
    });

    test('CODECS con video y audio: es seguro', () {
      const body = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1480000,CODECS="avc1.64001f,mp4a.40.2"\n'
          'a.m3u8\n';
      expect(hlsDropsAudio(body), isFalse);
    });

    test('sin CODECS: ExoPlayer sondea el stream, es seguro', () {
      const body = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=2841000\n'
          'a.m3u8\n';
      expect(hlsDropsAudio(body), isFalse);
    });

    test('audio en un grupo aparte (EXT-X-MEDIA) es seguro', () {
      const body = '#EXTM3U\n'
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",URI="audio.m3u8"\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.640029",AUDIO="a"\n'
          'v.m3u8\n';
      expect(hlsDropsAudio(body), isFalse);
    });

    test('lista de medios (no maestra) es segura', () {
      const body = '#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nseg.ts\n';
      expect(hlsDropsAudio(body), isFalse);
    });

    test('ac-3 y ec-3 cuentan como audio', () {
      const body = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.640029,ec-3"\n'
          'a.m3u8\n';
      expect(hlsDropsAudio(body), isFalse);
    });
  });

  group('exoWouldDropAudio', () {
    const solo = '#EXTM3U\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.640029"\nv.m3u8\n';

    test('descarga el manifiesto con el User-Agent y detecta video sin audio',
        () async {
      String? ua;
      final client = MockClient((req) async {
        ua = req.headers['User-Agent'];
        return http.Response(solo, 200);
      });
      final r = await exoWouldDropAudio('https://x.test/a/index.m3u8',
          userAgent: 'UA-TEST', client: client);
      expect(r, isTrue);
      expect(ua, 'UA-TEST');
    });

    test('una URL que no es .m3u8 no se descarga', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(solo, 200);
      });
      expect(
          await exoWouldDropAudio('https://x.test/video.mp4',
              userAgent: 'UA', client: client),
          isFalse);
      expect(calls, 0);
    });

    test('si falla la descarga no bloquea ExoPlayer', () async {
      final client = MockClient((req) async => throw http.ClientException('x'));
      expect(
          await exoWouldDropAudio('https://x.test/a.m3u8',
              userAgent: 'UA', client: client),
          isFalse);
    });

    test('una respuesta 404 no bloquea ExoPlayer', () async {
      final client = MockClient((req) async => http.Response('no', 404));
      expect(
          await exoWouldDropAudio('https://x.test/a.m3u8',
              userAgent: 'UA', client: client),
          isFalse);
    });
  });
}
