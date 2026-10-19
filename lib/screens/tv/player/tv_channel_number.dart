/// Dígitos tecleados con el control para saltar a un número de canal.
class TvChannelNumberBuffer {
  static const int maxDigits = 4;

  /// Tras este tiempo sin pulsar otro dígito se confirma el número.
  static const Duration timeout = Duration(milliseconds: 1500);

  String _digits = '';

  bool get isEmpty => _digits.isEmpty;
  String get value => _digits;

  void add(int digit) {
    if (_digits.length >= maxDigits) return;
    _digits += '$digit';
  }

  void clear() => _digits = '';

  /// Índice (base 0) del canal pedido, o `null` si el número no existe en una
  /// lista de [count] canales.
  int? resolve(int count) {
    final n = int.tryParse(_digits);
    if (n == null || n < 1 || n > count) return null;
    return n - 1;
  }
}
