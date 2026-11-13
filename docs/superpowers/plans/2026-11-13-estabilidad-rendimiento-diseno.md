# Estabilidad, rendimiento y diseño de la app de TV — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que Fred TV sea más estable y ligera en el televisor (menos memoria, menos trabajo por fotograma, zapping más rápido, sin fugas) y que la interfaz se vea más cuidada y consistente.

**Architecture:** Son 11 mejoras pequeñas e independientes sobre el código de `lib/screens/tv/` y `lib/backend/`, cada una con su test y su commit. No cambia la arquitectura (fachada `TvData`, motores `ExoEngine`/`MpvEngine`, widgets `Tv*`); no hay migraciones de base de datos ni dependencias nuevas.

**Tech Stack:** Flutter 3.32.4 / Dart 3.8, `video_player` (ExoPlayer), `media_kit` (mpv), `cached_network_image`, `sqlite_async`, `flutter_test`.

**Spec:** No hay spec aparte. Este plan nace de una auditoría del código y de mediciones en la TV; los hallazgos que justifican cada tarea están en la sección siguiente y en el «Por qué» de cada tarea.

## Hallazgos de la auditoría (2026-11-13)

Medido en la TV de pruebas (Hisense, Android 12 / API 31): pantalla 1920×1080 con densidad 320 → **960×540 píxeles lógicos, dpr 2**; **1,8 GB de RAM, ~520 MB disponibles**; arranque en frío 1,25 s; PSS de la app entre 116 MB y 215 MB (lectura ruidosa). Línea base del repo: **561 tests en verde**, `flutter analyze` con **31 avisos** (ningún error).

| # | Hallazgo | Dónde | Tarea |
|---|----------|-------|-------|
| 1 | Los logos se decodifican a resolución completa (sin `memCacheWidth`) y la caché de imágenes usa el límite por defecto (100 MB) en una TV con ~520 MB libres | `widgets/tv_channel_card.dart:44` | 1, 5 |
| 2 | `http.get` de Xtream sin timeout: si cuelga, bloquea `SourceRefresher` (secuencial) el resto de la sesión | `backend/xtream.dart:97` | 1 |
| 3 | Sin `ErrorWidget.builder` ni `PlatformDispatcher.onError`: un fallo de build deja un recuadro gris | `main.dart` | 1 |
| 4 | `ExoEngine.positionStream` crea un `Stream.periodic` nuevo en cada lectura; `_buildProgress` lo lee en cada rebuild y `asBroadcastStream()` no cancela el temporizador → fuga de temporizadores de 500 ms en películas | `player/exo_engine.dart:56`, `player/tv_player.dart:1194` | 2 |
| 5 | `ExoEngine._onValue` incrementa `_tick` en cada notificación (posición, buffer…) y reconstruye el árbol del video varias veces por segundo | `player/exo_engine.dart:141` | 2 |
| 6 | El reproductor no observa el ciclo de vida: al pulsar Inicio siguen corriendo los temporizadores de reintento (acaban en la pantalla de error) y al volver un directo queda pausado o desfasado | `player/tv_player.dart` | 3 |
| 7 | Cada apertura de un `.m3u8` con ExoPlayer descarga antes el manifiesto (hasta 4 s) para decidir si necesita `HlsAudioFix`, aunque ya se sepa que no | `player/hls_audio_fix.dart:27` | 4 |
| 8 | `IndexedStack` construye las 5 pestañas al arrancar (Canales, Favoritos, Mis listas, Buscar, Ajustes), cada una con sus consultas | `tv_home.dart:322` | 6 |
| 9 | El menú lateral anima su ancho (84↔220) y empuja el contenido: la grilla pasa de 2 a 3 columnas y se recoloca entera cada vez que el foco entra o sale del menú (visto en capturas) | `tv_home.dart:216` | 7 |
| 10 | Tema Material por defecto (semilla morada): indicadores de carga y SnackBars no usan los colores de `TvTheme` | `main.dart:158` | 8 |
| 11 | El mismo botón está copiado en 4 sitios con tamaños distintos; el botón primario no cambia al recibir foco | `tv_bootstrap.dart:161`, `widgets/tv_dialogs.dart:7`, `player/tv_player.dart:1283`, `youtube/tv_youtube_player.dart:372` | 9 |
| 12 | Logos oscuros invisibles sobre la tarjeta oscura (p. ej. «[adult swim]»); nombres con ruido («(1080p) [Not 24/7]») que se cortan; foco poco contrastado | `widgets/tv_channel_card.dart` | 10 |
| 13 | Al cambiar de grupo la grilla se vacía y muestra un spinner; los estados vacíos son solo texto; solo caben 9 canales en pantalla | `tv_channel_browser.dart:455` | 11 |

## Global Constraints

