# Programas dentro de un canal de YouTube — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La pantalla de un canal de YouTube muestra hasta 5 filas por programa (el prioritario arriba), después el mosaico mezclado, y deja reordenar los programas manteniendo OK.

**Architecture:** Lógica pura en `youtube_show.dart` (claves, pertenencia, orden, mover). El servicio existente añade la pestaña de listas, hasta 6 páginas de lista y un reintento, y devuelve una `YoutubeChannelPage`. El orden del usuario vive en un ajuste JSON y se aplica al mostrar. La pantalla pasa de un `GridView` a un `CustomScrollView` con filas horizontales + mosaico.

**Tech Stack:** Flutter 3.32, `package:http` (+ `MockClient` en tests), sqflite vía `Sql.getSetting/setSetting`, gen-l10n (6 ARB).

**Spec:** `docs/superpowers/specs/2026-11-11-programas-youtube-design.md`

## Global Constraints

- Flutter 3.32; sin dependencias nuevas.
- Máximo 5 filas de programa; hasta 20 emisiones por fila; máximo 6 páginas de lista por carga; «reciente» = menos de 30 días; claves de menos de 5 caracteres no reconocen por título.
- Caché de 2 minutos como hoy; un solo reintento por página, tras 1 s.
- La letra grande no corta textos: altos derivados de `MediaQuery.textScalerOf`.
- Cadenas nuevas en los 6 ARB (`es`, `en`, `pt`, `fr`, `de`, `it`); nombres de programas sin traducir.
- No tocar reproductor ni zapping. Nunca `git push`. En la tele, `adb install -r`, nunca borrar datos.
- Commits con `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.

## Review Focus

1. Una lista del canal con título vacío o solo símbolos («H&H» → clave `hh`): no debe reconocer por título ni romper nada. → Tarea 1.
2. El orden guardado nombra un programa que ya no existe o no tiene emisiones: se ignora sin dejar hueco y sin perderse del ajuste. → Tarea 1.
3. `/playlists` devuelve una página sin datos dos veces: la pantalla carga igual con los incorporados. → Tarea 3.
4. Ajuste `tvYoutubeShowOrder` corrupto (no JSON, o JSON con otra forma): se trata como vacío y el siguiente guardado lo repara. → Tarea 4.
5. Mover una fila mientras el foco está en una tarjeta que cambia de posición: el foco sigue en la misma emisión. → Tarea 5.

---

## Estructura de archivos

| Archivo | Responsabilidad |
|---|---|
| `lib/backend/youtube/youtube_show.dart` (nuevo) | Tipos y lógica pura de programas |
| `lib/backend/youtube/youtube_channel.dart` | + direcciones de listas y clave de canal |
| `lib/backend/youtube/youtube_page_parser.dart` | + `parseYoutubePlaylists` |
| `lib/backend/youtube/youtube_channel_service.dart` | + reintento, `channelPage` |
| `lib/backend/youtube/youtube_show_order.dart` (nuevo) | Leer/guardar el orden en ajustes |
| `lib/screens/tv/tv_data.dart`, `test/screens/tv/fakes.dart` | Enganche de datos |
| `lib/screens/tv/youtube/tv_youtube_programs.dart` | Filas, mosaico, menú |
| `lib/l10n/app_*.arb` | 4 cadenas |

---

### Task 1: Lógica pura de programas

**Files:** Create `lib/backend/youtube/youtube_show.dart`; Test `test/backend/youtube/youtube_show_test.dart`.

**Interfaces — Produces:**

```dart
/// Minúsculas, sin tildes (á→a, ñ→n, ü→u…), solo [a-z0-9].
String normalizeYoutubeText(String text);

/// Clave de un título de lista: normalizado y sin los finales `envivo` / `podcast`
/// (si al quitarlo queda vacío, se deja como estaba).
String youtubeShowKey(String title);

class YoutubeShowDef {            // programa conocido, sin emisiones
  const YoutubeShowDef({required this.key, required this.name, this.playlistIds = const []});
  final String key; final String name; final List<String> playlistIds;
}

class YoutubeShow {               // programa con sus emisiones ya ordenadas
  const YoutubeShow({required this.key, required this.name, required this.programs});
  final String key; final String name; final List<YoutubeProgram> programs;
}

