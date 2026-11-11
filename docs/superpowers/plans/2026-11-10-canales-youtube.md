# Canales de YouTube en la TV — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ver en la app de TV los últimos programas y los directos de canales de YouTube, reproducidos dentro de la app con el reproductor oficial.

**Architecture:** Un canal de YouTube es un canal manual cuya dirección es la de un canal de YouTube. `openTvPlayer` lo detecta y abre una pantalla de programas (mosaico) que obtiene la lista leyendo las pestañas públicas `/videos` y `/streams`; al elegir un programa se abre una pantalla con una WebView y el reproductor IFrame de YouTube, manejado por JavaScript desde las teclas del mando.

**Tech Stack:** Flutter 3.32.4 / Dart 3.8, `http`, `webview_flutter` 4.13.x, `url_launcher`, `wakelock_plus`, SQLite (`sqlite_async`), gen-l10n.

**Spec:** `docs/superpowers/specs/2026-11-10-canales-youtube-design.md`

## Global Constraints

- No subir Flutter (3.32.4) ni Dart (3.8). `webview_flutter: ^4.13.0` (resuelve 4.13.1).
- **Prohibido** obtener flujos de vídeo directos o usar `youtube_explode_dart`; no usar el feed RSS (404).
- Todo texto visible va en los 6 ARB (`lib/l10n/app_{es,en,pt,fr,de,it}.arb`, plantilla `app_es.arb`) y se regenera con `flutter gen-l10n`. No escribir `\n` ni apóstrofes con heredocs de Bash: usar las herramientas de edición.
- Navegación solo con mando; estilos de `TvTheme`; foco con `TvFocusable`.
- Tests de widgets: `pumpTv` y `FakeTvData` de `test/screens/tv/fakes.dart`; activar con teclas (`LogicalKeyboardKey.select`), nunca `tap`. Tests de SQL: `DbFactory.debugPath` + `DbFactory.debugReset()` (ver `test/backend/tv_data_camera_test.dart`); no usar `last_insert_rowid()`.
- Tras cada tarea: `flutter analyze` sin avisos nuevos y `flutter test` en verde.
- Git: solo commits locales, **nunca `git push`**. El árbol tiene trabajo previo sin guardar (ARB, guía, reproductor): cada commit añade **solo** los archivos de su tarea con `git add <rutas>`; si un archivo de la tarea ya tenía cambios ajenos (los ARB y `lib/l10n/gen`), parar y avisar al usuario antes de guardar.
- En la tele: `adb install -r`, nunca `pm clear`. Receta de build limpio y adb en la memoria `fred-tv-build-and-tv-testing`.

## Review Focus

1. La página de YouTube llega sin `ytInitialData` (página de consentimiento, cambio de formato, HTML truncado) → la pantalla muestra error con «Reintentar», nunca una excepción sin capturar ni un mosaico vacío mudo. (Tarea 2 y 4)
2. El mismo vídeo aparece en `/videos` y `/streams`, o una de las dos pestañas falla o no existe → sin duplicados; con una pestaña buena se muestra esa. (Tarea 3)
3. El reproductor no llega a `listo` (sin red, `iframe_api` bloqueado) → a los 20 s aparece el mismo aviso de error con «Abrir en YouTube» y «Volver». (Tarea 6)
4. Atrás pulsado mientras la lista o el vídeo cargan → se cierra limpio, sin `setState` tras `dispose` y sin audio sonando de fondo. (Tareas 4 y 6)
5. El usuario ya tiene una lista propia llamada «YouTube» o un canal manual con uno de los cinco nombres → la siembra los reutiliza, no duplica ni falla el arranque. (Tarea 5)

## Estructura de archivos

| Archivo | Responsabilidad |
|---|---|
| `lib/backend/youtube/youtube_channel.dart` | Reconocer direcciones de canal y construir las de sus pestañas |
| `lib/backend/youtube/youtube_program.dart` | Modelo `YoutubeProgram` |
| `lib/backend/youtube/youtube_page_parser.dart` | HTML de una pestaña → programas |
| `lib/backend/youtube/youtube_channel_service.dart` | Descarga, mezcla, orden y caché |
| `lib/backend/youtube/youtube_seed.dart` | Los cinco canales y la lista «YouTube» |
| `lib/screens/tv/youtube/tv_youtube_programs.dart` | Pantalla mosaico |
| `lib/screens/tv/youtube/youtube_age_label.dart` | Antigüedad localizada |
| `lib/screens/tv/youtube/tv_youtube_player.dart` | Pantalla del reproductor |
| `lib/screens/tv/youtube/youtube_player_page.dart` | HTML/JS del reproductor y sus mensajes |

