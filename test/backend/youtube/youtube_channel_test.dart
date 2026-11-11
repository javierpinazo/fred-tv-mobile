import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/youtube/youtube_channel.dart';

void main() {
  test('reconoce direcciones de canal', () {
    for (final u in [
      'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg',
      'https://youtube.com/@curwen',
      'http://m.youtube.com/@PaoloBenzaR/',
      'https://www.youtube.com/@leonmoya/videos',
    ]) {
      expect(isYoutubeChannelUrl(u), isTrue, reason: u);
    }
    for (final u in [
      null,
      '',
      'https://www.youtube.com/watch?v=Ejg0OQPYVgw',
      'https://youtu.be/Ejg0OQPYVgw',
      'https://www.youtube.com/',
      'https://www.youtube.com/channel/',
      'https://www.youtube.com/channel/PLabc',
      'https://www.youtube.com/@',
      'https://example.com/@curwen',
      'rtsp://192.168.1.251/1/h264major',
    ]) {
      expect(isYoutubeChannelUrl(u), isFalse, reason: '$u');
    }
  });

  test('construye la dirección de cada pestaña', () {
    expect(
        youtubeTabUri('http://m.youtube.com/@PaoloBenzaR/videos',
                YoutubeTab.streams)
            .toString(),
        'https://www.youtube.com/@PaoloBenzaR/streams?hl=es');
    expect(
        youtubeTabUri(
                'https://www.youtube.com/channel/UC-B7Xv56uNRDkj0vC3QW8Cg',
                YoutubeTab.videos)
            .toString(),
        'https://www.youtube.com/channel/UC-B7Xv56uNRDkj0vC3QW8Cg/videos?hl=es');
  });

  test('una dirección que no es de canal no tiene pestañas', () {
    expect(
        () => youtubeTabUri(
            'https://www.youtube.com/watch?v=Ejg0OQPYVgw', YoutubeTab.videos),
        throwsArgumentError);
  });
}