/// Programas conocidos del canal [channelKey] (`/channel/UC…` o `/@handle`):
/// listas agrupadas por clave + incorporados. Orden: el de [playlists], luego incorporados sin lista.
List<YoutubeShowDef> youtubeShowDefs(String channelKey, List<({String id, String title})> playlists);

/// Clave del prioritario inicial, o null.
String? defaultYoutubeShowKey(String channelKey);

/// Clave del programa al que apunta el título de [program] (la más larga contenida,
/// de 5+ caracteres), o null.
String? youtubeShowKeyForTitle(String title, Iterable<String> keys);

/// Filas a mostrar: ver «Orden de las filas» del spec. [order] = orden guardado
/// (o `[default]`). Corta a [max].
List<YoutubeShow> arrangeYoutubeShows(List<YoutubeShow> shows,
    {List<String> order = const [], int max = 5});

enum YoutubeShowMove { first, up, down }

/// Nuevo orden de [visibleKeys] tras mover [key]; igual si no se puede.
List<String> moveYoutubeShow(List<String> visibleKeys, String key, YoutubeShowMove move);
```

Valores fijos: incorporados de `/channel/UC-B7Xv56uNRDkj0vC3QW8Cg` → «Sin Guion», «Fuerte y Claro», «Que No Se Te Olvide», «La Verdad a Fondo», «Arde Troya». Nombre fijado: `laencerrona` → «La Encerrona». Prioritarios: `/channel/UCP0AJJeNkFBYzegTTVbKhPg` → `laencerrona`; `/channel/UC-B7Xv56uNRDkj0vC3QW8Cg` → `singuion`; `/channel/UCIpXj6C68YhT8Px3DGCafYA` → `lacontra`. Nombre de un grupo de listas: el título más corto, sin `#` inicial y sin el final « EN VIVO» / « Podcast» (sin distinguir mayúsculas).

- [ ] **Step 1: Tests que fallan**

```dart
test('normaliza', () {
  expect(normalizeYoutubeText('¿Qué PASÓ? #LaEncerrona ñ'), 'quepasolaencerronan');
});
test('clave de lista', () {
  expect(youtubeShowKey('#LaEncerrona'), 'laencerrona');
  expect(youtubeShowKey('La Contra EN VIVO'), 'lacontra');
  expect(youtubeShowKey('La Contra Podcast'), 'lacontra');
  expect(youtubeShowKey('Contraataque EN VIVO'), 'contraataque');
  expect(youtubeShowKey('Podcast'), 'podcast');
});
test('agrupa listas con la misma clave y fija nombres', () {
  final defs = youtubeShowDefs('/channel/UCIpXj6C68YhT8Px3DGCafYA', [
    (id: 'PLa', title: 'La Contra EN VIVO'), (id: 'PLb', title: 'La Contra Podcast'),
    (id: 'PLc', title: 'Helado B')]);
  expect(defs.map((d) => d.key), ['lacontra', 'heladob']);
  expect(defs.first.name, 'La Contra');
  expect(defs.first.playlistIds, ['PLa', 'PLb']);
  expect(youtubeShowDefs('/channel/UCP0AJJeNkFBYzegTTVbKhPg',
      [(id: 'PLx', title: '#LaEncerrona')]).single.name, 'La Encerrona');
});
test('incorporados de La República; listas vacías o raras no rompen', () {
  final defs = youtubeShowDefs('/channel/UC-B7Xv56uNRDkj0vC3QW8Cg',
      [(id: 'PL1', title: ''), (id: 'PL2', title: '¡¡!!'), (id: 'PL3', title: 'H&H')]);
  expect(defs.map((d) => d.key), containsAll(['singuion', 'fuerteyclaro',
      'quenoseteolvide', 'laverdadafondo', 'ardetroya', 'hh']));
  expect(defs.any((d) => d.key.isEmpty), isFalse);
});
test('pertenencia por título: gana la clave más larga; cortas no cuentan', () {
  const keys = ['lacontra', 'lacontraopina', 'hh', 'singuion'];
  expect(youtubeShowKeyForTitle('X | #LaContraOpina 3/11', keys), 'lacontraopina');
  expect(youtubeShowKeyForTitle('KEIKO SE VA | SIN GUION CON ROSA MARÍA PALACIOS', keys), 'singuion');
  expect(youtubeShowKeyForTitle('ehh hhola', keys), isNull);
});
test('orden de filas', () {
  // helper p(id, {age, live}) y show(key, [programs])
  final shows = [
    show('viejo', [p('a', age: const Duration(days: 40))]),
    show('ayer', [p('b', age: const Duration(days: 1))]),
    show('hoy', [p('c', age: const Duration(hours: 2))]),
    show('vivo', [p('d', live: true)]),
    show('vacio', []),
    show('sinedad', [p('e')]),
  ];
  expect(arrangeYoutubeShows(shows).map((s) => s.key), ['vivo', 'hoy', 'ayer']);
  expect(arrangeYoutubeShows(shows, order: ['viejo', 'noexiste', 'vacio', 'ayer'])
      .map((s) => s.key), ['viejo', 'ayer', 'vivo', 'hoy']);
  expect(arrangeYoutubeShows(shows, max: 2).length, 2);
});
test('mover', () {
  const k = ['a', 'b', 'c'];
  expect(moveYoutubeShow(k, 'c', YoutubeShowMove.first), ['c', 'a', 'b']);
  expect(moveYoutubeShow(k, 'b', YoutubeShowMove.up), ['b', 'a', 'c']);
  expect(moveYoutubeShow(k, 'b', YoutubeShowMove.down), ['a', 'c', 'b']);
  expect(moveYoutubeShow(k, 'a', YoutubeShowMove.up), k);
  expect(moveYoutubeShow(k, 'c', YoutubeShowMove.down), k);
  expect(moveYoutubeShow(k, 'zz', YoutubeShowMove.first), k);
});
```