---

### Task 1: Reconocer canales de YouTube y saltarlos en el zapping

**Files:**
- Create: `lib/backend/youtube/youtube_channel.dart`
- Modify: `lib/screens/tv/player/tv_playlist.dart` (`_step`)
- Test: `test/backend/youtube/youtube_channel_test.dart`, `test/screens/tv/player/tv_playlist_test.dart`

**Interfaces:**
- Produces:
  - `enum YoutubeTab { videos, streams }`
  - `bool isYoutubeChannelUrl(String? url)`
  - `Uri youtubeTabUri(String channelUrl, YoutubeTab tab)` — siempre `https://www.youtube.com/<ruta del canal>/<videos|streams>?hl=en`

- [ ] **Step 1: Tests que fallan**

```dart
test('reconoce direcciones de canal', () {
  for (final u in [
    'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg',
    'https://youtube.com/@curwen',
    'http://m.youtube.com/@PaoloBenzaR/',
    'https://www.youtube.com/@leonmoya/videos',
  ]) {
    expect(isYoutubeChannelUrl(u), isTrue, reason: u);
  }
  for (final u in [
    null, '', 'https://www.youtube.com/watch?v=Ejg0OQPYVgw',
    'https://youtu.be/Ejg0OQPYVgw', 'https://www.youtube.com/',
    'https://example.com/@curwen', 'rtsp://192.168.1.251/1/h264major',
  ]) {
    expect(isYoutubeChannelUrl(u), isFalse, reason: '$u');
  }
});

test('construye la dirección de cada pestaña', () {
  expect(
    youtubeTabUri('http://m.youtube.com/@PaoloBenzaR/videos', YoutubeTab.streams).toString(),
    'https://www.youtube.com/@PaoloBenzaR/streams?hl=en');
  expect(
    youtubeTabUri('https://www.youtube.com/channel/UC-B7Xv56uNRDkj0vC3QW8Cg', YoutubeTab.videos).toString(),
    'https://www.youtube.com/channel/UC-B7Xv56uNRDkj0vC3QW8Cg/videos?hl=en');
});
```

En `tv_playlist_test.dart`: lista `[A, YT, B]` (YT con `url: 'https://www.youtube.com/@curwen'`), cursor en 0 → `next()` deja `current.name == 'B'`; desde B `previous()` deja `'A'`. Con lista `[A, YT]`, `next()` se queda en `'A'`.

- [ ] **Step 2:** `flutter test test/backend/youtube/youtube_channel_test.dart test/screens/tv/player/tv_playlist_test.dart` → FALLA (símbolos inexistentes / se detiene en YT).
- [ ] **Step 3:** Implementar las dos funciones. Hosts aceptados: `youtube.com`, `www.youtube.com`, `m.youtube.com`; primer segmento `channel/<id que empieza por UC>` o `@handle`.
- [ ] **Step 4:** En `TvPlaylistCursor._step`, saltar también los candidatos con `isYoutubeChannelUrl(c.url)`. `jumpTo`, `goToLast` y `show` no cambian.
- [ ] **Step 5:** Mismos tests → PASAN. `flutter analyze`.
- [ ] **Step 6:** Commit `feat(tv): reconocer canales de YouTube y saltarlos en el zapping`.

---

### Task 2: Leer los programas de una pestaña

**Files:**
- Create: `lib/backend/youtube/youtube_program.dart`, `lib/backend/youtube/youtube_page_parser.dart`
- Test: `test/backend/youtube/youtube_page_parser_test.dart`

**Interfaces:**
- Produces:

```dart
enum YoutubeProgramKind { live, video }

class YoutubeProgram {
  const YoutubeProgram({required this.videoId, required this.title,
      required this.kind, this.duration, this.age});
  final String videoId;
  final String title;
  final YoutubeProgramKind kind;
  final String? duration; // «22:45»; null en directos
  final Duration? age;    // antigüedad aproximada; null en directos o si no se entiende
  String get thumbnail => 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
}

class YoutubeParseException implements Exception { /* message */ }

/// Lanza [YoutubeParseException] si no hay `ytInitialData` válido.
List<YoutubeProgram> parseYoutubeTab(String html);

/// «3 hours ago», «Streamed 1 day ago», «2 weeks ago»… → Duration; null si no se entiende.
Duration? parseYoutubeAge(String text);
```