- Rama: crear `feat/estabilidad-rendimiento-diseno` a partir de `feat/canales-youtube`. **Nunca `git push`**; solo commits locales, uno por tarea, con la línea de atribución que indique la sesión.
- Flutter 3.32.4 / Dart 3.8: **no subir versiones ni añadir dependencias** (ver `fred-tv-dev-gotchas` en la memoria del proyecto).
- No tocar la interfaz de móvil (`lib/home.dart`, `lib/player.dart`, `lib/settings_view.dart`, `lib/setup.dart`…) salvo `lib/main.dart` y `lib/backend/xtream.dart` donde se indica.
- Sin efectos caros de GPU: nada de `BackdropFilter`, `ImageFilter`, `ShaderMask`, sombras con desenfoque nuevas ni animaciones en bucle (shimmer).
- Todo texto visible nuevo va en los 6 ARB de `lib/l10n/` (ver `fred-tv-l10n`); este plan **no** añade textos nuevos.
- Los colores de `TvTheme` que dependen de `highContrast` son getters: no convertirlos en `const`.
- Tests de TV: `t.tap` no activa los botones; usa foco + teclas (`pumpTv`, `isFocused` de `test/screens/tv/fakes.dart`, que simula 960×540 con dpr 2).
- Editar código con las herramientas de edición, no con heredocs de Bash (rompen `\n`, `=>` y apóstrofes).
- Después de cada tarea: `flutter analyze` no debe tener más de 31 avisos ni ningún error, y `flutter test` debe pasar entero.
- En la TV: nunca `pm clear` ni desinstalar (se pierden los datos del usuario); instalar con `adb install -r`.

## Review Focus

1. **Volver de segundo plano tras más de un minuto con un directo abierto** (ExoPlayer y mpv): debe reabrirse solo, no quedar congelado ni en la pantalla de error. No es automatizable (los motores no son inyectables): se cubre con la política pura de la Tarea 3 y la comprobación manual de la Tarea 12.
2. **Enlace `fredtv://search?q=…` recibido al arrancar** con pestañas perezosas: Buscar debe construirse y recibir la consulta → test en la Tarea 6.
3. **`tvSourcesVersion` cambia cuando Favoritos y Mis listas aún no se han construido**: no debe lanzar (su `currentState` es `null`) → test en la Tarea 6.
4. **Un manifiesto HLS que pasa de «con audio» a «solo video»** dentro de la caché de veredictos dejaría el canal mudo: el veredicto caduca a los 30 min y un fallo de descarga nunca se guarda → tests en la Tarea 4.
5. **Logo vacío, roto o enorme**: la tarjeta muestra el icono de respaldo y el decodificado queda acotado → tests en la Tarea 5.

---

### Task 1: Red de seguridad de arranque (errores, caché de imágenes, timeout de Xtream)

**Por qué:** hallazgos 1 (límite de caché), 2 y 3.

**Files:**
- Create: `lib/screens/tv/tv_startup.dart`
- Modify: `lib/main.dart` (rama `if (PlatformDetector.isAndroidTV)` de `main()`), `lib/backend/xtream.dart:97`
- Test: `test/screens/tv/tv_startup_test.dart`

**Interfaces:**
- Produces: `void configureTvImageCache()`, `void installTvErrorGuards()`, `Widget tvErrorWidget(FlutterErrorDetails details)`; constantes `tvImageCacheBytes = 50 << 20`, `tvImageCacheCount = 200`.

- [ ] **Step 1: Test que falla** en `test/screens/tv/tv_startup_test.dart`

```dart
testWidgets('configureTvImageCache limita la caché de imágenes', (t) async {
  final cache = PaintingBinding.instance.imageCache;
  final bytes = cache.maximumSizeBytes, count = cache.maximumSize;
  addTearDown(() {
    cache.maximumSizeBytes = bytes;
    cache.maximumSize = count;
  });
  configureTvImageCache();
  expect(cache.maximumSizeBytes, 50 << 20);
  expect(cache.maximumSize, 200);
});

testWidgets('tvErrorWidget es un recuadro discreto, sin texto técnico', (t) async {
  await pumpTv(t, tvErrorWidget(FlutterErrorDetails(exception: 'boom')));
  expect(find.byIcon(Icons.error_outline), findsOneWidget);
  expect(find.textContaining('boom'), findsNothing);
});
```

- [ ] **Step 2:** `flutter test test/screens/tv/tv_startup_test.dart` → FALLA (no existe `tv_startup.dart`).
- [ ] **Step 3: Implementar `tv_startup.dart`.** `tvErrorWidget`: `ColoredBox` con `TvTheme.surface` y un `Icon(Icons.error_outline, color: TvTheme.textSecondary, size: 28)` centrado. `installTvErrorGuards()`: asigna `ErrorWidget.builder = tvErrorWidget`; envuelve `FlutterError.onError` conservando el manejador previo y añadiendo `debugPrint('FredTV: error de Flutter: …')`; asigna `PlatformDispatcher.instance.onError` que hace `debugPrint('FredTV: error no capturado: $error\n$stack')` y devuelve `true`.
- [ ] **Step 4:** en `main()`, dentro de la rama de TV y antes de `runApp`, llamar a `installTvErrorGuards()` y `configureTvImageCache()`.
- [ ] **Step 5:** en `getXtreamHttpData` cambiar `await http.get(url)` por `await http.get(url).timeout(const Duration(seconds: 60))` (el `catch (_)` existente ya devuelve `null`).
- [ ] **Step 6:** `flutter test test/screens/tv/tv_startup_test.dart` → PASA; `flutter analyze` sin errores.
- [ ] **Step 7: Commit** `fix(tv): red de seguridad de arranque y timeout en Xtream`

### Task 2: ExoEngine sin fuga de temporizadores ni reconstrucciones continuas

**Por qué:** hallazgos 4 y 5.

**Files:**
- Modify: `lib/screens/tv/player/exo_engine.dart`
- Test: `test/screens/tv/player/exo_engine_test.dart` (nuevo)