- [ ] **Step 2:** `flutter test test/backend/youtube/youtube_show_test.dart` → FALLA (no existe el archivo).
- [ ] **Step 3:** Implementar. Empate de recencia en `arrangeYoutubeShows`: por `name`. Recencia de un programa = menor `age` de sus emisiones; un directo = `Duration.zero`; sin edad = no reciente.
- [ ] **Step 4:** Mismo test → PASA. `flutter analyze lib/backend/youtube`.
- [ ] **Step 5:** Commit `feat(tv): reconocer y ordenar los programas de un canal de YouTube`.

---

### Task 2: Leer las listas de un canal

**Files:** Modify `lib/backend/youtube/youtube_channel.dart`, `lib/backend/youtube/youtube_page_parser.dart`; Test `test/backend/youtube/youtube_channel_test.dart`, `test/backend/youtube/youtube_page_parser_test.dart`.

**Interfaces — Produces:**

```dart
// youtube_channel.dart
String youtubeChannelKey(String channelUrl);      // '/channel/UC…' o '/@handle'; ArgumentError si no es canal
Uri youtubePlaylistsUri(String channelUrl);       // https://www.youtube.com<key>/playlists?hl=es
Uri youtubePlaylistUri(String playlistId);        // https://www.youtube.com/playlist?list=<id>&hl=es
// youtube_page_parser.dart
List<({String id, String title})> parseYoutubePlaylists(String html); // lanza YoutubeParseException como parseYoutubeTab
```

`parseYoutubePlaylists`: `lockupViewModel` cuyo `contentId` casa `^PL[A-Za-z0-9_-]{8,}$` y con título no vacío; en el orden de la página, sin repetir id. `parseYoutubeTab` no cambia (ya ignora ids que no son de vídeo). Extraer de `parseYoutubeTab` la parte común «HTML → Map» a una función privada.

- [ ] **Step 1: Tests que fallan** (con el ayudante `_page` que ya existe en el test del lector):

```dart
test('lee las listas del canal y salta lo que no es lista', () {
  final html = _page([
    {'contentId': 'PL4_L4CSNdHPUIm8ajOHFvHniKhc8Z26hY', 'contentType': 'LOCKUP_CONTENT_TYPE_PODCAST',
     'metadata': {'lockupMetadataViewModel': {'title': {'content': '#LaEncerrona'}}}},
    {'contentId': 'PLb7sHDpNJW0s',
     'metadata': {'lockupMetadataViewModel': {'title': {'content': ' ESPECIALES CANAL YA '}}}},
    {'contentId': 'aaaaaaaaaaa',
     'metadata': {'lockupMetadataViewModel': {'title': {'content': 'un vídeo'}}}},
    {'contentId': 'PLsinTitulo99', 'metadata': {}},
    {'contentId': 'PLb7sHDpNJW0s',
     'metadata': {'lockupMetadataViewModel': {'title': {'content': 'repetida'}}}},
  ]);
  expect(parseYoutubePlaylists(html), [
    (id: 'PL4_L4CSNdHPUIm8ajOHFvHniKhc8Z26hY', title: '#LaEncerrona'),
    (id: 'PLb7sHDpNJW0s', title: 'ESPECIALES CANAL YA'),
  ]);
  expect(() => parseYoutubePlaylists('<html></html>'), throwsA(isA<YoutubeParseException>()));
});
// youtube_channel_test.dart
test('direcciones de listas', () {
  expect(youtubeChannelKey('https://youtube.com/@DWEspanol/videos'), '/@DWEspanol');
  expect(youtubePlaylistsUri('https://www.youtube.com/channel/UCabc').toString(),
      'https://www.youtube.com/channel/UCabc/playlists?hl=es');
  expect(youtubePlaylistUri('PLx1').toString(), 'https://www.youtube.com/playlist?list=PLx1&hl=es');
  expect(() => youtubeChannelKey('https://example.com'), throwsArgumentError);
});
```

