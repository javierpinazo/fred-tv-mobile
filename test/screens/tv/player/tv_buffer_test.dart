import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/tv_buffer.dart';
import 'package:open_tv/l10n/gen/app_localizations_es.dart';

void main() {
  test('opciones disponibles y valor por defecto', () {
    expect(TvBuffer.options, [0, 2, 5, 10]);
    expect(TvBuffer.defaultSeconds, 2);
  });

  test('2 s: espera 2 s al arrancar y al recuperarse, y lee por adelantado', () {
    final o = TvBuffer.mpvOptions(2);
    expect(o['cache'], 'yes');
    expect(o['cache-pause'], 'yes');
    expect(o['cache-pause-initial'], 'yes');
    expect(o['cache-pause-wait'], '2');
    expect(o['demuxer-readahead-secs'], '6');
    expect(int.parse(o['demuxer-max-bytes']!), greaterThanOrEqualTo(32 * 1024 * 1024));
  });

  test('el colchón de lectura crece con los segundos', () {
    expect(TvBuffer.mpvOptions(5)['demuxer-readahead-secs'], '15');
    expect(TvBuffer.mpvOptions(10)['demuxer-readahead-secs'], '30');
    expect(TvBuffer.mpvOptions(10)['cache-pause-wait'], '10');
  });

  test('desactivado: sin espera inicial y reanuda enseguida', () {
    final o = TvBuffer.mpvOptions(0);
    expect(o['cache-pause-initial'], 'no');
    expect(o['cache-pause-wait'], '1');
  });

  test('etiquetas', () {
    expect(TvBuffer.label(0, AppLocalizationsEs()), 'Desactivado');
    expect(TvBuffer.label(2, AppLocalizationsEs()), '2 s');
    expect(TvBuffer.label(10, AppLocalizationsEs()), '10 s');
  });

  test('siguiente valor da la vuelta', () {
    expect(TvBuffer.next(0), 2);
    expect(TvBuffer.next(2), 5);
    expect(TvBuffer.next(5), 10);
    expect(TvBuffer.next(10), 0);
    expect(TvBuffer.next(7), 2, reason: 'valor desconocido → por defecto');
  });
}