**Interfaces:**
- Produces: `bool exoVideoLayoutChanged(VideoPlayerValue before, VideoPlayerValue after)` (función de nivel superior). `ExoEngine.positionStream` pasa a devolver siempre el stream de **un único** `StreamController<Duration>.broadcast`.

- [ ] **Step 1: Tests que fallan**

```dart
test('exoVideoLayoutChanged ignora posición y buffer', () {
  const a = VideoPlayerValue(
      duration: Duration(minutes: 1), size: Size(1920, 1080), isInitialized: true);
  expect(exoVideoLayoutChanged(a, a.copyWith(position: const Duration(seconds: 5))), isFalse);
  expect(exoVideoLayoutChanged(a, a.copyWith(isBuffering: true)), isFalse);
  expect(exoVideoLayoutChanged(a, a.copyWith(size: const Size(1280, 720))), isTrue);
  expect(exoVideoLayoutChanged(a, a.copyWith(isInitialized: false)), isTrue);
  expect(exoVideoLayoutChanged(a, a.copyWith(rotationCorrection: 90)), isTrue);
});

testWidgets('positionStream emite cada 500 ms y no deja temporizadores', (t) async {
  final engine = ExoEngine();
  final seen = <Duration>[];
  final sub = engine.positionStream.listen(seen.add);
  await t.pump(const Duration(milliseconds: 1100));
  expect(seen, [Duration.zero, Duration.zero]);
  await sub.cancel();
  // Sin temporizador pendiente: testWidgets fallaría al terminar si quedara uno.
});
```

No llames a `engine.dispose()` en el test (usa el plugin de wakelock, que no existe en tests).

- [ ] **Step 2:** `flutter test test/screens/tv/player/exo_engine_test.dart` → FALLA.
- [ ] **Step 3: Implementar.** `positionStream`: un `StreamController<Duration>.broadcast(onListen:, onCancel:)` de instancia que arranca un `Timer.periodic(500 ms)` al primer oyente y lo cancela cuando no queda ninguno; se cierra (y el temporizador se cancela) en `dispose()`. `_onValue`: guardar el último `VideoPlayerValue` y hacer `_tick.value++` solo si `exoVideoLayoutChanged(anterior, actual)`; los `_tick.value++` de `open()` y `_release()` se quedan.
- [ ] **Step 4:** tests → PASAN; `flutter test test/screens/tv/player` entero en verde.
- [ ] **Step 5: Commit** `fix(tv): ExoEngine sin fuga de temporizadores ni rebuilds por posición`

### Task 3: El reproductor respeta el ciclo de vida de la app

**Por qué:** hallazgo 6. Además `_releaseEngine()` espera `endOfFrame`, que no llega con la app en segundo plano: un reintento lanzado ahí se queda colgado.

**Files:**
- Modify: `lib/screens/tv/player/tv_retry_policy.dart`, `lib/screens/tv/player/tv_player.dart`
- Test: `test/screens/tv/player/tv_retry_policy_test.dart`

**Interfaces:**
- Produces: `enum TvResumeAction { none, reopen, resume }` y `static TvResumeAction TvRetryPolicy.onResume({required bool isLive, required bool hasError, required bool wasPlaying})`.

- [ ] **Step 1: Tests que fallan** (añadir al archivo existente)

```dart
group('TvRetryPolicy.onResume', () {
  test('un directo se reabre', () => expect(
      TvRetryPolicy.onResume(isLive: true, hasError: false, wasPlaying: false),
      TvResumeAction.reopen));
  test('una película que sonaba continúa', () => expect(
      TvRetryPolicy.onResume(isLive: false, hasError: false, wasPlaying: true),
      TvResumeAction.resume));
  test('una película en pausa se queda en pausa', () => expect(
      TvRetryPolicy.onResume(isLive: false, hasError: false, wasPlaying: false),
      TvResumeAction.none));
  test('con la pantalla de error no se hace nada', () => expect(
      TvRetryPolicy.onResume(isLive: true, hasError: true, wasPlaying: true),
      TvResumeAction.none));
});
```

- [ ] **Step 2:** `flutter test test/screens/tv/player/tv_retry_policy_test.dart` → FALLA.
- [ ] **Step 3:** implementar `TvResumeAction` y `TvRetryPolicy.onResume`.
- [ ] **Step 4: Conectar en `_TvPlayerState`.** Añadir `with WidgetsBindingObserver`; `addObserver` en `initState` y `removeObserver` en `dispose`. Campos `bool _backgrounded = false; bool _wasPlaying = false;`. En `didChangeAppLifecycleState`:
  - `AppLifecycleState.paused` (si `!_backgrounded && !_exiting`): `_backgrounded = true`, `_wasPlaying = _playing`, `++_generation` (invalida un `_play` en curso), cancelar `_firstFrameTimer`, `_stallTimer` y `_reconnectTimer`, y `unawaited(_engine?.pause())` capturando errores.
  - `AppLifecycleState.resumed` (si `_backgrounded`): `_backgrounded = false` y según `TvRetryPolicy.onResume(isLive: _isLive, hasError: _hasError, wasPlaying: _wasPlaying)`: `reopen` → `_liveReconnects = 0; _play(0);` · `resume` → `_engine?.play()` · `none` → nada. Si `_camera.visible`, `unawaited(_camera.retryNow())`; si `_mini.visible`, `unawaited(_mini.retryNow())`.
  - En `_reconnectLive` y `_onFailure`, salir sin hacer nada si `_backgrounded`.