Forma de la página (ver «Hallazgos» del spec): el HTML contiene `var ytInitialData = {JSON};</script>`. En cualquier profundidad del JSON hay objetos `{"lockupViewModel": {...}}` con:

```json
{"contentId": "Ejg0OQPYVgw",
 "contentImage": {"thumbnailViewModel": {"overlays": [{"thumbnailBottomOverlayViewModel":
   {"badges": [{"thumbnailBadgeViewModel": {"text": "22:45", "badgeStyle": "THUMBNAIL_OVERLAY_BADGE_STYLE_DEFAULT"}}]}}]}},
 "metadata": {"lockupMetadataViewModel": {"title": {"content": "Título"},
   "metadata": {"contentMetadataViewModel": {"metadataRows": [{"metadataParts":
     [{"text": {"content": "133K views"}}, {"text": {"content": "16 hours ago"}}]}]}}}}}
```

Reglas de clasificación (página pedida en inglés):
- **Programado → se descarta:** insignia con texto `Upcoming` o alguna parte de metadatos que empiece por `Scheduled for` o `Premieres`.
- **Directo en curso → `live`:** `badgeStyle` que contenga `LIVE`, o texto de insignia `LIVE`, o alguna parte de metadatos que termine en `watching`. `duration` y `age` nulos.
- **Resto → `video`:** `duration` = texto de la insignia si tiene forma `m:ss` / `h:mm:ss`; `age` = primer metadato que `parseYoutubeAge` entienda.
- Sin `contentId` de 11 caracteres `[A-Za-z0-9_-]` o sin título → se descarta el elemento.

`parseYoutubeAge`: quitar el prefijo `Streamed `; `<n> <unidad>[s] ago` con unidades second, minute, hour, day, week (7 d), month (30 d), year (365 d).

- [ ] **Step 1: Tests que fallan.** El test construye el HTML con un ayudante local `_page(List<Map> lockups)` que envuelve `{"contents": {"x": [{"richItemRenderer": {"content": {"lockupViewModel": …}}}]}}` en `<script>var ytInitialData = …;</script>`. Casos:

```dart
test('vídeo normal', () {
  final p = parseYoutubeTab(_page([_lockup('Ejg0OQPYVgw', 'URGENTE: paro', badge: '22:45',
      parts: ['133K views', '16 hours ago'])])).single;
  expect(p.videoId, 'Ejg0OQPYVgw');
  expect(p.title, 'URGENTE: paro');
  expect(p.kind, YoutubeProgramKind.video);
  expect(p.duration, '22:45');
  expect(p.age, const Duration(hours: 16));
  expect(p.thumbnail, 'https://i.ytimg.com/vi/Ejg0OQPYVgw/mqdefault.jpg');
});
test('directo ya emitido', () { /* parts ['4K views','Streamed 7 hours ago'] → video, age 7 h */ });
test('directo en curso', () { /* badge 'LIVE', style '…_LIVE', parts ['1.2K watching'] → live, duration null, age null */ });
test('programado se descarta', () { /* badge 'Upcoming', parts ['Scheduled for 11/11/26, 9:30 AM'] → lista vacía */ });
test('conserva el orden de la página y descarta elementos rotos', () { /* 3 lockups, el 2.º sin contentId → ids [1.º, 3.º] */ });
test('canal vacío', () => expect(parseYoutubeTab(_page([])), isEmpty));
test('sin ytInitialData lanza', () {
  expect(() => parseYoutubeTab('<html>Before you continue</html>'),
      throwsA(isA<YoutubeParseException>()));
  expect(() => parseYoutubeTab('<script>var ytInitialData = {"a": ;</script>'),
      throwsA(isA<YoutubeParseException>()));
});
test('antigüedades', () {
  expect(parseYoutubeAge('1 day ago'), const Duration(days: 1));
  expect(parseYoutubeAge('Streamed 3 weeks ago'), const Duration(days: 21));
  expect(parseYoutubeAge('2 months ago'), const Duration(days: 60));
  expect(parseYoutubeAge('1 year ago'), const Duration(days: 365));
  expect(parseYoutubeAge('133K views'), isNull);
});
```

