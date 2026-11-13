import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/tv_channel_label.dart';

void check(String name, String title, String? quality) {
  final l = tvChannelLabel(name);
  expect((l.title, l.quality), (title, quality), reason: name);
}

void main() {
  test('separa la calidad y quita las etiquetas entre corchetes', () {
    check('3ABN Latino (1080p)', '3ABN Latino', '1080p');
    check('4Dmas Noticias TV (1080p) [Not 24/7]', '4Dmas Noticias TV', '1080p');
    check('Adult Swim West [Not 24/7;Geo-blocked]', 'Adult Swim West', null);
    check('Canal (576i)', 'Canal', '576i');
  });

  test('no toca lo que no es calidad ni etiqueta', () {
    check('5tv', '5tv', null);
    check('Canal (Perú)', 'Canal (Perú)', null);
  });

  test('si no queda nada conserva el nombre original', () {
    check('[Test]', '[Test]', null);
  });
}
