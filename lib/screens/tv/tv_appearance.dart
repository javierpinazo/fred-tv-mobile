import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

/// Tamaño de letra y alto contraste de la interfaz de TV.
abstract final class TvAppearance {
  static const List<double> scales = [1.0, 1.15, 1.3];

  /// Escala de texto vigente; la raíz de la app la aplica con `TextScaler`.
  static final ValueNotifier<double> textScale = ValueNotifier(1.0);

  /// Idioma forzado por el usuario; `null` = el del sistema.
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  static Locale? parseLocale(String? raw) =>
      raw == null || raw.isEmpty ? null : Locale(raw);

  /// Cambia cada vez que el contraste cambia: la raíz reconstruye todo el árbol
  /// (los colores se leen al construir cada widget).
  static final ValueNotifier<int> epoch = ValueNotifier(0);

  static double nextScale(double current) {
    final i = scales.indexOf(current);
    return i < 0 ? scales.first : scales[(i + 1) % scales.length];
  }

  static String scaleLabel(double scale) => '${(scale * 100).round()} %';

  static double parseScale(String? raw) {
    final v = double.tryParse(raw ?? '');
    return v != null && scales.contains(v) ? v : 1.0;
  }

  static void applyHighContrast(bool value) {
    if (TvTheme.highContrast == value) return;
    TvTheme.highContrast = value;
    epoch.value++;
  }
}