- [ ] **Step 2:** `flutter test test/backend/youtube/youtube_page_parser_test.dart` → FALLA.
- [ ] **Step 3:** Implementar. Recorrido recursivo del JSON buscando la clave `lockupViewModel`; recorridos equivalentes para `thumbnailBadgeViewModel` y `metadataParts` dentro de cada elemento (no depender de la ruta exacta).
- [ ] **Step 4:** Tests → PASAN.
- [ ] **Step 5: Contraste con YouTube real (manual, no automatizado).** Script suelto en el scratchpad que descargue `/videos` y `/streams` de los cinco canales con las cabeceras de la Tarea 3 y llame a `parseYoutubeTab`: cada pestaña debe dar ≥ 20 programas con título, duración y `age` no nulos. Si algún canal está en directo, comprobar que sale como `live`; si la insignia real difiere de las reglas, ajustar reglas y tests. Anotar el resultado en el mensaje del commit.
- [ ] **Step 6:** Commit `feat(tv): leer los programas de un canal de YouTube`.

---

### Task 3: Servicio de programas (descarga, mezcla, caché)

**Files:**
- Create: `lib/backend/youtube/youtube_channel_service.dart`
- Test: `test/backend/youtube/youtube_channel_service_test.dart`

**Interfaces:**
- Consumes: `youtubeTabUri`, `YoutubeTab`, `parseYoutubeTab`, `YoutubeProgram`.
- Produces:

```dart
class YoutubeUnavailableException implements Exception { /* message */ }

/// Directos primero; después vídeos por antigüedad creciente (los de `age`
/// nula al final); orden estable; sin `videoId` repetidos (gana `live`, si no el primero).
List<YoutubeProgram> mergeYoutubePrograms(
    List<YoutubeProgram> videos, List<YoutubeProgram> streams);

class YoutubeChannelService {
  YoutubeChannelService({http.Client? client, DateTime Function()? clock});
  /// Caché de 2 minutos por canal; [force] la ignora.
  /// Lanza [YoutubeUnavailableException] solo si fallan las dos pestañas.
  Future<List<YoutubeProgram>> programs(String channelUrl, {bool force = false});
}
```

Petición: GET con `User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36`, `Accept-Language: en-US,en;q=0.9`, `Cookie: SOCS=CAI`; límite de 20 s por pestaña; las dos en paralelo. Fallo de una pestaña = código ≠ 200, tiempo agotado, excepción de red o `YoutubeParseException`.

- [ ] **Step 1: Tests que fallan** (con `MockClient` de `package:http/testing.dart`):

```dart
test('mezcla: directo primero, luego por antigüedad, sin duplicados', () {
  final v = [_v('a', hours: 16), _v('b', days: 1), _v('dup', days: 2)];
  final s = [_live('L'), _v('c', hours: 7), _v('d', days: 1), _v('dup', days: 2)];
  expect(mergeYoutubePrograms(v, s).map((p) => p.videoId),
      ['L', 'c', 'a', 'b', 'd', 'dup']);
});
test('age nula va al final', () { /* [_v('x', age: null), _v('y', hours: 1)] + [] → ['y','x'] */ });
test('pide las dos pestañas con hl=en y cabeceras', () { /* el mock registra 2 URIs: …/videos?hl=en y …/streams?hl=en; cookie SOCS=CAI */ });
test('una pestaña caída: devuelve la otra', () { /* streams → 404 */ });
test('las dos caídas: lanza', () { /* throwsA(isA<YoutubeUnavailableException>()) */ });
test('página sin ytInitialData en ambas: lanza', () {});
test('caché de 2 minutos y force', () { /* reloj inyectado: 2.ª llamada sin peticiones; +3 min o force → vuelve a pedir */ });
```

- [ ] **Step 2:** → FALLA. **Step 3:** Implementar. **Step 4:** → PASA.
- [ ] **Step 5:** Commit `feat(tv): servicio de programas de YouTube con mezcla y caché`.

---

### Task 4: Pantalla de programas y enganche en la app

**Files:**
- Create: `lib/screens/tv/youtube/tv_youtube_programs.dart`, `lib/screens/tv/youtube/youtube_age_label.dart`
- Modify: `lib/screens/tv/tv_data.dart`, `lib/screens/tv/player/tv_player.dart` (`openTvPlayer`), `test/screens/tv/fakes.dart`, los 6 ARB + `lib/l10n/gen`
- Test: `test/screens/tv/youtube/tv_youtube_programs_test.dart`, `test/screens/tv/youtube/youtube_age_label_test.dart`