- [ ] **Step 2:** → FALLA. **Step 3:** Implementar. **Step 4:** → PASA (todo `test/backend/youtube`).
- [ ] **Step 5: Contraste con YouTube real (manual).** Script suelto en el scratchpad (`dart run` o `flutter test` con un test temporal fuera del repo) que descargue `/playlists` de los cinco canales y una lista de cada uno y llame a los lectores: ≥ 5 listas en La Encerrona, Paolo Benza y Curwen; la lista `PLWanORKprxNDeq_3mNAqL294WmaluP1H-` da ≥ 20 emisiones con duración y `age`. Anotar el resultado en el commit.
- [ ] **Step 6:** Commit `feat(tv): leer las listas de un canal de YouTube`.

---

### Task 3: Servicio — página del canal con programas y reintento

**Files:** Modify `lib/backend/youtube/youtube_channel_service.dart`; Test `test/backend/youtube/youtube_channel_service_test.dart`.

**Interfaces — Consumes:** Tareas 1 y 2. **Produces:**

```dart
class YoutubeChannelPage {
  const YoutubeChannelPage({required this.programs, required this.shows});
  final List<YoutubeProgram> programs;   // mezcla de siempre
  final List<YoutubeShow> shows;         // todos los programas con ≥1 emisión, sin ordenar para mostrar
}

// en YoutubeChannelService
static const maxPlaylistPages = 6;
static const maxShowPrograms = 20;
YoutubeChannelService({http.Client? client, DateTime Function()? clock, Duration timeout, Duration retryDelay = const Duration(seconds: 1)});
Future<YoutubeChannelPage> channelPage(String channelUrl, {List<String> preferred = const [], bool force = false});
Future<List<YoutubeProgram>> programs(String channelUrl, {bool force = false}); // se mantiene: = (await channelPage).programs
```

Algoritmo de `channelPage`: (1) en paralelo `/videos`, `/streams`, `/playlists`, cada una con un reintento si no es 200 o el lector lanza; (2) si fallan vídeos y directos → `YoutubeUnavailableException`; (3) `defs = youtubeShowDefs(key, playlists ?? [])`; (4) asignar cada emisión reciente con `youtubeShowKeyForTitle`; (5) elegir hasta 6 ids de lista en el orden del spec — claves de `preferred` (el llamador ya incluye ahí el prioritario inicial), luego programas con emisiones por título del más reciente al más antiguo, luego el resto en el orden de `defs` — y leerlas en paralelo; (6) emisiones de cada programa = `mergeYoutubePrograms(porTítulo, deListas)` cortadas a 20; un directo visto en las pestañas conserva su estado de directo (ya lo hace `mergeYoutubePrograms` si se pasa como primer argumento lo reciente); (7) caché de 2 min de la página entera por `youtubeChannelKey`.

- [ ] **Step 1: Tests que fallan** (`MockClient`; ayudantes `_tabHtml(videos)` y `_playlistsHtml(listas)` en el test; `retryDelay: Duration.zero`):
  - `channelPage` de un canal con listas «#LaEncerrona» (`PLenc`) y «Pequeñas Islas» (`PLisl`): la emisión `… #LaEncerrona` de `/videos` que no está en `PLenc` aparece en el programa `laencerrona` junto a las de la lista, sin repetir, la más reciente primero.
  - Un programa cuyas emisiones solo están en su lista (títulos sin el nombre) obtiene emisiones cuando su clave va en `preferred`.
  - Con 9 listas y ninguna pista, se piden exactamente 6 páginas `/playlist`.
  - `/playlists` responde dos veces sin `ytInitialData` → no lanza; `shows` solo trae incorporados con emisiones por título (probar con el canal de La República y un título `… | SIN GUION`).
  - `/streams` responde primero sin datos y a la segunda bien → sus emisiones están en `programs` y la dirección se pidió 2 veces.
  - `/videos` y `/streams` fallan dos veces → `YoutubeUnavailableException`.
  - Segunda llamada dentro de 2 min no hace peticiones; con `force: true` sí.
  - Los tests existentes de `programs()` siguen pasando (el `MockClient` de esos tests debe responder 404 a `/playlists`).
