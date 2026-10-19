import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/player/tv_channel_number.dart';

void main() {
  test('junta los dígitos tecleados', () {
    final b = TvChannelNumberBuffer();
    expect(b.isEmpty, isTrue);
    b.add(1);
    b.add(2);
    expect(b.value, '12');
    expect(b.isEmpty, isFalse);
  });

  test('máximo 4 dígitos: el quinto se ignora', () {
    final b = TvChannelNumberBuffer();
    for (final d in [1, 2, 3, 4, 5]) {
      b.add(d);
    }
    expect(b.value, '1234');
  });

  test('resolve devuelve el índice base 0 si el número existe', () {
    final b = TvChannelNumberBuffer()..add(1)..add(2);
    expect(b.resolve(30), 11);
    expect(b.resolve(12), 11);
    expect(b.resolve(11), isNull); // fuera de rango
  });

  test('ceros a la izquierda y el 0 solo no son un canal', () {
    final b = TvChannelNumberBuffer()..add(0);
    expect(b.resolve(10), isNull);
    b.add(5);
    expect(b.resolve(10), 4); // "05" = canal 5
  });

  test('clear vacía el buffer y el tiempo de espera es de 1,5 s', () {
    final b = TvChannelNumberBuffer()..add(9);
    b.clear();
    expect(b.isEmpty, isTrue);
    expect(b.resolve(10), isNull);
    expect(TvChannelNumberBuffer.timeout, const Duration(milliseconds: 1500));
  });
}