**Interfaces:**
- Consumes: `YoutubeChannelService.programs`, `YoutubeProgram`, `isYoutubeChannelUrl`.
- Produces:
  - `TvData.youtubePrograms(Channel channel, {bool force = false}) → Future<List<YoutubeProgram>>` (servicio estático compartido, como `_catalog`); `FakeTvData` lo implementa con un campo configurable (lista o error).
  - `String youtubeAgeLabel(AppLocalizations l10n, Duration age)`
  - `typedef YoutubePlay = Future<void> Function(BuildContext context, Channel channel, YoutubeProgram program);`
  - `class TvYoutubePrograms extends StatefulWidget { const TvYoutubePrograms({super.key, required this.channel, this.data = const TvData(), this.onPlay}); }` — `onPlay` por defecto es `openTvYoutubePlayer` (Tarea 6; hasta entonces, un marcador que no hace nada).
  - `openTvPlayer`: si `isYoutubeChannelUrl(playlist[index].url)`, empuja `TvYoutubePrograms` y al volver devuelve `index`; si no, como hoy.

Claves ARB nuevas (plantilla en español; traducir en los otros 5):

| Clave | es |
|---|---|
| `ytLive` | `EN VIVO` |
| `ytLiveNow` | `En vivo ahora` |
| `ytLoadFailed` | `No se pudieron cargar los programas de YouTube` |
| `ytEmpty` | `Este canal no tiene programas recientes` |
| `ytAgeMinutes` / `ytAgeHours` / `ytAgeDays` / `ytAgeWeeks` / `ytAgeMonths` / `ytAgeYears` | `hace {n} min` / `hace {n} h` / plurales ICU: `hace {n} día(s)`, `semana(s)`, `mes(es)`, `año(s)` |

«Reintentar» reutiliza `commonRetry`.

`youtubeAgeLabel`: < 1 h → minutos (mínimo 1); < 24 h → horas; < 7 d → días; < 30 d → semanas; < 365 d → meses; si no, años.

Diseño de la pantalla (spec, «Pantalla de programas»): fondo `TvTheme.background`, márgenes `TvTheme.safeArea`, cabecera con `channel.name` en `fontTitle`; `GridView` de **4 columnas**; cada tarjeta es un `TvFocusable` con miniatura 16:9 (`CachedNetworkImage`), insignia de duración abajo a la derecha o insignia roja (`TvTheme.error`) `ytLive` arriba a la izquierda, título a 2 líneas con elipsis y debajo `youtubeAgeLabel` o `ytLiveNow`. Estados: cargando (indicador centrado), error (`ytLoadFailed` + botón `commonRetry` con foco, que llama con `force: true`), vacío (`ytEmpty`). Foco inicial en la primera tarjeta; al volver del reproductor, foco en la tarjeta reproducida.

- [ ] **Step 1: Tests que fallan.**

`youtube_age_label_test.dart` (l10n español): 30 s → `hace 1 min`; 16 h → `hace 16 h`; 1 d → `hace 1 día`; 4 d → `hace 4 días`; 21 d → `hace 3 semanas`; 60 d → `hace 2 meses`; 400 d → `hace 1 año`.

`tv_youtube_programs_test.dart`:

```dart
testWidgets('muestra directo primero con insignia y los vídeos con antigüedad', …);
  // fake devuelve [live L, video a (16 h, '22:45')] → find.text('EN VIVO'), 'En vivo ahora', '22:45', 'hace 16 h'
testWidgets('OK en la primera tarjeta llama a onPlay con ese programa', …);
testWidgets('flecha derecha + OK reproduce el segundo', …);
testWidgets('error: mensaje y Reintentar vuelve a cargar con force', …);
  // 1.ª llamada lanza, 2.ª devuelve lista → tras OK en «Reintentar» aparecen las tarjetas
testWidgets('lista vacía muestra ytEmpty', …);
testWidgets('Atrás durante la carga cierra sin errores', …);
  // Future sin completar; t.binding.handlePopRoute(); completar después; expect(t.takeException(), isNull)
testWidgets('openTvPlayer con canal de YouTube abre la lista de programas', …);
  // playlist [canal normal, canal YT], index 1 → find.byType(TvYoutubePrograms); TvPlayer ausente
```

- [ ] **Step 2:** → FALLA.
- [ ] **Step 3:** Añadir las claves a los 6 ARB y ejecutar `flutter gen-l10n`.
- [ ] **Step 4:** Implementar `youtubeAgeLabel`, `TvData.youtubePrograms`, el fake, la pantalla y la rama de `openTvPlayer`.
- [ ] **Step 5:** `flutter test` completo → PASA (incluido `tv_l10n_test.dart`). `flutter analyze`.
- [ ] **Step 6:** Commit `feat(tv): pantalla de programas de un canal de YouTube`.

---

### Task 5: Los cinco canales y la lista «YouTube»