- [ ] **Step 5:** tests → PASAN; `flutter analyze` sin errores.
- [ ] **Step 6: Commit** `fix(tv): el reproductor se detiene en segundo plano y se recupera al volver`

### Task 4: Zapping más rápido — recordar qué canales HLS no necesitan corrección de audio

**Por qué:** hallazgo 7.

**Files:**
- Modify: `lib/screens/tv/player/hls_audio_fix.dart`
- Test: `test/screens/tv/player/hls_audio_fix_test.dart`

**Interfaces:**
- Produces: `HlsAudioFix.prepare` gana el parámetro opcional `DateTime Function() now = DateTime.now`; `static const Duration HlsAudioFix.verdictTtl = Duration(minutes: 30)`; `@visibleForTesting static void HlsAudioFix.debugClearVerdicts()`.

- [ ] **Step 1: Tests que fallan** (grupo `HlsAudioFix.prepare`; llamar a `HlsAudioFix.debugClearVerdicts()` en un `setUp`). `_conAudio` es el manifiesto con `CODECS="avc1.64001f,mp4a.40.2"` que ya usa el archivo; `_soloVideo` ya existe.

```dart
test('no vuelve a descargar un manifiesto que ya se sabe que trae audio', () async {
  var calls = 0;
  final client = MockClient((_) async { calls++; return http.Response(_conAudio, 200); });
  for (var i = 0; i < 2; i++) {
    expect(await HlsAudioFix.prepare('https://x.test/i.m3u8', userAgent: 'UA', client: client), isNull);
  }
  expect(calls, 1);
});

test('el veredicto caduca a los 30 minutos', () async {
  var calls = 0;
  var now = DateTime(2026, 1, 1, 12);
  final client = MockClient((_) async { calls++; return http.Response(_conAudio, 200); });
  await HlsAudioFix.prepare('https://x.test/i.m3u8', userAgent: 'UA', client: client, now: () => now);
  now = now.add(const Duration(minutes: 31));
  await HlsAudioFix.prepare('https://x.test/i.m3u8', userAgent: 'UA', client: client, now: () => now);
  expect(calls, 2);
});

test('un fallo de descarga no se recuerda', () async {
  var calls = 0;
  final client = MockClient((_) async { calls++; return http.Response('', 500); });
  await HlsAudioFix.prepare('https://x.test/i.m3u8', userAgent: 'UA', client: client);
  await HlsAudioFix.prepare('https://x.test/i.m3u8', userAgent: 'UA', client: client);
  expect(calls, 2);
});

test('un canal que necesita la corrección se prepara siempre', () async {
  final client = MockClient((_) async => http.Response(_soloVideo, 200));
  for (var i = 0; i < 2; i++) {
    final fix = await HlsAudioFix.prepare('https://x.test/i.m3u8', userAgent: 'UA', client: client);
    expect(fix, isNotNull);
    await fix!.close();
  }
});
```

- [ ] **Step 2:** `flutter test test/screens/tv/player/hls_audio_fix_test.dart` → FALLA.
- [ ] **Step 3: Implementar.** Mapa estático `url → DateTime` de manifiestos que **no** necesitan corrección. `prepare` devuelve `null` sin red si hay un veredicto de menos de `verdictTtl`; solo guarda veredicto cuando el manifiesto se descargó (`body != null`) y `!hlsDropsAudio(body)`. Acotar el mapa a 500 entradas (al superarlas, vaciarlo).
- [ ] **Step 4:** tests → PASAN.
- [ ] **Step 5: Commit** `perf(tv): no sondear de nuevo los HLS que no necesitan corrección de audio`

### Task 5: Logos decodificados al tamaño de la tarjeta

**Por qué:** hallazgo 1. Un logo de 1000×1000 ocupa 4 MB decodificado; la tarjeta mide como mucho 200 px lógicos (400 físicos).

**Files:**
- Modify: `lib/screens/tv/widgets/tv_channel_card.dart`
- Test: `test/screens/tv/tv_channel_card_test.dart` (nuevo)

**Interfaces:**
- Produces: en `TvChannelCard`, el `CachedNetworkImage` lleva `memCacheWidth = (TvTheme.tileMaxExtent * MediaQuery.devicePixelRatioOf(context)).round()`, `fadeInDuration: Duration.zero` y `fadeOutDuration: Duration.zero`.

- [ ] **Step 1: Tests que fallan.** Construye el canal como en los demás tests de TV (`Channel(name:, image:, url:, favorite: false, mediaType: MediaType.livestream, sourceId: 1)`), dentro de un `SizedBox(width: 200, height: 150)`.

```dart
testWidgets('el logo se decodifica al ancho de la tarjeta', (t) async {
  await pumpTv(t, card(image: 'https://x.test/logo.png'));
  final img = t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
  expect(img.memCacheWidth, (TvTheme.tileMaxExtent * 2).round()); // pumpTv usa dpr 2
  expect(img.fadeInDuration, Duration.zero);
});

testWidgets('sin logo muestra el icono de respaldo', (t) async {
  await pumpTv(t, card(image: ''));
  expect(find.byType(CachedNetworkImage), findsNothing);
  expect(find.byIcon(Icons.live_tv), findsOneWidget);
});
```

Si `pumpAndSettle` no termina por la descarga de la imagen, monta el primer caso con `pumpTvRoute` (no espera a que se asiente).

