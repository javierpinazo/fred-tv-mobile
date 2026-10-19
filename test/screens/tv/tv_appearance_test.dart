import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/screens/tv/tv_appearance.dart';
import 'package:open_tv/screens/tv/widgets/tv_theme.dart';

void main() {
  tearDown(() => TvAppearance.applyHighContrast(false));

  test('el tamaño de letra rota 100 → 115 → 130 → 100 %', () {
    expect(TvAppearance.nextScale(1.0), 1.15);
    expect(TvAppearance.nextScale(1.15), 1.3);
    expect(TvAppearance.nextScale(1.3), 1.0);
    expect(TvAppearance.nextScale(0.5), 1.0); // valor desconocido
  });

  test('etiqueta del tamaño', () {
    expect(TvAppearance.scaleLabel(1.0), '100 %');
    expect(TvAppearance.scaleLabel(1.15), '115 %');
    expect(TvAppearance.scaleLabel(1.3), '130 %');
  });

  test('lee el tamaño guardado y rechaza valores fuera de la lista', () {
    expect(TvAppearance.parseScale('1.3'), 1.3);
    expect(TvAppearance.parseScale('1.15'), 1.15);
    expect(TvAppearance.parseScale(null), 1.0);
    expect(TvAppearance.parseScale('2.5'), 1.0);
    expect(TvAppearance.parseScale('abc'), 1.0);
  });

  test('alto contraste: texto secundario más claro y borde de foco más grueso',
      () {
    final normalText = TvTheme.textSecondary;
    final normalWidth = TvTheme.focusBorderWidth;
    TvAppearance.applyHighContrast(true);
    expect(TvTheme.highContrast, isTrue);
    expect(TvTheme.textSecondary.computeLuminance(),
        greaterThan(normalText.computeLuminance()));
    expect(TvTheme.focusBorderWidth, greaterThan(normalWidth));
    TvAppearance.applyHighContrast(false);
    expect(TvTheme.textSecondary, normalText);
    expect(TvTheme.focusBorderWidth, normalWidth);
  });

  test('cambiar el contraste fuerza reconstruir la interfaz', () {
    final before = TvAppearance.epoch.value;
    TvAppearance.applyHighContrast(true);
    expect(TvAppearance.epoch.value, before + 1);
    TvAppearance.applyHighContrast(true); // sin cambio: no reconstruye
    expect(TvAppearance.epoch.value, before + 1);
  });
}