- [ ] **Step 2:** → FALLA. **Step 3:** Implementar. **Step 4:** → PASA. `flutter analyze`.
- [ ] **Step 5:** Commit `feat(tv): programas de un canal de YouTube en el servicio, con reintento`.

---

### Task 4: Orden guardado y enganche de datos

**Files:** Create `lib/backend/youtube/youtube_show_order.dart`; Modify `lib/screens/tv/tv_data.dart`, `test/screens/tv/fakes.dart`; Test `test/backend/youtube/youtube_show_order_test.dart`.

**Interfaces — Produces:**

```dart
const youtubeShowOrderSettingKey = 'tvYoutubeShowOrder';
/// Orden guardado de [channelKey] dentro del JSON [raw]; [] si no hay o [raw] es ilegible.
List<String> decodeYoutubeShowOrder(String? raw, String channelKey);
/// JSON resultante de fijar [order] para [channelKey] conservando los demás canales
/// (si [raw] es ilegible se parte de vacío).
String encodeYoutubeShowOrder(String? raw, String channelKey, List<String> order);

// TvData (y FakeTvData con campos `onYoutubeChannelPage`, `youtubeOrders` en memoria)
Future<YoutubeChannelPage> youtubeChannelPage(Channel channel, {bool force = false});
Future<List<String>> youtubeShowOrder(Channel channel);          // guardado, o [default] si existe, o []
Future<void> setYoutubeShowOrder(Channel channel, List<String> order);
```

`TvData.youtubeChannelPage` lee el orden y lo pasa como `preferred`. `TvData.youtubePrograms` se elimina si ya nadie lo usa tras la Tarea 5 (hacerlo en la Tarea 5).

- [ ] **Step 1: Tests que fallan:**

```dart
test('orden por canal', () {
  var raw = encodeYoutubeShowOrder(null, '/channel/UCa', ['x', 'y']);
  raw = encodeYoutubeShowOrder(raw, '/@b', ['z']);
  expect(decodeYoutubeShowOrder(raw, '/channel/UCa'), ['x', 'y']);
  expect(decodeYoutubeShowOrder(raw, '/@b'), ['z']);
  expect(decodeYoutubeShowOrder(raw, '/@otro'), isEmpty);
});
test('ajuste corrupto', () {
  for (final bad in ['no json', '[1,2]', '{"/@b": "x"}', '{"/@b": [1, "ok"]}']) {
    expect(decodeYoutubeShowOrder(bad, '/@b'), anyOf(isEmpty, ['ok']), reason: bad);
    expect(decodeYoutubeShowOrder(encodeYoutubeShowOrder(bad, '/@c', ['k']), '/@c'), ['k']);
  }
});
```

- [ ] **Step 2:** → FALLA. **Step 3:** Implementar (los elementos que no son texto se descartan). **Step 4:** → PASA; `flutter test` completo sigue en verde.
- [ ] **Step 5:** Commit `feat(tv): guardar el orden de los programas de cada canal de YouTube`.

---

### Task 5: Pantalla con filas por programa y menú para mover

**Files:** Modify `lib/screens/tv/youtube/tv_youtube_programs.dart`, `lib/l10n/app_{es,en,pt,fr,de,it}.arb`, `lib/screens/tv/tv_data.dart`, `test/screens/tv/fakes.dart`; Test `test/screens/tv/youtube/tv_youtube_programs_test.dart`.

**Interfaces — Consumes:** `TvData.youtubeChannelPage / youtubeShowOrder / setYoutubeShowOrder`, `arrangeYoutubeShows`, `moveYoutubeShow`, `showTvOptions`.