- [ ] **Step 2:** `flutter test test/screens/tv/tv_channel_card_test.dart` → FALLA en el primer test.
- [ ] **Step 3:** implementar los tres parámetros en el `CachedNetworkImage`.
- [ ] **Step 4:** tests → PASAN.
- [ ] **Step 5: Commit** `perf(tv): decodificar los logos al tamaño de la tarjeta`

### Task 6: Pestañas perezosas en el inicio

**Por qué:** hallazgo 8.

**Files:**
- Modify: `lib/screens/tv/tv_home.dart`
- Test: `test/screens/tv/tv_home_test.dart`

**Interfaces:**
- Produces: `_TVHomeState` mantiene `final Set<int> _builtTabs = {0}`; una pestaña se construye la primera vez que se selecciona (en `_onNavFocused` y en `_onLink` para Buscar) y después se conserva viva en el `IndexedStack`. Las no construidas son `const SizedBox.shrink()` (manteniendo su `ExcludeFocus` + `FocusScope`).

- [ ] **Step 1: Tests que fallan** (usa los mismos fakes y el mismo montaje que el resto de `tv_home_test.dart`; `FakeTvPlatform` o equivalente ya existe para los enlaces)

```dart
testWidgets('al arrancar solo se construye Canales', (t) async {
  await pumpHome(t);
  expect(find.byType(TVSettings, skipOffstage: false), findsNothing);
  expect(find.byType(TVSearch, skipOffstage: false), findsNothing);
  expect(find.byType(TvUserPlaylistsScreen, skipOffstage: false), findsNothing);
});

testWidgets('una pestaña visitada se conserva al salir de ella', (t) async {
  await pumpHome(t);
  // ↓ cuatro veces desde Canales llega a Ajustes; ↑ cuatro veces vuelve.
  for (var i = 0; i < 4; i++) { await t.sendKeyEvent(LogicalKeyboardKey.arrowDown); await t.pumpAndSettle(); }
  expect(find.byType(TVSettings), findsOneWidget);
  for (var i = 0; i < 4; i++) { await t.sendKeyEvent(LogicalKeyboardKey.arrowUp); await t.pumpAndSettle(); }
  expect(find.byType(TVSettings, skipOffstage: false), findsOneWidget);
});

testWidgets('un enlace de búsqueda al arrancar construye Buscar con la consulta', (t) async {
  await pumpHome(t, initialLink: 'fredtv://search?q=dw');
  expect(find.byType(TVSearch), findsOneWidget);
  expect(find.text('dw'), findsWidgets);
});

testWidgets('cambiar las fuentes sin haber abierto Favoritos no lanza', (t) async {
  await pumpHome(t);
  tvSourcesVersion.value++;
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
});
```

`pumpHome` es el nombre del montaje aquí; usa el helper que ya tenga el archivo y añade el parámetro del enlace inicial solo si no existe.

- [ ] **Step 2:** `flutter test test/screens/tv/tv_home_test.dart` → FALLAN los dos primeros.
- [ ] **Step 3:** implementar `_builtTabs` en `_buildContent`, `_onNavFocused` y `_onLink`. Construir cada widget de pestaña solo si su índice está en el conjunto.
- [ ] **Step 4:** el archivo entero en verde. Si un test anterior dependía de que una pestaña existiera sin haberla visitado, ajusta el test para que la visite primero (no reviertas la pereza).
- [ ] **Step 5: Commit** `perf(tv): construir cada pestaña del inicio al visitarla`

### Task 7: El menú lateral se despliega por encima del contenido

**Por qué:** hallazgo 9. Hoy la grilla cambia de 2 a 3 columnas y recoloca todos los logos cada vez que el foco cruza entre menú y contenido.

**Files:**
- Modify: `lib/screens/tv/tv_home.dart` (`build` y `_buildSidebar`)
- Test: `test/screens/tv/tv_home_test.dart`

**Interfaces:**
- Produces: el cuerpo pasa de `Row[sidebar, contenido]` a `Stack[Padding(left: TvTheme.sidebarCollapsed + 8, contenido), Positioned(left: 0, top: 0, bottom: 0, sidebar)]`. El contenido tiene siempre el mismo ancho; el menú sigue animando 84↔220 pero tapa el contenido en vez de empujarlo.

- [ ] **Step 1: Test que falla**

```dart
testWidgets('el contenido no cambia de ancho al entrar o salir del menú', (t) async {
  await pumpHome(t); // foco en el menú: desplegado
  final open = t.getSize(find.byType(IndexedStack)).width;
  await t.sendKeyEvent(LogicalKeyboardKey.arrowRight); // entra al contenido
  await t.pumpAndSettle();
  expect(t.getSize(find.byType(IndexedStack)).width, open);
});
```

- [ ] **Step 2:** `flutter test test/screens/tv/tv_home_test.dart` → FALLA (hoy difiere en 136 px).
- [ ] **Step 3:** implementar el `Stack`. El `FocusScope` del menú, `_onEdge`, `PopScope` y las `Actions` no cambian.
- [ ] **Step 4:** archivo entero en verde (la navegación ←/→ entre menú y contenido la cubren los tests existentes).
- [ ] **Step 5: Commit** `perf(tv): el menú lateral se despliega sobre el contenido sin recolocar la grilla`

### Task 8: Tema Material alineado con TvTheme

