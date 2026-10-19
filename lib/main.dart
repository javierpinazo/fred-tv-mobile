import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:open_tv/backend/settings_service.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/utils.dart';
import 'package:open_tv/home.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/settings.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/setup.dart';
import 'package:open_tv/screens/tv/tv_appearance.dart';
import 'package:open_tv/screens/tv/tv_bootstrap.dart';
import 'package:open_tv/screens/tv/tv_data.dart';
import 'package:media_kit/media_kit.dart';

/// Detecta si la app corre en un Android TV (UiMode televisión o leanback).
///
/// Para forzar el modo TV en un teléfono:
/// `flutter run --dart-define=FORCE_TV=true`.
class PlatformDetector {
  static const MethodChannel channel =
      MethodChannel('dev.fredol.open_tv/device');

  static const bool _forceTv = bool.fromEnvironment('FORCE_TV');

  static bool defaultIsAndroid() => !kIsWeb && Platform.isAndroid;

  /// Reemplazable en tests.
  static bool Function() isAndroidPlatform = defaultIsAndroid;

  static bool _isTv = false;

  static Future<void> init() async {
    _isTv = false;
    if (!isAndroidPlatform()) return;
    try {
      _isTv = (await channel.invokeMethod<bool>('isTv')) ?? false;
    } catch (e) {
      debugPrint('PlatformDetector: no se pudo consultar isTv: $e');
      _isTv = false;
    }
  }

  static bool get isAndroidTV => _forceTv || _isTv;

  static bool get isMobile => !isAndroidTV;
}

Future<void> _loadDefaultM3USource() async {
  try {
    // Crear la fuente con la lista M3U de IPTV-org en español
    final defaultSource = Source(
      name: "IPTV Español",
      url: "https://iptv-org.github.io/iptv/languages/spa.m3u",
      sourceType: SourceType.m3uUrl,
      enabled: true,
    );

    // Procesar la fuente (esto la descarga y la agrega a la base de datos)
    await Utils.processSource(defaultSource);
    print("Lista M3U predeterminada cargada exitosamente");
  } catch (e) {
    print("Error al cargar la lista M3U predeterminada: $e");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await PlatformDetector.init();

  // Android TV: orientación horizontal y arranque inmediato; la lista por
  // defecto se descarga con una pantalla de carga (TvBootstrap).
  if (PlatformDetector.isAndroidTV) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final data = const TvData();
    TvAppearance.textScale.value = await data.textScaleSetting();
    TvAppearance.applyHighContrast(await data.highContrastSetting());
    runApp(MyApp(skipSetup: true, settings: Settings(), isTv: true));
    return;
  }

  var hasSources = await Sql.hasSources();
  final settings = await SettingsService.getSettings();

  // Si no hay fuentes, cargar la lista M3U predeterminada
  if (!hasSources) {
    await _loadDefaultM3USource();
    hasSources = true; // Ya tenemos una fuente ahora
  }

  runApp(MyApp(
    skipSetup: hasSources,
    settings: settings,
  ));
}

class MyApp extends StatelessWidget {
  final bool skipSetup;
  final Settings settings;
  final bool isTv;
  const MyApp({
    super.key,
    required this.skipSetup,
    required this.settings,
    this.isTv = false,
  });

  @override
  Widget build(BuildContext context) {
    final app = _buildApp();
    if (!isTv) return app;
    // Tamaño de letra (sin reconstruir) y alto contraste (reconstruye todo el
    // árbol porque los colores se leen al construir cada widget).
    return ValueListenableBuilder<int>(
      valueListenable: TvAppearance.epoch,
      builder: (context, epoch, _) => KeyedSubtree(
        key: ValueKey(epoch),
        child: _buildApp(),
      ),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'Fred TV',
      builder: isTv
          ? (context, child) => ValueListenableBuilder<double>(
                valueListenable: TvAppearance.textScale,
                builder: (context, scale, _) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              )
          : null,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: isTv ? ThemeMode.dark : ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: isTv
          ? const TvBootstrap() // Interfaz para Android TV
          : (skipSetup
              ? Home(
                  firstLaunch: true,
                  refresh: settings.refreshOnStart,
                  home: HomeManager(
                      filters: Filters(
                    viewType: settings.defaultView,
                  )))
              : const Setup()),
    );
  }
}
