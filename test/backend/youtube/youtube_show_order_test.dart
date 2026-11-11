import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/youtube/youtube_show_order.dart';

void main() {
  test('orden por canal', () {
    var raw = encodeYoutubeShowOrder(null, '/channel/UCa', ['x', 'y']);
    raw = encodeYoutubeShowOrder(raw, '/@b', ['z']);
    expect(decodeYoutubeShowOrder(raw, '/channel/UCa'), ['x', 'y']);
    expect(decodeYoutubeShowOrder(raw, '/@b'), ['z']);
    expect(decodeYoutubeShowOrder(raw, '/@otro'), isEmpty);
    expect(decodeYoutubeShowOrder(null, '/@b'), isEmpty);
    expect(decodeYoutubeShowOrder('', '/@b'), isEmpty);
  });

  test('volver a guardar un canal sustituye su orden', () {
    var raw = encodeYoutubeShowOrder(null, '/@b', ['x', 'y']);
    raw = encodeYoutubeShowOrder(raw, '/@b', ['y', 'x']);
    expect(decodeYoutubeShowOrder(raw, '/@b'), ['y', 'x']);
  });

  test('ajuste corrupto: se trata como vacío y el siguiente guardado lo repara',
      () {
    for (final bad in ['no json', '[1,2]', '{"/@b": "x"}', '7', 'null']) {
      expect(decodeYoutubeShowOrder(bad, '/@b'), isEmpty, reason: bad);
      expect(
          decodeYoutubeShowOrder(
              encodeYoutubeShowOrder(bad, '/@c', ['k']), '/@c'),
          ['k'],
          reason: bad);
    }
    expect(decodeYoutubeShowOrder('{"/@b": [1, "ok", null]}', '/@b'), ['ok']);
  });
}