**Por qué:** hallazgo 10.

**Files:**
- Modify: `lib/screens/tv/widgets/tv_theme.dart`, `lib/main.dart:158-162`, `test/screens/tv/fakes.dart` (`pumpTv`)
- Test: `test/screens/tv/tv_appearance_test.dart`

**Interfaces:**
- Produces: `ThemeData tvMaterialTheme()` en `tv_theme.dart`.

- [ ] **Step 1: Test que falla**

```dart
test('tvMaterialTheme usa los colores de TvTheme', () {
  final theme = tvMaterialTheme();
  expect(theme.brightness, Brightness.dark);
  expect(theme.colorScheme.primary, TvTheme.accent);
  expect(theme.scaffoldBackgroundColor, TvTheme.background);
  expect(theme.progressIndicatorTheme.color, TvTheme.accent);
  expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
  expect(theme.snackBarTheme.backgroundColor, TvTheme.surfaceRaised);
});
```

- [ ] **Step 2:** `flutter test test/screens/tv/tv_appearance_test.dart` → FALLA.
- [ ] **Step 3: Implementar `tvMaterialTheme()`:** `ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: ColorScheme.fromSeed(seedColor: TvTheme.accent, brightness: Brightness.dark).copyWith(primary: TvTheme.accent, surface: TvTheme.surface), scaffoldBackgroundColor: TvTheme.background, progressIndicatorTheme: ProgressIndicatorThemeData(color: TvTheme.accent), snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, width: 520, backgroundColor: TvTheme.surfaceRaised, contentTextStyle: TextStyle(fontSize: TvTheme.fontBody, color: TvTheme.textPrimary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TvTheme.radius))))`.
- [ ] **Step 4:** en `main.dart`, `darkTheme: isTv ? tvMaterialTheme() : ThemeData(useMaterial3: true, brightness: Brightness.dark)`; en `pumpTv`, `theme: tvMaterialTheme()`.
- [ ] **Step 5:** `flutter test` entero → PASA (un SnackBar flotante necesita un `Scaffold` por encima: si algún test falla por eso, la pantalla que lo muestra ya debería tenerlo; no quites `floating`).
- [ ] **Step 6: Commit** `feat(tv): tema Material con los colores de la interfaz de TV`

### Task 9: Un solo botón de TV, con foco inconfundible

**Por qué:** hallazgo 11.

**Files:**
- Create: `lib/screens/tv/widgets/tv_button.dart`
- Modify: `lib/screens/tv/tv_bootstrap.dart` (`_button`), `lib/screens/tv/widgets/tv_dialogs.dart` (`_button`), `lib/screens/tv/player/tv_player.dart` (`_errorButton`), `lib/screens/tv/youtube/tv_youtube_player.dart` (`_button`)
- Test: `test/screens/tv/tv_button_test.dart`

**Interfaces:**
- Produces:

```dart
class TvButton extends StatelessWidget {
  const TvButton({
    super.key,
    required this.label,
    required this.onSelect,
    this.primary = false,
    this.autofocus = false,
    this.focusNode,
  });
}
```

Aspecto: `TvFocusable` con `minWidth: 160`, `minHeight: 56`, relleno 24×12, radio `TvTheme.radius - 2`, texto `fontBody`. Colores: **con foco** fondo `TvTheme.focusBorder` y texto `TvTheme.background` en negrita; sin foco, `primary` → fondo `TvTheme.accent`, normal → fondo `TvTheme.surface`; texto `TvTheme.textPrimary`.

- [ ] **Step 1: Tests que fallan**

```dart
testWidgets('con foco invierte los colores; sin foco usa los normales', (t) async {
  await pumpTv(t, Row(children: [
    TvButton(key: const ValueKey('a'), label: 'Aceptar', autofocus: true, onSelect: () {}),
    TvButton(key: const ValueKey('b'), label: 'Cancelar', onSelect: () {}),
  ]));
  expect(t.widget<Text>(find.text('Aceptar')).style!.color, TvTheme.background);
  expect(t.widget<Text>(find.text('Cancelar')).style!.color, TvTheme.textPrimary);
});

testWidgets('OK llama a onSelect', (t) async {
  var n = 0;
  await pumpTv(t, TvButton(label: 'Ir', autofocus: true, onSelect: () => n++));
  await t.sendKeyDownEvent(LogicalKeyboardKey.select);
  await t.sendKeyUpEvent(LogicalKeyboardKey.select);
  expect(n, 1);
});
```

- [ ] **Step 2:** `flutter test test/screens/tv/tv_button_test.dart` → FALLA.
- [ ] **Step 3:** implementar `TvButton`.
- [ ] **Step 4:** sustituir las cuatro copias por `TvButton`, **conservando las `key` y los `focusNode`** que reciben hoy (los tests existentes los buscan). Borrar las funciones `_button` / `_errorButton` que queden sin uso.
- [ ] **Step 5:** `flutter test` entero → PASA.
- [ ] **Step 6: Commit** `feat(tv): botón de TV único con foco de alto contraste`

### Task 10: Tarjeta de canal más legible

**Por qué:** hallazgo 12 (capturas de la TV: «[adult swim]» invisible, nombres cortados por «(1080p) [Not 24/7]»).

**Files:**
- Create: `lib/screens/tv/tv_channel_label.dart`
- Modify: `lib/screens/tv/widgets/tv_theme.dart`, `lib/screens/tv/widgets/tv_channel_card.dart`
- Test: `test/screens/tv/tv_channel_label_test.dart` (nuevo), `test/screens/tv/tv_channel_card_test.dart`

