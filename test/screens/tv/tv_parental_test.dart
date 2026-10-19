import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/tv_parental.dart';

void main() {
  group('sha256', () {
    test('vectores de prueba oficiales', () {
      expect(sha256Hex(''),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(sha256Hex('abc'),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(
          sha256Hex(
              'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
          '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
    });

    test('UTF-8 y mensajes de varios bloques', () {
      expect(sha256Hex('áéíóú'),
          'cdfab900629099e3849d71299159850f4efde07c77e95c41c1185dcb728a8bd9');
      expect(sha256Hex('a' * 1000),
          '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3');
    });
  });

  group('TvParental', () {
    test('un PIN válido son 4 dígitos', () {
      expect(TvParental.isValidPin('1234'), isTrue);
      expect(TvParental.isValidPin('0000'), isTrue);
      expect(TvParental.isValidPin('123'), isFalse);
      expect(TvParental.isValidPin('12345'), isFalse);
      expect(TvParental.isValidPin('12a4'), isFalse);
      expect(TvParental.isValidPin(''), isFalse);
    });

    test('encode/verify: el PIN correcto valida y el incorrecto no', () {
      final stored = TvParental.encode('4821');
      expect(TvParental.verify('4821', stored), isTrue);
      expect(TvParental.verify('4822', stored), isFalse);
      expect(TvParental.verify('', stored), isFalse);
    });

    test('lo guardado no contiene el PIN en claro y lleva sal', () {
      final a = TvParental.encode('4821');
      final b = TvParental.encode('4821');
      expect(a, isNot(contains('4821')));
      expect(a, isNot(equals(b))); // sal distinta
      expect(TvParental.verify('4821', a), isTrue);
      expect(TvParental.verify('4821', b), isTrue);
    });

    test('un valor guardado corrupto nunca valida', () {
      expect(TvParental.verify('4821', ''), isFalse);
      expect(TvParental.verify('4821', 'sin-separador'), isFalse);
      expect(TvParental.verify('4821', null), isFalse);
    });
  });
}
