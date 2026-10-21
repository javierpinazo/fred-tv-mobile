import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/backend/countries.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/screens/tv/tv_appearance.dart';
import 'package:open_tv/screens/tv/tv_settings.dart';

import 'fakes.dart';

const _langs = ['es', 'en', 'pt', 'fr', 'de', 'it'];

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Marcadores `{nombre}` de un mensaje (los de las ramas de un plural, como
/// `{1 resultado}`, no cuentan porque no son identificadores).
Set<String> _placeholders(String message) => RegExp(r'\{([A-Za-z_]\w*)(?=[},])')
    .allMatches(message)
    .map((m) => m.group(1)!)
    .where((n) => n != 'other')
    .toSet();

void main() {
  group('archivos .arb', () {
    final es = _arb('es');
    final keys = es.keys.where((k) => !k.startsWith('@')).toSet();

    for (final lang in _langs.skip(1)) {
      test('$lang tiene exactamente las claves de es', () {
        final other = _arb(lang);
        final otherKeys = other.keys.where((k) => !k.startsWith('@')).toSet();
        expect(keys.difference(otherKeys), isEmpty, reason: 'faltan en $lang');
        expect(otherKeys.difference(keys), isEmpty, reason: 'sobran en $lang');
      });

      test('$lang usa los mismos marcadores que es', () {
        final other = _arb(lang);
        for (final k in keys.where((k) => k != '@@locale')) {
          expect(_placeholders(other[k] as String), _placeholders(es[k] as String),
              reason: '$lang.$k');
        }
      });
    }

    test('ningún texto está vacío', () {
      for (final lang in _langs) {
        final arb = _arb(lang);
        for (final e in arb.entries.where((e) => !e.key.startsWith('@'))) {
          expect((e.value as String).trim(), isNotEmpty, reason: '$lang.${e.key}');
        }
      }
    });
  });

  group('idioma', () {
    const supported = [Locale('es'), Locale('en'), Locale('pt')];

    test('sigue el del sistema por idioma, sin mirar el país', () {
      expect(resolveAppLocale(const Locale('es', 'PE'), supported).languageCode, 'es');
      expect(resolveAppLocale(const Locale('pt', 'BR'), supported).languageCode, 'pt');
    });

    test('si no está traducido, inglés', () {
      expect(resolveAppLocale(const Locale('ja'), supported), fallbackLocale);
      expect(resolveAppLocale(null, supported), fallbackLocale);
    });

    test('los seis idiomas están disponibles', () {
      expect(AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
          _langs.toSet());
      expect(languageNativeNames.keys.toSet(), _langs.toSet());
    });

    test('parseLocale', () {
      expect(TvAppearance.parseLocale(null), isNull);
      expect(TvAppearance.parseLocale(''), isNull);
      expect(TvAppearance.parseLocale('en'), const Locale('en'));
    });
  });

  group('países', () {
    test('se traducen por idioma y, sin traducción, caen al español', () {
      expect(countryName('pe'), 'Perú');
      expect(countryName('pe', lang: 'en'), 'Peru');
      expect(countryName('de', lang: 'fr'), 'Allemagne');
      expect(countryName('de', lang: 'xx'), 'Alemania');
      expect(countryName('zz', lang: 'en'), 'ZZ');
    });

    test('todos los países tienen nombre en cada idioma', () {
      for (final code in countryNames.keys) {
        for (final lang in _langs.skip(1)) {
          expect(countryName(code, lang: lang), isNot(code.toUpperCase()),
              reason: '$lang.$code');
        }
      }
    });
  });

  group('plurales', () {
    test('singular y plural en cada idioma', () {
      for (final lang in _langs) {
        final l = lookupAppLocalizations(Locale(lang));
        expect(l.searchStatusResults(1), isNot(contains('1 results')));
        expect(l.searchStatusResults(5), contains('5'));
        expect(l.playlistChannelCount(1), isNot(equals(l.playlistChannelCount(2))));
      }
      final es = lookupAppLocalizations(const Locale('es'));
      expect(es.searchStatusResults(1), '1 resultado');
      expect(es.searchStatusResults(2), '2 resultados');
    });
  });

  group('Ajustes', () {
    Future<void> pumpApp(WidgetTester t, FakeTvData data) async {
      t.view.physicalSize = const Size(1920, 1080);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      TvAppearance.locale.value = const Locale('es');
      addTearDown(() => TvAppearance.locale.value = null);
      await t.pumpWidget(ValueListenableBuilder<Locale?>(
        valueListenable: TvAppearance.locale,
        builder: (_, locale, __) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TVSettings(data: data)),
        ),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('elegir un idioma lo guarda y traduce la pantalla', (t) async {
      final data = FakeTvData();
      await pumpApp(t, data);
      await focusKey(t, 'tv-settings-language');
      expect(find.text('Idioma'), findsWidgets);
      expect(find.text('Automático (sistema)'), findsOneWidget);

      await t.sendKeyDownEvent(LogicalKeyboardKey.select);
      await t.sendKeyUpEvent(LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      // Opciones: Automático, Español, English, ...
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      await t.sendKeyDownEvent(LogicalKeyboardKey.select);
      await t.sendKeyUpEvent(LogicalKeyboardKey.select);
      await t.pumpAndSettle();

      expect(data.language, 'en');
      expect(TvAppearance.locale.value, const Locale('en'));
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Idioma'), findsNothing);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Security camera'), findsOneWidget);
      expect(find.text('Cámara de seguridad'), findsNothing);
    });

    for (final lang in _langs) {
      testWidgets('se dibuja en $lang sin errores', (t) async {
        await pumpApp(t, FakeTvData());
        TvAppearance.locale.value = Locale(lang);
        await t.pumpAndSettle();
        final l10n = lookupAppLocalizations(Locale(lang));
        expect(find.text(l10n.settingsAddFromIptvOrg), findsOneWidget);
        await focusKey(t, 'tv-settings-language');
        expect(find.text(l10n.settingsLanguage), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  });
}