**Interfaces:**
- Produces: `class TvChannelLabel { final String title; final String? quality; }` y `TvChannelLabel tvChannelLabel(String name)`; en `TvTheme`: `static const Color logoPlate = Color(0xFF4A4A57)` y `static const Color surfaceFocused = Color(0xFF34343F)`.
- Solo cambia lo que **pinta** la tarjeta: `channel.name` no se modifica (búsqueda, enlaces, listas y el reproductor siguen usando el nombre completo).

- [ ] **Step 1: Tests que fallan** (`tv_channel_label_test.dart`)

```dart
void check(String name, String title, String? quality) {
  final l = tvChannelLabel(name);
  expect((l.title, l.quality), (title, quality));
}

test('separa la calidad y quita las etiquetas entre corchetes', () {
  check('3ABN Latino (1080p)', '3ABN Latino', '1080p');
  check('4Dmas Noticias TV (1080p) [Not 24/7]', '4Dmas Noticias TV', '1080p');
  check('Adult Swim West [Not 24/7;Geo-blocked]', 'Adult Swim West', null);
  check('Canal (576i)', 'Canal', '576i');
});

test('no toca lo que no es calidad ni etiqueta', () {
  check('5tv', '5tv', null);
  check('Canal (Perú)', 'Canal (Perú)', null);
});

test('si no queda nada conserva el nombre original', () {
  check('[Test]', '[Test]', null);
});
```

Y en `tv_channel_card_test.dart`:

```dart
testWidgets('la tarjeta muestra el nombre limpio y la calidad aparte', (t) async {
  await pumpTv(t, card(name: 'ADN TV (720p) [Not 24/7]', image: ''));
  expect(find.text('ADN TV'), findsOneWidget);
  expect(find.text('720p'), findsOneWidget);
});

testWidgets('el nombre resalta con foco', (t) async {
  await pumpTv(t, card(name: 'ADN TV', image: '', focused: true));
  expect(t.widget<Text>(find.text('ADN TV')).style!.color, TvTheme.textPrimary);
  await pumpTv(t, card(name: 'ADN TV', image: '', focused: false));
  expect(t.widget<Text>(find.text('ADN TV')).style!.color, TvTheme.textSecondary);
});
```

- [ ] **Step 2:** ambos archivos → FALLAN.
- [ ] **Step 3: Implementar `tvChannelLabel`:** quitar todos los grupos `[...]`; extraer la primera coincidencia de `\((\d{3,4}[pi])\)` como `quality` y quitarla; colapsar espacios y recortar; si el título queda vacío, devolver el nombre original sin calidad.
- [ ] **Step 4: Tarjeta.** (a) El logo va sobre una placa: `Container` con `TvTheme.logoPlate`, radio 6 y relleno 6 dentro del área del logo, solo cuando hay imagen (el icono de respaldo no lleva placa). (b) Fondo de la tarjeta con foco: `TvTheme.surfaceFocused`. (c) Nombre: `tvChannelLabel(channel.name).title`, color `textPrimary` + `FontWeight.w600` con foco y `textSecondary` sin foco. (d) Calidad: texto de 12 px en `textSecondary` dentro de una píldora `Color(0xCC000000)` de radio 4, en la esquina inferior derecha del área del logo; no se pinta si `quality == null`.
- [ ] **Step 5:** `flutter test` entero → PASA. Si un test existente buscaba en una tarjeta un nombre con «(720p)» o corchetes, cámbialo al título limpio.
- [ ] **Step 6: Commit** `feat(tv): tarjeta de canal con placa de logo, nombre limpio y foco más claro`

### Task 11: Grilla más densa, esqueleto de carga y estados vacíos

**Por qué:** hallazgo 13. Con 960 px lógicos caben 3 columnas y 9 canales; con estos valores caben 4 columnas y 16.

**Files:**
- Create: `lib/screens/tv/widgets/tv_grid_skeleton.dart`
- Modify: `lib/screens/tv/widgets/tv_theme.dart`, `lib/screens/tv/tv_channel_browser.dart` (`_buildGrid`)
- Test: `test/screens/tv/tv_channel_browser_test.dart`

**Interfaces:**
- Consumes: `TvTheme.surface`, `TvTheme.radius`.
- Produces: `TvTheme.tileMaxExtent = 150.0` (antes 200) y `TvTheme.groupsWidth = 208.0` (antes 240); `class TvGridSkeleton extends StatelessWidget { const TvGridSkeleton({super.key, this.count = 16}); }` — una `GridView` no desplazable (`NeverScrollableScrollPhysics`) con el mismo `SliverGridDelegateWithMaxCrossAxisExtent`, relleno y separación que la grilla real, y cajas estáticas `TvTheme.surface` con radio `TvTheme.radius - 2`. Sin animación.

- [ ] **Step 1: Tests que fallan**

