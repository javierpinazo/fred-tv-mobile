import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_tv/screens/tv/player/hls_audio_fix.dart';
import 'package:open_tv/screens/tv/player/hls_probe.dart';

const _soloVideo = '#EXTM3U\n'
    '#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=5410000,BANDWIDTH=6750000,'
    'RESOLUTION=1920x1080,CODECS="avc1.640029",CLOSED-CAPTIONS=NONE\n'
    'tracks-v1a1/mono.ts.m3u8\n';

void main() {
  group('hlsAddAudioCodec', () {
    final base = Uri.parse('https://iptv.test/CANAL/index.m3u8');

    test('añade el códec de audio y vuelve absoluta la variante', () {
      final out = hlsAddAudioCodec(_soloVideo, base);
      expect(out, contains('CODECS="avc1.640029,mp4a.40.2"'));
      expect(out,
          contains('\nhttps://iptv.test/CANAL/tracks-v1a1/mono.ts.m3u8'));
      expect(hlsDropsAudio(out), isFalse);
    });

    test('no toca un CODECS que ya trae audio', () {
      const body = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.64001f,mp4a.40.2"\n'
          'a.m3u8\n';
      final out = hlsAddAudioCodec(body, base);
      expect(out, contains('CODECS="avc1.64001f,mp4a.40.2"'));
      expect(out, isNot(contains('mp4a.40.2,mp4a.40.2')));
    });

    test('las URI absolutas se respetan y las de atributos se resuelven', () {
      const body = '#EXTM3U\n'
          '#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=1,URI="iframe.m3u8"\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.640029"\n'
          'http://otro.test/v.m3u8\n';
      final out = hlsAddAudioCodec(body, base);
      expect(out, contains('URI="https://iptv.test/CANAL/iframe.m3u8"'));
      expect(out, contains('\nhttp://otro.test/v.m3u8'));
    });

    test('conserva los fines de línea CRLF sin duplicar retornos', () {
      final out = hlsAddAudioCodec(_soloVideo.replaceAll('\n', '\r\n'), base);
      expect(out, isNot(contains('\r\r')));
      expect(out, contains('mp4a.40.2'));
    });
  });

  group('HlsAudioFix.prepare', () {
    test('devuelve null si el manifiesto ya declara audio', () async {
      final client = MockClient((_) async => http.Response(
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.64001f,mp4a.40.2"\na.m3u8\n',
          200));
      expect(
          await HlsAudioFix.prepare('https://x.test/i.m3u8',
              userAgent: 'UA', client: client),
          isNull);
    });

    test('devuelve null si no se puede descargar', () async {
      final client = MockClient((_) async => http.Response('no', 500));
      expect(
          await HlsAudioFix.prepare('https://x.test/i.m3u8',
              userAgent: 'UA', client: client),
          isNull);
    });

    test('sirve en 127.0.0.1 el manifiesto corregido y se cierra', () async {
      var origin = 0;
      final client = MockClient((_) async {
        origin++;
        return http.Response(_soloVideo, 200);
      });
      final fix = await HlsAudioFix.prepare(
          'https://iptv.test/CANAL/index.m3u8',
          userAgent: 'UA',
          client: client);
      expect(fix, isNotNull);
      expect(fix!.url, startsWith('http://127.0.0.1:'));

      final local = http.Client();
      final res = await local.get(Uri.parse(fix.url));
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], contains('mpegurl'));
      expect(res.body, contains('CODECS="avc1.640029,mp4a.40.2"'));
      expect(res.body,
          contains('https://iptv.test/CANAL/tracks-v1a1/mono.ts.m3u8'));
      expect(origin, greaterThanOrEqualTo(2)); // prepare + petición local

      await fix.close();
      await expectLater(local.get(Uri.parse(fix.url)), throwsA(anything));
      local.close();
    });

    test('si el origen falla después, sirve la última versión corregida',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response(_soloVideo, 200)
            : http.Response('error', 503);
      });
      final fix = await HlsAudioFix.prepare('https://iptv.test/C/index.m3u8',
          userAgent: 'UA', client: client);
      final local = http.Client();
      final res = await local.get(Uri.parse(fix!.url));
      expect(res.statusCode, 200);
      expect(res.body, contains('mp4a.40.2'));
      await fix.close();
      local.close();
    });
  });
}