Cadenas (clave → es / en / pt / fr / de / it):
- `ytAllRecent` → Todo lo último / Latest / Mais recentes / Les plus récents / Neueste / Più recenti
- `ytShowMoveFirst` → Poner primero / Move to top / Colocar primeiro / Mettre en premier / Ganz nach oben / Metti per primo
- `ytShowMoveUp` → Subir / Move up / Subir / Monter / Nach oben / Sposta su
- `ytShowMoveDown` → Bajar / Move down / Descer / Descendre / Nach unten / Sposta giù

Comportamiento: ver «Qué ve el usuario», «Mover un programa» y «Restricciones» del spec. Decisiones de construcción:
- `CustomScrollView`: por cada fila, título (`Key('yt-show-<clave>')`, `TvTheme.fontBody`, negrita) + `ListView` horizontal de alto `_ProgramCard.height(ancho, scaler)` con tarjetas del mismo ancho que las del mosaico; después título `ytAllRecent` (solo si hay filas) y `SliverGrid` actual.
- Claves de tarjeta: fila → `ValueKey('yt-<clave>-<videoId>')`; mosaico → `ValueKey('yt-<videoId>')` (como hoy, para no romper tests).
- Un `FocusNode` por tarjeta (fila y mosaico por separado). Foco inicial: primera tarjeta de la primera fila, o del mosaico si no hay filas. Al enfocar, `Scrollable.ensureVisible` de modo que el título de la fila también quede a la vista.
- OK largo en tarjeta de fila → `showTvOptions<YoutubeShowMove>(title: nombre del programa, …)`; con el resultado: `moveYoutubeShow(clavesVisibles, clave, move)`, `setYoutubeShowOrder`, `setState` con `arrangeYoutubeShows` de nuevo y foco de vuelta a la misma tarjeta.
- Si el menú no tendría ninguna opción (una sola fila), el OK largo no hace nada.

- [ ] **Step 1: Tests que fallan** (el `FakeTvData` devuelve una `YoutubeChannelPage` con programas `enc` [e1 hoy, e2 ayer], `cen` [c1 hace 2 días], `isl` [i1 hace 3 días] y `programs` = todas):
  - muestra los títulos de fila en el orden `enc, cen, isl` con orden guardado `['enc']`, luego «Todo lo último» y el mosaico; el foco inicial está en `yt-enc-e1`.
  - sin programas (`shows: []`) no aparece «Todo lo último» y el mosaico se ve como antes (los tests actuales siguen pasando, adaptando el fake).
  - flecha abajo desde `yt-enc-e1` enfoca una tarjeta de la fila `cen`; flecha derecha en `enc` enfoca `yt-enc-e2`.
  - OK en `yt-cen-c1` llama a `onPlay` con `c1` y al volver el foco sigue en `yt-cen-c1`.
  - OK largo en `yt-cen-c1` → menú con «Poner primero», «Subir», «Bajar»; elegir «Poner primero» deja el orden de filas `cen, enc, isl`, guarda `['cen', 'enc', 'isl']` en el fake y el foco queda en `yt-cen-c1`.
  - OK largo en la primera fila no ofrece «Subir» ni «Poner primero»; en la última no ofrece «Bajar».
  - OK largo en una tarjeta del mosaico no abre menú.
  - con `textScaler` 1.6 no hay desbordes (`tester.takeException()` nulo) en 1920×1080 lógico/2.
  - `tv_l10n_test.dart` pasa (las 4 claves en los 6 idiomas).
- [ ] **Step 2:** → FALLA. **Step 3:** ARB + `flutter gen-l10n`; implementar; quitar `youtubePrograms` de `TvData`/fake si quedó sin uso. **Step 4:** `flutter test` completo → PASA. `flutter analyze` sin incidencias nuevas.
- [ ] **Step 5:** Commit `feat(tv): canal de YouTube separado por programas, con orden a elección`.

---

### Task 6: Comprobación en la tele

- [ ] **Step 1:** Build limpio de release (receta de la memoria `fred-tv-build-and-tv-testing`; Gradle ~110 s; revertir `android/gradle.properties`). Verificar que `ytShowMoveFirst`/«Poner primero» aparece en `libapp.so`.
- [ ] **Step 2:** `adb install -r` en `192.168.1.60:5555`.
- [ ] **Step 3:** Recorrer los 7 puntos de «Comprobación final en la tele» del spec con capturas, comprobando antes que la app está delante.
- [ ] **Step 4:** Commit de correcciones (si las hubo) e informe con lo comprobado y lo que no.