```dart
testWidgets('mientras cargan los canales se ve el esqueleto, no un spinner', (t) async {
  final gate = Completer<List<Channel>>();
  await pumpBrowserNoSettle(t, FakeTvData(onSearchChannels: (_) => gate.future));
  expect(find.byType(TvGridSkeleton), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  gate.complete(const []);
  await t.pumpAndSettle();
  expect(find.byType(TvGridSkeleton), findsNothing);
});

testWidgets('un grupo vacío muestra icono y texto', (t) async {
  await pumpBrowser(t, FakeTvData());
  expect(find.byIcon(Icons.tv_off), findsOneWidget);
});

testWidgets('Favoritos vacío muestra su icono', (t) async {
  await pumpBrowser(t, FakeTvData(), favoritesOnly: true);
  expect(find.byIcon(Icons.star_border), findsOneWidget);
});
```

`pumpBrowser` / `pumpBrowserNoSettle` son los nombres del montaje aquí: usa el helper que ya tenga el archivo (para el caso sin asentar, `t.pumpWidget` + un `t.pump()`).

- [ ] **Step 2:** `flutter test test/screens/tv/tv_channel_browser_test.dart` → FALLAN los tres.
- [ ] **Step 3:** implementar `TvGridSkeleton`; en `_buildGrid`, devolverlo cuando `_loadingChannels`; en el estado vacío, poner encima del texto un `Icon` de 56 px en `TvTheme.textSecondary` (`Icons.star_border` en Favoritos, `Icons.tv_off` en el resto). El spinner de «cargar más» al final de la grilla se queda.
- [ ] **Step 4:** cambiar las dos constantes de `TvTheme`.
- [ ] **Step 5:** `flutter test` entero. Los tests que navegan la grilla con flechas dando por hecho el número de columnas anterior deben recalcularse con las nuevas (en `pumpTv`, sin menú: ancho 960 − 208 − 32 = 720 → `ceil(720 / 170)` = 5 columnas); corrige las pulsaciones esperadas, no las constantes.
- [ ] **Step 6: Commit** `feat(tv): grilla más densa, esqueleto de carga y estados vacíos con icono`

### Task 12: Verificación en el televisor

**Files:** ninguno (si hay que tocar `android/gradle.properties` para compilar, revertirlo con `git checkout -- android/gradle.properties` al terminar).

- [ ] **Step 1: Comprobación final del repo.** `flutter analyze` (≤ 31 avisos, 0 errores) y `flutter test` (todo en verde, más tests que los 561 de partida).
- [ ] **Step 2: Build limpio** siguiendo la receta de la memoria `fred-tv-build-and-tv-testing` (JDK 17 temporal en `gradle.properties`, `flutter clean`, `gradlew --stop`, borrar `android/.gradle`, `flutter pub get`, `flutter build apk --release --target-platform android-arm64,android-arm`). El paso de Gradle debe durar ~110 s; si dura segundos, el build está obsoleto y hay que repetirlo.
- [ ] **Step 3: Instalar** con `adb -s 192.168.1.60:5555 install -r build/app/outputs/flutter-apk/app-release.apk` (adb está en `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`). Si la TV no responde, pide al usuario que la encienda; no sigas a ciegas.
- [ ] **Step 4: Recorrido manual por adb** (antes de mandar teclas, confirma con `dumpsys activity activities | grep mResumedActivity` que la app está en primer plano). Captura con `adb exec-out screencap -p > archivo.png` y revisa cada punto:
  1. Inicio: al pasar del menú a la grilla, las tarjetas **no** cambian de tamaño ni de columnas; se ven 4 columnas.
  2. Tarjetas: «Adult Swim West» (grupo «Todos los canales», tras ~20 pulsaciones de ↓) muestra su logo sobre la placa y el nombre sin corchetes.
  3. Cambiar de grupo muestra el esqueleto, no un spinner.
  4. Reproducir un directo (p. ej. `am start -a android.intent.action.VIEW -d 'fredtv://play?name=DW%20Espa%C3%B1ol' dev.fredol.open_tv`), pulsar Inicio (`input keyevent 3`), esperar 90 s, volver a la app: el canal se reabre solo y no aparece la pantalla de error.
  5. Zapping: abrir el mismo canal HLS dos veces seguidas; la segunda vez no debe aparecer en logcat una segunda descarga previa del manifiesto.
  6. Diálogo de confirmación (Ajustes → eliminar una lista → **Cancelar**): el botón con foco se ve invertido (claro con texto oscuro).
- [ ] **Step 5: Medir** `adb shell dumpsys meminfo dev.fredol.open_tv | grep "TOTAL PSS"` tras bajar 20 filas en «Todos los canales» y comparar con la línea base (116–215 MB, ruidosa). Anota el valor en el informe final; un valor mayor que 215 MB es una regresión que hay que investigar.
- [ ] **Step 6: Informe final al usuario:** qué tareas se completaron, resultado de cada punto del recorrido (con las capturas), la medida de memoria y cualquier punto que no se haya podido verificar, dicho tal cual.

## Fuera de este plan (recomendado para después)

- **Grupos de iptv-org con varias categorías** («Animation;Classic;Entertainment»): llenan la lista de grupos de combinaciones. Arreglarlo cambia cómo se importan los canales (un canal en varios grupos) y necesita su propio diseño.
- **Memoria de la guía XMLTV:** se guardan en memoria todos los programas de todos los canales de hasta 4 países; convendría quedarse solo con los canales que existen en las listas del usuario.
- **Búsqueda y «Todos los canales» con varias listas:** `LIKE '%texto%'` y la deduplicación por URL recorren toda la tabla en cada página. Antes de optimizar hay que medir con la base real del usuario.
- **Firma de release:** el APK se firma con la clave de depuración (`android/app/build.gradle`).
