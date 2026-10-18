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
import 'package:open_tv/screens/tv/tv_home.dart';

// Detector de Android TV
// Detector de Android TV
class PlatformDetector {
  // Cambia esto a true para forzar el modo TV en móviles para pruebas
  static const bool _forceTVMode = true;

  static bool get isAndroidTV {
    if (kIsWeb) return false;

    // Si estamos forzando modo TV
    if (_forceTVMode) return true;

    // TODO: Implementar detección real usando device_info_plus
    // androidInfo.systemFeatures.contains('android.software.leanback')

    return false;
  }

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

  // Si detectamos Android TV, forzamos orientación landscape
  if (PlatformDetector.isAndroidTV) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
  const MyApp({super.key, required this.skipSetup, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fred TV',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,

      // Aquí decidimos qué interfaz mostrar
      home: PlatformDetector.isAndroidTV
          ? const TVHome() // Interfaz para Android TV
          : (skipSetup     // Tu lógica original para móvil
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