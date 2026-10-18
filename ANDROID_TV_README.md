# Fred TV - Guía de Android TV

## Compatibilidad con Android TV

Fred TV ahora es totalmente compatible con Android TV y soporta controles remotos de televisores y dispositivos Android TV.

## Características de Android TV

### Navegación con Control Remoto

La aplicación soporta completamente la navegación con el control remoto de tu televisor o Android TV Box:

#### En la Pantalla Principal
- **D-PAD (↑ ↓ ← →)**: Navega entre los canales
- **ENTER/OK/SELECT**: Selecciona y reproduce un canal
- **BACK**: Regresa a la pantalla anterior
- **MENU**: Marca/desmarca canal como favorito

#### En el Reproductor
- **PLAY/PAUSE**: Reproduce o pausa el contenido
- **PLAY/PAUSE o ENTER**: Alterna entre reproducir y pausar
- **STOP**: Detiene y sale del reproductor
- **← (Izquierda)**: Retrocede 10 segundos
- **→ (Derecha)**: Avanza 10 segundos
- **↑ (Arriba)**: Sube el volumen
- **↓ (Abajo)**: Baja el volumen
- **REWIND**: Retrocede rápidamente
- **FAST FORWARD**: Avanza rápidamente
- **BACK**: Sale del reproductor

### Interfaz Optimizada para TV

La aplicación detecta automáticamente cuando se ejecuta en Android TV y muestra una interfaz optimizada:

- **Grid de Canales**: Vista de cuadrícula optimizada para pantallas grandes (4 columnas)
- **Logos de Canales**: Muestra los logos de los canales cuando están disponibles
- **Feedback Visual**: Indicadores claros de qué elemento tiene el foco
- **Auto-scroll**: La lista se desplaza automáticamente para mantener el elemento seleccionado visible
- **Botones Grandes**: Todos los botones están optimizados para ser visibles desde la distancia

## Configuración

### Cambiar entre Modo Móvil y TV

En el archivo `lib/main.dart`, puedes cambiar el modo de la aplicación:

```dart
static bool get isAndroidTV {
  if (!kIsWeb && Platform.isAndroid) {
    return true; // Cambia a false para modo móvil
  }
  return false;
}
```

### Requisitos de Android TV

El `AndroidManifest.xml` ya está configurado con:
- Soporte para `LEANBACK_LAUNCHER` (launcher de TV)
- `touchscreen` marcado como no requerido
- `android.software.leanback` como característica opcional
- Banner de TV configurado

## Control desde Celular

Si tienes la aplicación de control remoto de Android TV en tu celular, también puedes controlar la aplicación:

1. **App de Google TV** (Android/iOS)
2. **Control Remoto Android TV** (integrado en algunos dispositivos Android)
3. **Teclado y Mouse Bluetooth**

## Instalación en Android TV

### Método 1: APK Directo
1. Compila la aplicación: `flutter build apk --release`
2. Transfiere el APK a tu Android TV usando USB o red
3. Instala usando un explorador de archivos de TV

### Método 2: ADB
```bash
flutter build apk --release
adb connect <IP_DE_TU_TV>:5555
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Método 3: Android Studio
1. Conecta tu Android TV por ADB
2. Ejecuta `flutter run` con el dispositivo TV seleccionado

## Solución de Problemas

### La aplicación no aparece en el launcher de TV
- Verifica que el AndroidManifest.xml tenga la categoría `LEANBACK_LAUNCHER`
- Asegúrate de que el banner de TV esté presente en los recursos

### El control remoto no funciona
- Verifica que la navegación por D-pad esté habilitada en la configuración de tu TV
- Reinicia la aplicación
- Prueba con otro control remoto o la app de control remoto del celular

### La interfaz se ve pequeña
- La aplicación detecta automáticamente Android TV
- Verifica que `PlatformDetector.isAndroidTV` retorne `true` en `main.dart`

## Roadmap Futuro

Funcionalidades planeadas para futuras versiones:
- [ ] Recomendaciones en pantalla de inicio
- [ ] Guía de programación (EPG)
- [ ] Búsqueda por voz
- [ ] Android TV Channels integration
- [ ] Picture-in-Picture (PiP)
- [ ] Integración con Google Assistant

## Soporte

Para reportar problemas o sugerencias relacionadas con Android TV, por favor abre un issue en el repositorio del proyecto.