**Files:**
- Create: `lib/backend/youtube/youtube_seed.dart`
- Modify: `lib/screens/tv/tv_bootstrap.dart` (`_prepare`)
- Test: `test/backend/youtube/youtube_seed_test.dart`

**Interfaces:**
- Consumes: `UserPlaylistsSql.all/create/add/addManualChannel`, `Sql.channelByName(name, sourceName: customSourceName)`, `Sql.getSetting/setSetting`.
- Produces:
  - `const youtubeSeedSettingKey = 'tvYoutubeSeeded';`
  - `const youtubePlaylistName = 'YouTube';`
  - `const List<({String name, String url})> defaultYoutubeChannels` — en este orden: La Encerrona `https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg`; La República `…/UC-B7Xv56uNRDkj0vC3QW8Cg`; Curwen `…/UCHUD6A_lv3OXbzgVXwomtkw`; Paolo Benza `…/UCIpXj6C68YhT8Px3DGCafYA`; Carlos León Moya `…/UCw2gXKyj0RcW2qcohj7Gqtg`.
  - `Future<void> ensureYoutubeChannels()` — si el ajuste vale `'1'`, no hace nada. Si no: para cada canal, reutiliza el canal manual con ese nombre si existe o lo crea; reutiliza la lista propia `YouTube` si existe o la crea; añade los canales en orden; pone el ajuste a `'1'`. No marca favoritos.

En `TvBootstrap._prepare`, tras la preparación de fuentes: `await ensureYoutubeChannels()` dentro de su propio `try/catch` con `debugPrint` (un fallo aquí **no** impide entrar a la app, y el ajuste queda sin marcar para reintentar en el siguiente arranque). Solo cuando `widget.prepare == null`, para no afectar a los tests existentes del arranque.

- [ ] **Step 1: Tests que fallan** (base SQLite temporal):

```dart
test('crea la lista YouTube con los cinco canales en orden', () async {
  await ensureYoutubeChannels();
  final list = (await UserPlaylistsSql.all()).singleWhere((p) => p.name == 'YouTube');
  final chs = await UserPlaylistsSql.channels(list.id);
  expect(chs.map((c) => c.name),
      ['La Encerrona', 'La República', 'Curwen', 'Paolo Benza', 'Carlos León Moya']);
  expect(chs.every((c) => isYoutubeChannelUrl(c.url) && !c.favorite), isTrue);
  expect(await Sql.getSetting('tvYoutubeSeeded'), '1');
});
test('no vuelve a crear lo que el usuario borró', () async {
  /* sembrar; borrar el canal Curwen y la lista; sembrar otra vez → siguen sin existir */ });
test('reutiliza una lista YouTube y un canal con el mismo nombre ya existentes', () async {
  /* crear antes la lista 'YouTube' y un canal manual 'Curwen' con otra URL →
     tras sembrar hay UNA lista YouTube con 5 canales y UN canal 'Curwen' (se conserva la URL del usuario) */ });
```

- [ ] **Step 2:** → FALLA. **Step 3:** Implementar y enganchar en el arranque. **Step 4:** `flutter test` completo → PASA.
- [ ] **Step 5:** Commit `feat(tv): lista «YouTube» con cinco canales al arrancar`.

---

### Task 6: Reproductor de YouTube

**Files:**
- Create: `lib/screens/tv/youtube/youtube_player_page.dart`, `lib/screens/tv/youtube/tv_youtube_player.dart`
- Modify: `pubspec.yaml` (`webview_flutter: ^4.13.0`, `webview_flutter_android: ^4.10.0`), `lib/screens/tv/youtube/tv_youtube_programs.dart` (onPlay por defecto), los 6 ARB + gen
- Test: `test/screens/tv/youtube/youtube_player_page_test.dart`, `test/screens/tv/youtube/tv_youtube_player_test.dart`

**Interfaces:**
- Consumes: `YoutubeProgram`, `Channel`, `YoutubePlay`.
- Produces:

```dart
// youtube_player_page.dart — sin dependencias de Flutter UI
const youtubePlayerOrigin = 'https://fredtv.example.app/'; // el origen probado en la tele
/// Página con el IFrame API. Lanza ArgumentError si [videoId] no es [A-Za-z0-9_-]{11}.
String youtubePlayerHtml(String videoId, {String language = 'es'});

enum YoutubePlayerState { loading, playing, paused, buffering, ended }
sealed class YoutubePlayerEvent {}            // lo que la página envía a Flutter
final class YoutubeStateEvent extends YoutubePlayerEvent { state, position, duration, isLive }
final class YoutubeErrorEvent extends YoutubePlayerEvent { code }
YoutubePlayerEvent? parseYoutubePlayerEvent(String message); // null si no se entiende

enum YoutubeKeyCommand { toggle, back30, forward30 }
YoutubeKeyCommand? youtubeKeyCommand(LogicalKeyboardKey key);
String youtubeCommandJs(YoutubeKeyCommand command); // 'ytToggle()', 'ytSeek(-30)', 'ytSeek(30)'

// tv_youtube_player.dart
abstract class YoutubePlayerSurface {   // costura para tests: la real envuelve WebViewController
  Widget build(BuildContext context);
  Future<void> load(String html, String baseUrl);
  Future<void> run(String js);
  set onMessage(void Function(String) handler);
  Future<void> dispose();               // carga 'about:blank' para cortar el audio
}
Future<void> openTvYoutubePlayer(BuildContext context, Channel channel, YoutubeProgram program);
class TvYoutubePlayer extends StatefulWidget {
  const TvYoutubePlayer({super.key, required this.channel, required this.program,
      this.surface, this.openExternally, this.readyTimeout = const Duration(seconds: 20)});
}
```

Página (probada en la tele, ver spec «Reproducción»): `<div id="p">` a pantalla completa (`position:fixed; inset:0; width:100vw; height:100vh`, fondo negro, `<meta name="viewport" content="width=device-width, initial-scale=1">`), `https://www.youtube.com/iframe_api`, `YT.Player` con `playerVars {autoplay:1, controls:0, rel:0, playsinline:1, fs:0, iv_load_policy:3, disablekb:1, hl:<language>}`, `onReady → playVideo()`. Mensajes a Flutter por el canal JavaScript `FredTv` como JSON: `{"t":"state","s":<-1|0|1|2|3|5>,"pos":<s>,"dur":<s>,"live":<bool>}` en cada cambio de estado y cada 1 s mientras reproduce; `{"t":"error","code":<n>}` en `onError`. Funciones globales `ytToggle()` y `ytSeek(delta)`.

WebView real: JavaScript sin restricciones, fondo negro, `AndroidWebViewController.setMediaPlaybackRequiresUserGesture(false)`, `loadHtmlString(html, baseUrl: youtubePlayerOrigin)`, envuelta en `IgnorePointer`.

Comportamiento de la pantalla:
- Teclas (un `Focus` propio por encima de la WebView): `select`/`enter`/`mediaPlayPause` → toggle; `arrowLeft`/`mediaRewind` → −30 s; `arrowRight`/`mediaFastForward` → +30 s. Atrás (pop de la ruta) cierra.
- Barra inferior propia, visible 4 s tras cada tecla y siempre en pausa: título del programa, y `mm:ss / mm:ss` o la insignia `ytLive` si es directo.
- Indicador de carga hasta el primer `playing`.
- `ended` → `Navigator.pop`.
- `WakelockPlus.enable()` al entrar y `disable()` al salir.
- `YoutubeErrorEvent` **o** `readyTimeout` sin ningún mensaje de estado → panel con `ytPlayerFailed`, botón «Abrir en YouTube» (`ytOpenInYoutube`, foco inicial) y «Volver» (`ytBack`). «Abrir en YouTube» llama a `openExternally(videoId)`; por defecto `launchUrl(Uri.parse('https://www.youtube.com/watch?v=<id>'), mode: LaunchMode.externalApplication)` y después hace `pop`.
- `dispose`: cancelar temporizadores y `surface.dispose()`.

Claves ARB nuevas: `ytPlayerFailed` = `No se pudo reproducir este vídeo aquí`; `ytOpenInYoutube` = `Abrir en YouTube`; `ytBack` = `Volver`; `ytPaused` = `En pausa`.

- [ ] **Step 1: Tests que fallan.**

`youtube_player_page_test.dart`:

```dart
test('la página lleva el vídeo, el idioma y el API', () {
  final h = youtubePlayerHtml('Ejg0OQPYVgw', language: 'pt');
  expect(h, contains("videoId:'Ejg0OQPYVgw'"));
  expect(h, contains("hl:'pt'"));
  expect(h, contains('https://www.youtube.com/iframe_api'));
});
test('rechaza ids que no son de YouTube', () {
  for (final bad in ['', "x';alert(1);//", 'Ejg0OQPYVg', '../../etc/passwd']) {
    expect(() => youtubePlayerHtml(bad), throwsArgumentError);
  }
});
test('interpreta los mensajes', () {
  final e = parseYoutubePlayerEvent('{"t":"state","s":1,"pos":82.4,"dur":1365,"live":false}') as YoutubeStateEvent;
  expect(e.state, YoutubePlayerState.playing);
  expect(e.position, const Duration(seconds: 82));
  expect(e.duration, const Duration(seconds: 1365));
  expect((parseYoutubePlayerEvent('{"t":"state","s":0,"pos":0,"dur":0,"live":false}') as YoutubeStateEvent).state, YoutubePlayerState.ended);
  expect((parseYoutubePlayerEvent('{"t":"error","code":150}') as YoutubeErrorEvent).code, 150);
  expect(parseYoutubePlayerEvent('basura'), isNull);
  expect(parseYoutubePlayerEvent('{"t":"state"}'), isNull);
});
test('teclas del mando', () {
  expect(youtubeKeyCommand(LogicalKeyboardKey.select), YoutubeKeyCommand.toggle);
  expect(youtubeKeyCommand(LogicalKeyboardKey.arrowLeft), YoutubeKeyCommand.back30);
  expect(youtubeKeyCommand(LogicalKeyboardKey.arrowRight), YoutubeKeyCommand.forward30);
  expect(youtubeKeyCommand(LogicalKeyboardKey.arrowUp), isNull);
  expect(youtubeCommandJs(YoutubeKeyCommand.back30), 'ytSeek(-30)');
});
```

`tv_youtube_player_test.dart` (con una `FakeSurface` que guarda `load`/`run` y permite emitir mensajes):

```dart
testWidgets('carga la página del vídeo con el origen', …);       // fake.loadedBaseUrl == youtubePlayerOrigin; html contiene el id
testWidgets('OK envía ytToggle() y derecha ytSeek(30)', …);
testWidgets('en pausa muestra título y «En pausa»', …);          // emitir state s=2
testWidgets('al terminar vuelve atrás', …);                      // emitir s=0 → la ruta se cierra
testWidgets('error 150 ofrece Abrir en YouTube y lo lanza con el id', …);
testWidgets('sin mensajes en 20 s muestra el mismo aviso', …);   // t.pump(const Duration(seconds: 21))
testWidgets('Atrás mientras carga libera la superficie', …);     // fake.disposed == true; takeException() == null
```

- [ ] **Step 2:** → FALLA.
- [ ] **Step 3:** `flutter pub add webview_flutter:^4.13.0 webview_flutter_android:^4.10.0`; comprobar que no cambia la versión de `video_player`, `media_kit*` ni del SDK en `pubspec.lock`.
- [ ] **Step 4:** ARB + `flutter gen-l10n`; implementar página, eventos, teclas, superficie real y pantalla; poner `openTvYoutubePlayer` como `onPlay` por defecto de `TvYoutubePrograms`.
- [ ] **Step 5:** `flutter test` completo → PASA. `flutter analyze`.
- [ ] **Step 6:** Commit `feat(tv): reproductor de YouTube incrustado con mando`.

---

### Task 7: Comprobación en la tele

**Files:** ninguno nuevo; correcciones donde toque (con su test si el fallo es de lógica).

- [ ] **Step 1:** Build limpio de release según la memoria `fred-tv-build-and-tv-testing` (Gradle ~110 s; revertir `android/gradle.properties` al acabar). Verificar que `EN VIVO` aparece en `libapp.so`.
- [ ] **Step 2:** `adb install -r` en `192.168.1.60:5555`. Desinstalar la prueba desechable: `adb uninstall com.example.ytspike`.
- [ ] **Step 3:** Recorrer la «Comprobación final en la tele» del spec (6 puntos) con `input keyevent` y capturas, verificando antes con `dumpsys activity activities | grep mResumedActivity` que la app está delante:
  1. lista «YouTube» con cinco canales;
  2. mosaico ordenado en cada canal;
  3. **directo en curso primero con «EN VIVO»** — hacerlo cuando un canal emita (La República, mañanas de Lima); si ninguno emite, decirlo en el informe como no comprobado;
  4. grabado en alta calidad (`hd720` o más en logcat), OK pausa, flechas saltan, un Atrás vuelve a la lista;
  5. zapping entre canales normales sin detenerse en YouTube;
  6. **imagen sin recorte**: captura de un directo con rótulo inferior; si se recorta, corregir el tamaño de la página (viewport / `width`/`height` del reproductor) y repetir.
- [ ] **Step 4:** Probar el aviso de error cortando la red de la tele o con un vídeo no incrustable, y «Abrir en YouTube».
- [ ] **Step 5:** Commit de las correcciones (si las hubo) e informe al usuario con lo comprobado y lo que no.
