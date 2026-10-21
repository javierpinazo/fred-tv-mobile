import 'package:flutter/widgets.dart';
import 'package:open_tv/l10n/gen/app_localizations.dart';

export 'package:open_tv/l10n/gen/app_localizations.dart';

extension AppL10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Idioma de respaldo cuando el del sistema no está traducido.
const Locale fallbackLocale = Locale('en');

/// Elige el idioma de la app: el del sistema si está traducido (por idioma,
/// sin mirar el país) y, si no, inglés.
Locale resolveAppLocale(Locale? device, Iterable<Locale> supported) {
  if (device != null) {
    for (final l in supported) {
      if (l.languageCode == device.languageCode) return l;
    }
  }
  return fallbackLocale;
}

/// Idiomas que el usuario puede forzar en Ajustes, con su nombre propio (no se
/// traduce: cada uno se reconoce en su idioma).
const Map<String, String> languageNativeNames = {
  'es': 'Español',
  'en': 'English',
  'pt': 'Português',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
};
