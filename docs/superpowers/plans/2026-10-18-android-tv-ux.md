# Fred TV — Plan de mejoras UI/UX para Android TV

> **Para agentes:** SUB-SKILL REQUERIDA: usa superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea por tarea. Los pasos usan checkboxes (`- [ ]`) para seguimiento.

**Objetivo:** que la app se use cómodamente con el control remoto de Android TV: navegación D-pad predecible en todos los menús, búsqueda que funcione, reproducción estable con errores visibles y zapping, catálogo de listas de iptv-org con actualización automática de enlaces, y listas de canales propias.

**Arquitectura:** se elimina el interceptor global de flechas de `TVHome` y se usa la navegación direccional nativa de Flutter (`DirectionalFocusIntent`), con un `FocusScope` por región (menú lateral y una por pestaña), `ExcludeFocus` para las pestañas ocultas y una acción "de borde" que salta al menú lateral cuando no hay nada más a la izquierda. Todos los elementos enfocables de TV usan un widget común `TvFocusable`. Las pantallas TV acceden a datos solo mediante una fachada inyectable `TvData` (tests sin base de datos). El reproductor TV es una pantalla propia (`TvPlayer`) sobre media_kit **sin** la ruta de pantalla completa de media_kit. Las fuentes se refrescan con un servicio `SourceRefresher` (secuencial, sin solaparse). Las listas propias guardan `(source_id, nombre del canal)`, así que siguen funcionando cuando la fuente se actualiza y cambian los enlaces.

**Tech stack:** Flutter 3.32.4 / Dart 3.8, media_kit 1.2 + media_kit_video 1.3, sqlite_async, http, cached_network_image, flutter_test.

**Spec:** este mismo documento (sección "Análisis UI/UX" y "Funciones nuevas"). No hay otro spec.

---

## Análisis UI/UX (hallazgos verificados)

Los hallazgos marcados con 🧪 se verificaron con pruebas de widgets en un proyecto aparte (Flutter 3.32.4).

| # | Severidad | Hallazgo | Dónde |
|---|---|---|---|
| H1 | 🔴 Crítico | **La búsqueda nunca devuelve resultados.** `TVSearch` crea `Filters` sin `mediaTypes`; `Sql.search` hace `filters.mediaTypes!` → excepción → el `catch` la oculta → siempre "No results found". | `lib/screens/tv/tv_search.dart:63-68`, `lib/backend/sql.dart:155-156` |
| H2 | 🔴 Crítico | 🧪 **El `Shortcuts` raíz de `TVHome` captura las 4 flechas** con `CallbackAction` siempre habilitadas, así que la navegación direccional de Flutter nunca corre. En Búsqueda (resultados) y Ajustes (campos y botón) las flechas no mueven el foco. | `lib/screens/tv/tv_home.dart:68-91` |
| H3 | 🔴 Crítico | **Entrar a Búsqueda o Ajustes manda el foco al explorador de canales oculto.** `_getCurrentContentFocusNode()` devuelve `_channelBrowserFocusNode` para los índices 2 y 3. | `tv_home.dart:48-57` |
| H4 | 🔴 Crítico | 🧪 **Una pestaña oculta roba el foco al arrancar.** `IndexedStack` deja enfocables a los hijos ocultos; `TVSearch.initState` hace `requestFocus()` en su `TextField`. | `tv_search.dart:27-30` |
| H5 | 🟠 Alto | **Atrás no funciona dentro del explorador.** Los `onKeyEvent` de grupos y canales devuelven `handled` para *cualquier* tecla (incluye `goBack` y multimedia). | `lib/screens/tv/tv_channel_browser.dart:347`, `:478` |
| H6 | 🟠 Alto | 🧪 **Un `TextField` de una línea atrapa ↑/↓** y al enfocarse abre el teclado aunque el usuario solo esté pasando. | `tv_search.dart`, `tv_settings.dart` |
| H7 | 🟠 Alto | **Reproductor en TV:** `enterFullscreen()` de media_kit hace *push* de otra ruta → el `KeyboardListener` de `Player` deja de recibir teclas; los controles de media_kit son táctiles (audio/subtítulos/zoom inaccesibles con D-pad). Cuando sí recibe teclas, ←/→ hacen *seek* en directo (cortes), OK pausa el directo y ↑/↓ cambian el volumen interno. | `lib/player.dart:112-160` (cambios respecto al original) |
| H8 | 🟠 Alto | **Sin feedback de error en reproducción.** Si un stream falla queda pantalla negra. Muestra de 40 URLs de la lista por defecto (`iptv-org spa.m3u`, 2400 streams): **12 fallaron (30 %)**. | `lib/player.dart` |
| H9 | 🟡 Medio | Favoritos solo con MENU/INFO/F2/REC (el control de Google TV no las tiene) y sin pista visual. `addTestChannels()` corre en cada carga y fuerza `favorite = 1` en France 24. | `tv_channel_browser.dart:146,469-476`, `sql.dart` `addCustomChannel` |
| H10 | 🟡 Medio | Recorrer grupos dispara una consulta por grupo, sin debounce ni descarte de respuestas viejas. | `tv_channel_browser.dart:297-305` |
| H11 | 🟡 Medio | Diseño 10-foot: TV 1080p ≈ 960×540 dp. Menú 200 + grupos 250 dejan ~510 dp para 4 columnas (tarjetas ~115 dp, texto 12 sp). Sin márgenes de overscan. Foco solo por color y calculado con índices, no con el foco real. | `tv_home.dart:98`, `tv_channel_browser.dart:282,387-392,517` |
| H12 | 🟡 Medio | Favoritos no se refrescan al marcar un canal; la vista de favoritos muestra un panel de grupos inútil. | `tv_home.dart:126-134` |
| H13 | 🟡 Medio | La primera vez se descarga la lista **antes** de `runApp` (pantalla negra). `_forceTVMode = true` siempre; `leanback required="true"` impide instalar en teléfonos; no hay banner de TV aunque el README lo diga. | `lib/main.dart:20-35,64-73`, `AndroidManifest.xml:9-11` |
| H14 | 🟡 Medio | **Grupos mezclados entre fuentes.** `Sql.updateGroups` tiene `;` sueltos (el `ON CONFLICT` y el `WHERE source_id` nunca se ejecutan) y asigna `group_id` buscando solo por nombre: con 2+ listas que comparten grupos ("News") los canales de la segunda quedan en el grupo de la primera. Con el catálogo de iptv-org esto pasa siempre. | `lib/backend/sql.dart:64-84` |
| H15 | 🟡 Medio | **"Actualizar todas" falla con la fuente `Custom Channels`:** se crea con `source_type = 0` (= `SourceType.xtream`) y `url = ""`; `Utils.refreshAllSources` intenta refrescarla y lanza, cortando el resto. `downloadM3U` no tiene timeout y siempre escribe en el mismo archivo temporal `get.m3u`. | `sql.dart` `addCustomChannel`, `lib/backend/utils.dart:44-49`, `lib/backend/m3u.dart:136-154` |
| H16 | 🟢 Bajo | UI TV en inglés con canales en español. `video_player 2.7.0` y `wakelock_plus` sin uso. `lib/screens/simple_tv_test.dart` es código muerto. | `pubspec.yaml:55-56` |

**Sobre "la versión original funcionaba bien":** comparé con `fred-tv-mobile-main.zip` (original de Fredolx). La lógica de streaming (`m3u.dart`, cabeceras, `player.open`) **no cambió**; lo que cambió en el reproductor es el `KeyboardListener` (H7). Lo que más afecta es H7 + H8 + streams caídos de la lista por defecto. El repo oficial (`github.com/Fredolx/fred-tv-mobile`) ya fue reescrito (backend Rust, ExoPlayer en Android); este plan **no** migra a esa versión.

## Funciones nuevas (pedidas por el usuario)

- **F1 — Catálogo iptv-org:** en Ajustes, "Agregar desde iptv-org" con tres secciones: *Recomendados* (lista fija en español), *Países* (de `https://iptv-org.github.io/api/countries.json`) y *Categorías* (de `https://iptv-org.github.io/api/categories.json`, sin `xxx`). Elegir una agrega la fuente M3U con nombre `iptv-org · <nombre>`. URLs (verificadas, responden 200):
  - país: `https://iptv-org.github.io/iptv/countries/<código en minúsculas>.m3u`
  - idioma: `https://iptv-org.github.io/iptv/languages/<código>.m3u`
  - categoría: `https://iptv-org.github.io/iptv/categories/<id>.m3u`
- **F2 — Actualización automática de enlaces:** al arrancar en TV, si está activada (por defecto sí), se refrescan en segundo plano las fuentes URL/Xtream cuya última actualización tenga ≥ 24 h. Favoritos, historial y listas propias se conservan (ya se preservan por nombre; las listas propias guardan nombre + fuente). Botón "Actualizar listas ahora" y lista "Mis fuentes" (actualizar / activar / desactivar / eliminar una).
- **F3 — Listas propias:** pestaña "Mis listas": crear, renombrar, eliminar listas; desde cualquier canal (OK largo → "Agregar a una lista…"); agregar un canal manual por URL; mover y quitar canales.

---

## Restricciones globales

- Flutter 3.32.4 / Dart 3.8. No subir `environment.sdk` (`^3.5.3`).
- No agregar dependencias de pub. Se **eliminan** `video_player` y `wakelock_plus` de `pubspec.yaml`. Para tests HTTP usar `package:http/testing.dart` (`MockClient`, ya incluido en `http`).
- La UI móvil (`lib/home.dart`, `lib/channel_tile.dart`, `lib/setup.dart`, `lib/settings_view.dart`) no se toca. `lib/player.dart` vuelve a su versión original (Tarea 3). Los arreglos de backend (H14, H15) benefician también al móvil.
- Toda la UI TV en **español** con los textos exactos de la tabla "Textos".
- Ningún `onKeyEvent` de TV devuelve `KeyEventResult.handled` para teclas que no procesa.
- Ningún widget TV redefine `Shortcuts` para las flechas; la navegación ↑↓←→ la hace `DirectionalFocusIntent`.
- Medidas TV (en `TvTheme`, Tarea 2): overscan `EdgeInsets.symmetric(horizontal: 48, vertical: 27)`; texto mínimo 16 sp; foco = escala 1.06 + borde blanco 3 dp; animación 150 ms.
- `debugPrint` en vez de `print` en archivos tocados.
- Nombre fijo de la fuente de canales manuales: `const String customSourceName = 'Custom Channels';` (en `sql.dart`).
- El proyecto **no es un repo git**: la Tarea 0 lo inicializa. Solo commits locales, nunca `push`.
- Comandos desde la raíz: `flutter test <ruta>`, `flutter analyze` (línea base: 0 errores, 40 avisos/infos; sin errores ni *warnings* nuevos en archivos tocados).
- El host de tests no tiene SQLite nativo: el SQL nuevo **no** tiene test automático; se verifica en el dispositivo (Tarea 12). Mantén el SQL exactamente como se indica.

### Textos (copia exacta)

| Clave | Texto |
|---|---|
| nav | `Canales`, `Favoritos`, `Mis listas`, `Buscar`, `Ajustes` |
| grupos | `Todos los canales` |
| vacío canales | `No hay canales en este grupo` |
| vacío favoritos | `Aún no tienes favoritos. Mantén presionado OK sobre un canal para agregarlo.` |
| pista explorador | `OK Reproducir  ·  Mantén OK Opciones  ·  ← Menú` |
| menú de canal | título = nombre; `Reproducir`, `Agregar a favoritos` / `Quitar de favoritos`, `Agregar a una lista…` |
| snackbar | `Agregado a favoritos` / `Quitado de favoritos`, `Agregado a «{lista}»`, `Ya está en «{lista}»` |
| búsqueda | etiqueta `Buscar canales`, pista `Presiona OK para escribir`, `Escribe al menos 2 letras`, `Buscando…`, `Sin resultados para "{q}"`, `{n} resultados`, `Error al buscar. Intenta de nuevo.` |
| mis listas | `Nueva lista`, `Nombre de la lista`, `Crear`, `Guardar`, `Cancelar`, `Renombrar`, `Eliminar`, `¿Eliminar la lista «{nombre}»?`, `Ya existe una lista con ese nombre`, `Agregar canal por URL`, `Nombre del canal`, `URL del stream`, `Quitar de la lista`, `Mover antes`, `Mover después`, `Crea tu primera lista con «Nueva lista».`, `Esta lista está vacía. Mantén OK sobre cualquier canal y elige «Agregar a una lista…».`, `{n} canales` |
| ajustes (menú) | `Agregar desde iptv-org`, `Agregar lista M3U por URL`, `Actualizar listas ahora`, `Actualización automática (cada 24 h)`, `Activada` / `Desactivada`, `Mis fuentes`, `Actualizada {hace}`, `Nunca actualizada`, `Desactivada` |
| ajustes (fuente) | `Actualizar`, `Activar`, `Desactivar`, `Eliminar`, `¿Eliminar la fuente «{nombre}» y sus canales?` |
| ajustes (estado) | `Actualizando listas…`, `Listas actualizadas`, `{n} listas no se pudieron actualizar`, `Ya se están actualizando las listas` |
| formulario M3U | `Agregar lista M3U`, `Nombre de la lista`, `URL de la lista M3U`, `Agregar lista`, `Completa todos los campos`, `La URL debe empezar con http:// o https://`, `Ya existe una lista con ese nombre`, `Agregando lista…`, `Lista agregada correctamente`, `No se pudo agregar la lista` |
| iptv-org | título `Listas de iptv-org`, secciones `Recomendados`, `Países`, `Categorías`, chip `Agregada`, `Agregando «{nombre}»…`, `«{nombre}» agregada`, `Ya agregada`, `Esta lista no está disponible`, `No se pudo cargar el catálogo. Revisa tu conexión.`, `Reintentar` |
| tiempo relativo | `hace un momento` (< 1 min), `hace {n} min`, `hace {n} h`, `hace {n} d` |
| reproductor | `Cargando…`, `En vivo`, `Pausado`, `No se pudo reproducir este canal`, `Reintentar`, `Siguiente canal`, `Volver`, opciones `Audio`, `Subtítulos`, `Ajustar imagen`, `Agregar a favoritos` / `Quitar de favoritos` |
| pista reproductor (en vivo) | `↑↓ Cambiar canal  ·  OK Info  ·  Mantén OK Opciones  ·  Atrás Salir` |
| pista reproductor (VOD) | `←→ 10 s  ·  OK Pausa  ·  Mantén OK Opciones  ·  Atrás Salir` |
| arranque | `Preparando canales…`, `No se pudo descargar la lista de canales`, `Reintentar`, `Continuar` |

## Review Focus

1. **Mantener ↓ presionado en la grilla con paginación** (key-repeat mientras carga la página siguiente): el foco no se pierde ni salta al menú; cada página se pide una sola vez. → test en Tarea 4.
2. **La actualización automática termina mientras el usuario navega o ve un canal:** no debe mover el foco ni recargar la grilla bajo sus pies; los datos nuevos se aplican al volver al menú lateral. → test en Tarea 10.
3. **Atrás con el campo de búsqueda en modo edición:** vuelve al menú lateral, no cierra la app. → test en Tarea 10.
4. **Respuestas de búsqueda fuera de orden** ("ab" responde después que "abc"): se muestran las de la última consulta. → test en Tarea 5.
5. **Volver del reproductor tras hacer zapping:** el foco queda en la tarjeta del último canal visto. → test en Tarea 4.

---

## Estructura de archivos

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `lib/screens/tv/tv_data.dart` | Crear (T1, crece en T6/T7) | Fachada inyectable sobre `Sql`/servicios para pantallas TV. |
| `lib/screens/tv/tv_search_filters.dart` | Crear | Arma los `Filters` de búsqueda. |
| `lib/screens/tv/widgets/tv_theme.dart` | Crear | Constantes visuales TV. |
| `lib/screens/tv/widgets/tv_focusable.dart` | Crear | Elemento enfocable común. |
| `lib/screens/tv/widgets/tv_text_field.dart` | Crear | Campo de texto apto para D-pad. |
| `lib/screens/tv/widgets/tv_dialogs.dart` | Crear | `showTvConfirm`, `showTvTextPrompt`, `showTvOptions`. |
| `lib/screens/tv/widgets/tv_channel_card.dart` | Crear | Tarjeta de canal. |
| `lib/screens/tv/widgets/tv_channel_menu.dart` | Crear | Menú de OK largo de un canal. |
| `lib/screens/tv/tv_focus.dart` | Crear | `TvEdgeFocusAction`, `focusFirstIn()`. |
| `lib/screens/tv/tv_time.dart` | Crear | `formatAgo()`. |
| `lib/screens/tv/player/*.dart` | Crear | Teclas, cursor de lista, reintentos, `TvPlayer`. |
| `lib/backend/source_refresher.dart` | Crear | Refresco de fuentes + `tvSourcesVersion`. |
| `lib/backend/iptv_org_catalog.dart` | Crear | Catálogo iptv-org. |
| `lib/backend/user_playlists_sql.dart` | Crear | SQL de listas propias. |
| `lib/models/user_playlist.dart` | Crear | Modelo `UserPlaylist`. |
| `lib/screens/tv/tv_iptv_org_screen.dart` | Crear | Pantalla del catálogo. |
| `lib/screens/tv/tv_add_m3u_screen.dart` | Crear | Formulario de lista M3U por URL. |
| `lib/screens/tv/tv_user_playlists.dart` | Crear | Pestaña "Mis listas" + diálogo "Agregar a una lista…". |
| `lib/screens/tv/tv_bootstrap.dart` | Crear | Arranque TV. |
| `lib/screens/tv/tv_home.dart`, `tv_channel_browser.dart`, `tv_search.dart`, `tv_settings.dart` | Reescribir | Pantallas TV. |
| `lib/player.dart` | Restaurar | Versión original (móvil). |
| `lib/select_dialog.dart` | Modificar | `autofocus` en el primer ítem. |
| `lib/main.dart` | Modificar | Detección TV real, `MediaKit.ensureInitialized()`, tema oscuro TV, `TvBootstrap`. |
| `lib/models/filters.dart` | Modificar | Campo opcional `groupName`. |
| `lib/backend/sql.dart` | Modificar | `searchGroupNames`, `groupName` en `search`, `updateGroups`, `addCustomChannel`, `customSourceName`, helpers de settings. |
| `lib/backend/db_factory.dart` | Modificar | Migración 4. |
| `lib/backend/m3u.dart`, `lib/backend/utils.dart` | Modificar | Timeout/temp único; `refreshAllSources` usa `SourceRefresher`. |
| `android/.../MainActivity.kt`, `AndroidManifest.xml`, `res/drawable/tv_banner.xml` | Modificar/Crear | `isTv`, leanback opcional, banner. |
| `lib/screens/simple_tv_test.dart` | Eliminar | Código muerto. |
| `test/screens/tv/fakes.dart` + `test/**/*_test.dart` | Crear | Fakes y tests. |

---

### Tarea 0: Preparación (git + línea base)

- [x] **Paso 1:** en la raíz: `git init`; añade al `.gitignore` (si faltan) `build/`, `.dart_tool/`, `android/build/`, `flutter_01.log`.
- [x] **Paso 2:** `git add -A && git commit -m "chore: baseline antes de mejoras Android TV"`.
- [x] **Paso 3:** `flutter analyze` → esperado `40 issues found`, ninguno `error`. Anótalo.
- [x] **Paso 4:** borra `lib/screens/simple_tv_test.dart` (no se importa), `flutter analyze` sin errores, commit `chore: eliminar pantalla de prueba sin uso`.

---

### Tarea 1: Arreglar la búsqueda, fachada `TvData` y grupos por nombre (H1, H14 parte TV)

**Archivos:**
- Crear: `lib/screens/tv/tv_search_filters.dart`, `lib/screens/tv/tv_data.dart`, `test/screens/tv/fakes.dart`, `test/screens/tv/tv_search_filters_test.dart`
- Modificar: `lib/models/filters.dart`, `lib/backend/sql.dart`, `lib/screens/tv/tv_search.dart`

**Interfaces:**
- Produce:
  - `const int tvSearchMinChars = 2;` y `Filters? buildTvSearchFilters(String rawQuery, List<int> sourceIds)` — `null` si `rawQuery.trim()` < 2 caracteres o `sourceIds` vacío; si no `Filters(viewType: ViewType.all, sourceIds: sourceIds, query: <trim, espacios múltiples → uno>, useKeywords: true, mediaTypes: [MediaType.livestream, MediaType.movie])`.
  - `Filters` gana `String? groupName` (parámetro con nombre opcional; nadie más cambia).
  - `Sql.search`: si `groupId == null && groupName != null` agrega `AND group_name = ?` (el parámetro va en la misma posición que hoy ocupa `groupId`).
  - `static Future<List<Channel>> Sql.searchGroupNames(Filters f)` — grupos **fusionados por nombre** entre fuentes:
    ```sql
    SELECT group_name, MIN(image) FROM channels
    WHERE group_name IS NOT NULL AND group_name <> '' AND url IS NOT NULL
      AND media_type IN (<mediaTypes>) AND source_id IN (<sourceIds>)
    GROUP BY group_name ORDER BY group_name COLLATE NOCASE
    LIMIT ?, ?
    ```
    Devuelve `Channel(name: group_name, image: …, mediaType: MediaType.group, sourceId: -1, favorite: false)` (sin `id`).
  - `class TvData { const TvData(); Future<List<int>> enabledSourceIds(); Future<List<Channel>> searchChannels(Filters f); Future<List<Channel>> searchGroups(Filters f); Future<void> setFavorite(int channelId, bool favorite); Future<void> addToHistory(int channelId); Future<ChannelHttpHeaders?> channelHeaders(int channelId); }` — delegan en `Sql.getEnabledSourcesMinimal()` (→ `.id`), `Sql.search`, `Sql.searchGroupNames`, `Sql.favoriteChannel`, `Sql.addToHistory`, `Sql.getChannelHeaders`.
  - `test/screens/tv/fakes.dart`:
    - `Channel fakeChannel(int i, {String? group, bool favorite = false, MediaType type = MediaType.livestream, int sourceId = 1})` → `Channel(id: i, name: 'Canal $i', url: 'http://test/$i.m3u8', mediaType: type, sourceId: sourceId, favorite: favorite, group: group)` (sin `image`).
    - `class FakeTvData extends TvData` — `FakeTvData({List<String> groups = const [], List<Channel> channels = const [], Future<List<Channel>> Function(Filters f)? onSearchChannels})`; registra `channelCalls`, `groupCalls` (`List<Filters>`), `favoriteCalls` (`List<(int, bool)>`), `historyCalls` (`List<int>`). `enabledSourceIds()` → `[1]`. `searchGroups` → `groups` como `Channel(name: g, mediaType: MediaType.group, sourceId: -1, favorite: false)`. `searchChannels` (sin `onSearchChannels`): filtra por `f.groupName` (contra `Channel.group`), por favorito si `f.viewType == ViewType.favorites`, por todas las palabras de `f.query` (contiene, sin mayúsculas), y pagina con `pageSize` según `f.page`. `channelHeaders` → `null`. (Las tareas 6 y 7 le agregan más métodos.)
    - `Future<void> pumpTv(WidgetTester t, Widget child)` — `t.view.physicalSize = const Size(1920, 1080)`, `t.view.devicePixelRatio = 2`, `addTearDown(t.view.reset)`, `pumpWidget(MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: Scaffold(body: child)))`, `pumpAndSettle()`.

- [x] **Paso 1: test que falla** — `tv_search_filters_test.dart`:

```dart
test('incluye mediaTypes (regresión H1)', () {
  final f = buildTvSearchFilters('  canal   24 ', [1, 2])!;
  expect(f.mediaTypes, [MediaType.livestream, MediaType.movie]);
  expect(f.query, 'canal 24');
  expect(f.useKeywords, isTrue);
  expect(f.viewType, ViewType.all);
  expect(f.sourceIds, [1, 2]);
});
test('null con menos de 2 letras', () => expect(buildTvSearchFilters(' a ', [1]), isNull));
test('null sin fuentes', () => expect(buildTvSearchFilters('abc', []), isNull));
```

- [x] **Paso 2:** `flutter test test/screens/tv/tv_search_filters_test.dart` → FALLA.
- [x] **Paso 3:** implementa lo anterior. En `tv_search.dart` reemplaza la construcción de `Filters` (líneas 60-68) por `buildTvSearchFilters` (si es `null`, limpia resultados) — arreglo mínimo; la pantalla se reescribe en la Tarea 5.
- [x] **Paso 4:** `flutter test test/screens/tv/` → PASA; `flutter analyze` sin errores.
- [x] **Paso 5:** commit `fix(tv): búsqueda sin mediaTypes; fachada TvData; grupos por nombre`.

---

### Tarea 2: Primitivas de foco TV

**Archivos:**
- Crear: `lib/screens/tv/widgets/tv_theme.dart`, `tv_focusable.dart`, `tv_text_field.dart`, `tv_dialogs.dart`, `lib/screens/tv/tv_focus.dart`, `lib/screens/tv/tv_time.dart`
- Modificar: `test/screens/tv/fakes.dart` (agregar `isFocused`)
- Test: `test/screens/tv/tv_focusable_test.dart`, `tv_text_field_test.dart`, `tv_focus_test.dart`, `tv_dialogs_test.dart`, `tv_time_test.dart`

**Interfaces:**
- Produce:
  - `abstract final class TvTheme`: `background = Color(0xFF0E0E12)`, `surface = Color(0xFF1C1C22)`, `surfaceRaised = Color(0xFF2A2A33)`, `accent = Color(0xFF3D8BFF)`, `focusBorder = Colors.white`, `textPrimary = Colors.white`, `textSecondary = Color(0xFFB4B4BE)`, `success = Color(0xFF4CAF50)`, `error = Color(0xFFEF5350)`, `favorite = Color(0xFFFFC107)`, `safeArea = EdgeInsets.symmetric(horizontal: 48, vertical: 27)`, `focusScale = 1.06`, `focusBorderWidth = 3.0`, `focusDuration = Duration(milliseconds: 150)`, `radius = 10.0`, `fontSmall = 16.0`, `fontBody = 18.0`, `fontTitle = 26.0`, `sidebarCollapsed = 84.0`, `sidebarExpanded = 220.0`, `groupsWidth = 240.0`, `tileMaxExtent = 200.0`, `tileAspectRatio = 16 / 12`.
  - `class TvFocusable extends StatefulWidget` — `const TvFocusable({super.key, required Widget Function(BuildContext context, bool focused) builder, VoidCallback? onSelect, VoidCallback? onLongPress, ValueChanged<bool>? onFocusChange, FocusNode? focusNode, bool autofocus = false, bool scaleOnFocus = true, bool decorate = true, bool ensureVisibleOnFocus = true})`. Estado público `TvFocusableState` con `bool get hasFocus`.
    - Selección (`select`, `enter`, `numpadEnter`, `gameButtonA`): `KeyDown` → marca presionado, `handled`. `KeyRepeat` → si hay `onLongPress` y no se disparó, lo dispara una vez; `handled`. `KeyUp` → si estaba presionado y no hubo largo, `onSelect`; resetea; `handled`. `KeyUp` sin `KeyDown` previo → se ignora.
    - `contextMenu`, `info`, `f2` (`KeyDown`) → `onLongPress`, `handled`. Otras → `ignored`.
    - Al ganar foco con `ensureVisibleOnFocus`: `Scrollable.ensureVisible(context, alignment: 0.5, duration: TvTheme.focusDuration)`.
    - Con `decorate`: `AnimatedScale` (→ `focusScale` si `scaleOnFocus`) + `AnimatedContainer` con borde `focusBorder` de `focusBorderWidth` y sombra al tener foco; sin foco borde transparente del mismo ancho.
  - `class TvTextField extends StatefulWidget` — `const TvTextField({super.key, required TextEditingController controller, required String label, String? hint, IconData? icon, FocusNode? focusNode, bool autofocus = false, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, TextInputType? keyboardType, TextInputAction textInputAction = TextInputAction.done})`.
    - Modo botón (defecto): `TvFocusable` con icono + `label` + texto actual (o `hint`). Enfocado **no** abre teclado.
    - OK → modo edición: enfoca el `TextField` interno (abre teclado). En edición, ↑/↓ salen, devuelven el foco al `TvFocusable` y en el siguiente frame llaman `focusInDirection(up|down)`. Al enviar: sale de edición con foco en el `TvFocusable` y llama `onSubmitted`. Si el campo interno pierde foco por otra causa, sale de edición.
    - Enfoque sugerido: `TextField(canRequestFocus: _editing)` dentro de `Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: …)` que intercepta ↑/↓ (probado: el ancestro recibe la flecha antes que los atajos de texto).
  - `tv_focus.dart`: `class TvEdgeFocusAction extends DirectionalFocusAction { TvEdgeFocusAction({required void Function(TraversalDirection direction) onEdge}); }` — `invoke`: `final moved = primaryFocus?.focusInDirection(intent.direction) ?? false; if (!moved) onEdge(intent.direction);`. `bool focusFirstIn(FocusScopeNode scope)` — `FocusTraversalGroup.maybeOf(scope.context!)?.findFirstFocus(scope)` (último hijo enfocado o el primero); si `null` o es el propio `scope` → `false` sin mover; si no `requestFocus()` y `true`; `false` si `scope.context == null`.
  - `tv_dialogs.dart` (todas usan `TvFocusable`, fondo `TvTheme.surface`, primer botón con `autofocus`; Atrás cierra devolviendo `null`/`false`):
    - `Future<bool> showTvConfirm(BuildContext context, {required String message, String confirmLabel = 'Eliminar', String cancelLabel = 'Cancelar'})` — el foco inicial está en **Cancelar**.
    - `Future<String?> showTvTextPrompt(BuildContext context, {required String title, required String label, String initial = '', String confirmLabel = 'Guardar'})` — `TvTextField` (autofocus) + `confirmLabel` / `Cancelar`; devuelve el texto con `trim()`, o `null` si se cancela o queda vacío.
    - `Future<T?> showTvOptions<T>(BuildContext context, {required String title, required List<(String label, T value)> options})` — lista vertical; devuelve el valor elegido.
  - `String formatAgo(Duration d)` (`tv_time.dart`) → textos de "tiempo relativo".
  - `bool isFocused(WidgetTester t, Key key)` en `fakes.dart` → `t.state<TvFocusableState>(find.byKey(key)).hasFocus`.

- [x] **Paso 1: tests que fallan:**

```dart
// tv_focusable_test.dart
testWidgets('OK al soltar llama onSelect una vez', ...);          // down+up select → selects 1, longs 0
testWidgets('OK mantenido llama onLongPress y no onSelect', ...); // down, repeat×3, up → longs 1, selects 0
testWidgets('KeyUp sin KeyDown no activa', ...);                  // up enter → selects 0
testWidgets('tecla MENU llama onLongPress', ...);
testWidgets('flechas y Atrás no se consumen', (t) async {
  expect(await t.sendKeyEvent(LogicalKeyboardKey.goBack), isFalse);
  await t.sendKeyEvent(LogicalKeyboardKey.arrowRight); await t.pump();
  expect(isFocused(t, const ValueKey('b')), isTrue);
});

// tv_text_field_test.dart
testWidgets('enfocar no abre el teclado', (t) async { /* ... */ expect(t.testTextInput.isVisible, isFalse); });
testWidgets('OK entra a edición y ↓ sale al siguiente', ...);     // isVisible true; ↓ → isFocused('below')
testWidgets('enviar llama onSubmitted y vuelve al modo botón', ...); // enterText 'hola'; receiveAction(done)

// tv_focus_test.dart — menú (FocusScope, 'side') + Actions{DirectionalFocusIntent: TvEdgeFocusAction} + FocusScope(scope) 2×2 g0..g3
// g0 → g1, ↓ g3, ← g2, ← borde → edges == [left], foco sigue en g2
// foco a 'side'; focusFirstIn(scope) == true y foco en g2
// scope nunca enfocado → focusFirstIn enfoca g0; scope sin enfocables → false y el foco no cambia

// tv_dialogs_test.dart
// showTvConfirm: foco inicial en 'Cancelar'; OK → false; ← → 'Eliminar' OK → true
// showTvTextPrompt: OK, enterText ' Mi lista ', done, ↓ a 'Guardar', OK → 'Mi lista'; vacío → null
// showTvOptions: ↓ ↓ OK → valor del 3.er ítem

// tv_time_test.dart
expect(formatAgo(const Duration(seconds: 30)), 'hace un momento');
expect(formatAgo(const Duration(minutes: 5)), 'hace 5 min');
expect(formatAgo(const Duration(hours: 3, minutes: 59)), 'hace 3 h');
expect(formatAgo(const Duration(days: 2)), 'hace 2 d');
```

- [x] **Paso 2:** `flutter test test/screens/tv/` → FALLAN los nuevos.
- [x] **Paso 3:** implementa.
- [x] **Paso 4:** `flutter test test/screens/tv/` → PASAN.
- [x] **Paso 5:** commit `feat(tv): primitivas de foco y diálogos para D-pad`.

---

### Tarea 3: Reproductor TV (H7, H8)

**Archivos:**
- Crear: `lib/screens/tv/player/tv_player_keys.dart`, `tv_playlist.dart`, `tv_retry_policy.dart`, `tv_player.dart`
- Restaurar: `lib/player.dart` al original del zip `fred-tv-mobile-main.zip` (sin `KeyboardListener`, sin `_focusNode`, sin los `Focus(...)` alrededor de los `IconButton`).
- Modificar: `lib/select_dialog.dart` (`autofocus: true` en el primer `ListTile`), `pubspec.yaml` (quitar `video_player` y `wakelock_plus`), `lib/main.dart` (`MediaKit.ensureInitialized()` justo después de `WidgetsFlutterBinding.ensureInitialized()`).
- Test: `test/screens/tv/player/tv_player_keys_test.dart`, `tv_playlist_test.dart`, `tv_retry_policy_test.dart`

**Interfaces:**
- Consume: `TvData` (T1), `TvFocusable`, `TvTheme`, `showTvOptions` (T2).
- Produce:
  - `enum TvPlayerCommand { none, togglePlayPause, play, pause, seekBack, seekForward, previousChannel, nextChannel, showOverlay, toggleOverlay, openOptions, exit }`
  - `TvPlayerCommand mapTvPlayerKey(LogicalKeyboardKey key, {required bool isLive})`:

    | Tecla | En vivo | VOD (película) |
    |---|---|---|
    | `arrowUp`, `channelDown` | `previousChannel` | `showOverlay` |
    | `arrowDown`, `channelUp` | `nextChannel` | `showOverlay` |
    | `arrowLeft` / `arrowRight` | `showOverlay` | `seekBack` / `seekForward` |
    | `mediaRewind` / `mediaFastForward` | `none` | `seekBack` / `seekForward` |
    | `select`, `enter`, `numpadEnter`, `gameButtonA` | `toggleOverlay` | `togglePlayPause` |
    | `mediaPlayPause` / `mediaPlay` / `mediaPause` | `togglePlayPause` / `play` / `pause` | igual |
    | `contextMenu`, `info`, `f2` | `openOptions` | `openOptions` |
    | `goBack`, `escape`, `browserBack`, `mediaStop` | `exit` | `exit` |
    | otra | `none` | `none` |

  - `class TvPlaylistCursor { TvPlaylistCursor(List<Channel> channels, int index); Channel get current; int get index; void next(); void previous(); String get positionLabel; }` — circular; `positionLabel` = `'${index + 1} / ${channels.length}'`; `ArgumentError` si lista vacía o índice fuera de rango.
  - `class TvPlaybackAttempt { const TvPlaybackAttempt({required this.hardwareDecoding}); final bool hardwareDecoding; }` y `abstract final class TvRetryPolicy { static const attempts = [TvPlaybackAttempt(hardwareDecoding: true), TvPlaybackAttempt(hardwareDecoding: false)]; static const firstFrameTimeout = Duration(seconds: 15); static const maxLiveReconnects = 3; static const reconnectDelay = Duration(seconds: 2); static TvPlaybackAttempt? next(int failedAttemptIndex); }`
  - `const String tvFallbackUserAgent = 'VLC/3.0.21 LibVLC/3.0.21';`
  - `class TvPlayer extends StatefulWidget { const TvPlayer({super.key, required List<Channel> playlist, required int initialIndex, TvData data = const TvData()}); }`
  - `Future<int?> openTvPlayer(BuildContext context, {required List<Channel> playlist, required int index, TvData data = const TvData()})` — `Navigator.push(MaterialPageRoute<int>(builder: (_) => TvPlayer(...)))`; devuelve el índice del último canal reproducido.

**Comportamiento de `TvPlayer`** (se valida en el dispositivo, Tarea 12):
- Entrar: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`; salir: `SystemUiMode.edgeToEdge`. No cambia orientaciones.
- `Video(controller: …, controls: NoVideoControls, fit: _fill ? BoxFit.cover : BoxFit.contain)`. **No** se llama `enterFullscreen()`.
- Raíz: `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) _exit(); })` + `Focus(autofocus: true, onKeyEvent: …)` con `mapTvPlayerKey`; OK largo (mismo patrón `KeyDown`/`KeyRepeat`/`KeyUp` que `TvFocusable`) → `openOptions`. Comando ≠ `none` → `handled`; `none` → `ignored`.
- `_play(Channel c, TvPlaybackAttempt a)`: `data.addToHistory(c.id!)`; cabeceras con `data.channelHeaders(c.id!)`; `User-Agent` = el de la cabecera o `tvFallbackUserAgent`; si `player.platform is NativePlayer`: `setProperty('hwdec', a.hardwareDecoding ? 'auto-safe' : 'no')` y `setProperty('network-timeout', '15')` antes de `open`. Películas: posición inicial con `Sql.getPosition`.
- Fallos: `player.stream.error` o sin primer frame (`player.stream.width` no nulo) en `firstFrameTimeout` → `TvRetryPolicy.next(i)`; si `null` → overlay de error con `TvFocusable` `Reintentar` (autofocus, vuelve a `attempts[0]`), `Siguiente canal`, `Volver`.
- En vivo: `player.stream.completed == true` → reconectar tras `reconnectDelay`, hasta `maxLiveReconnects` seguidas (se resetea al recibir frame).
- Zapping: mueve `TvPlaylistCursor`, abre con `attempts[0]`, muestra el overlay.
- Overlay (abajo, gradiente): nombre (`fontTitle`), `group` si hay, `positionLabel`, estado (`Cargando…`/`En vivo`/`Pausado`) y la pista de teclas (tabla "Textos"). Se oculta a los 4 s sin teclas.
- Opciones: `showTvOptions` con `Audio`, `Subtítulos` (abren `SelectDialog` con `player.state.tracks`, como `player.dart`), `Ajustar imagen` (alterna `_fill`), `Agregar a favoritos`/`Quitar de favoritos` (`data.setFavorite`).
- `_exit` (bandera `_exiting`): si es película `Sql.setPosition`; `Navigator.pop(context, cursor.index)`.

- [x] **Paso 1: tests que fallan:**

```dart
// tv_player_keys_test.dart — recorre la tabla completa, p. ej.:
expect(mapTvPlayerKey(LogicalKeyboardKey.arrowLeft, isLive: true), TvPlayerCommand.showOverlay);
expect(mapTvPlayerKey(LogicalKeyboardKey.arrowLeft, isLive: false), TvPlayerCommand.seekBack);
expect(mapTvPlayerKey(LogicalKeyboardKey.select, isLive: true), TvPlayerCommand.toggleOverlay);
expect(mapTvPlayerKey(LogicalKeyboardKey.select, isLive: false), TvPlayerCommand.togglePlayPause);
expect(mapTvPlayerKey(LogicalKeyboardKey.arrowUp, isLive: true), TvPlayerCommand.previousChannel);
expect(mapTvPlayerKey(LogicalKeyboardKey.channelUp, isLive: true), TvPlayerCommand.nextChannel);
expect(mapTvPlayerKey(LogicalKeyboardKey.mediaRewind, isLive: true), TvPlayerCommand.none);
expect(mapTvPlayerKey(LogicalKeyboardKey.goBack, isLive: false), TvPlayerCommand.exit);
expect(mapTvPlayerKey(LogicalKeyboardKey.keyA, isLive: true), TvPlayerCommand.none);

// tv_playlist_test.dart
final c = TvPlaylistCursor([fakeChannel(1), fakeChannel(2), fakeChannel(3)], 2);
c.next(); expect(c.index, 0); c.previous(); expect(c.index, 2);
expect(c.positionLabel, '3 / 3');
expect(() => TvPlaylistCursor([], 0), throwsArgumentError);

// tv_retry_policy_test.dart
expect(TvRetryPolicy.next(0)!.hardwareDecoding, isFalse);
expect(TvRetryPolicy.next(1), isNull);
```

- [x] **Paso 2:** `flutter test test/screens/tv/player/` → FALLAN.
- [x] **Paso 3:** implementa; restaura `player.dart`; edita `select_dialog.dart`, `pubspec.yaml`, `main.dart`; `flutter pub get`.
- [x] **Paso 4:** `flutter test test/screens/tv/` → PASAN; `flutter analyze` sin errores; `grep -rn "video_player\|wakelock_plus" lib` → vacío.
- [x] **Paso 5:** commit `feat(tv): reproductor TV con overlay, zapping, reintentos y errores visibles`.

---

### Tarea 4: Explorador de canales (H5, H9, H10, H11, H12)

**Archivos:**
- Reescribir: `lib/screens/tv/tv_channel_browser.dart`
- Crear: `lib/screens/tv/widgets/tv_channel_card.dart`, `tv_channel_menu.dart`
- Modificar: `lib/screens/tv/tv_home.dart` (solo para compilar con el constructor nuevo), `lib/backend/sql.dart` (`addCustomChannel`: `DO UPDATE SET url = excluded.url`, sin tocar `favorite`)
- Test: `test/screens/tv/tv_channel_browser_test.dart`

**Interfaces:**
- Consume: `TvData`, `TvFocusable`, `TvTheme`, `showTvOptions`, `openTvPlayer`.
- Produce:
  - `typedef TvPlayCallback = Future<int?> Function(BuildContext context, List<Channel> playlist, int index);`
  - `typedef TvAddToPlaylistCallback = Future<void> Function(BuildContext context, Channel channel);`
  - `class TVChannelBrowser extends StatefulWidget { const TVChannelBrowser({super.key, bool favoritesOnly = false, TvData data = const TvData(), TvPlayCallback? onPlay, TvAddToPlaylistCallback? onAddToPlaylist}); }` — `onPlay` por defecto llama `openTvPlayer`. Estado público `TVChannelBrowserState` con `Future<void> reload()`. Se eliminan `onBackToMenu` y `contentFocusNode`.
  - Keys: grupos `ValueKey('tv-group-$index')`, tarjetas `ValueKey('tv-channel-$index')`.
  - `class TvChannelCard extends StatelessWidget { const TvChannelCard({super.key, required Channel channel, required bool focused}); }` — logo `CachedNetworkImage` (`BoxFit.contain`, placeholder/error `Icons.live_tv`), nombre en 2 líneas (`fontSmall`), estrella `TvTheme.favorite` si es favorito; sin `image` → solo icono.
  - `Future<void> showTvChannelMenu(BuildContext context, {required Channel channel, required VoidCallback onPlay, required VoidCallback onToggleFavorite, VoidCallback? onAddToPlaylist})` — `showTvOptions` con título = nombre: `Reproducir`, `Agregar a favoritos`/`Quitar de favoritos`, y `Agregar a una lista…` solo si `onAddToPlaylist != null`.

**Comportamiento:**
- Ya **no** llama `Sql.addTestChannels()` (pasa a la Tarea 11).
- Layout: `Row` [grupos `TvTheme.groupsWidth` (oculto si `favoritesOnly`) | grilla] y debajo la pista del explorador.
- Grupos: `ListView.builder` de `TvFocusable(scaleOnFocus: false)`; ítem 0 = `Todos los canales` (sin `groupName`), luego `data.searchGroups(Filters(viewType: ViewType.categories, sourceIds: …, mediaTypes: [MediaType.livestream]))`. El grupo cargado lleva una barra `TvTheme.accent` de 4 dp aunque no tenga foco. Enfocar un grupo programa la carga con **debounce de 300 ms** y número de petición (se descartan respuestas que no sean la última). Canales del grupo: `Filters(viewType: ViewType.all, groupName: <nombre>, mediaTypes: [MediaType.livestream], sourceIds: …, page: n)`. OK sobre un grupo → primera tarjeta.
- Grilla: `GridView.builder` con `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: TvTheme.tileMaxExtent, childAspectRatio: TvTheme.tileAspectRatio, mainAxisSpacing: 20, crossAxisSpacing: 20)`, padding 16. Tarjeta = `TvFocusable(onSelect: play, onLongPress: menú, builder: … TvChannelCard)`. **Sin** manejo manual de flechas.
- Paginación: scroll a < 400 px del final → página siguiente (`pageSize`), sin pedir dos veces la misma página.
- Reproducir: `final last = await onPlay(context, _channels, i);` → si `last != null`, enfoca `tv-channel-$last` tras un frame.
- Favorito: `data.setFavorite(id, !fav)`, actualiza modelo, snackbar 800 ms. En `favoritesOnly`, quitar un favorito lo saca de la grilla y enfoca la vecina (o el estado vacío).
- `favoritesOnly`: `ViewType.favorites`, sin grupos. Estados vacíos y carga según "Textos".

- [x] **Paso 1: tests que fallan** (`pumpTv` + `FakeTvData(groups: ['Deportes', 'Noticias', 'Cine'], channels: 50 canales con `group` repartido)`):

```dart
testWidgets('↓ en la grilla baja una fila en la misma columna', ...);   // top mayor, left ≈ igual (±1)
testWidgets('← en la primera columna va al grupo seleccionado', ...);
testWidgets('Atrás no se consume (regresión H5)', (t) async {
  expect(await t.sendKeyEvent(LogicalKeyboardKey.goBack), isFalse);
});
testWidgets('debounce: recorrer grupos rápido carga solo el último', ...);
//   foco grupo 0; ↓ ↓ ↓ sin esperar; pump(350ms) → una sola llamada nueva con groupName 'Cine'
testWidgets('OK reproduce con la lista y el índice', ...);              // onPlay recibe (channels, 5)
testWidgets('OK largo → menú → favorito', ...);                          // favoriteCalls == [(id, true)]
testWidgets('menú muestra "Agregar a una lista…" solo con callback', ...);
testWidgets('al volver del reproductor enfoca el último canal visto', ...); // onPlay → 7 → isFocused(tv-channel-7) [RF5]
testWidgets('mantener ↓ con paginación no pierde el foco', ...);
//   80 canales; 12× (sendKeyDownEvent/sendKeyRepeatEvent arrowDown + pump(16ms)); pumpAndSettle;
//   alguna tv-channel-* con foco; cada page aparece una sola vez en channelCalls [RF1]
testWidgets('favoritesOnly sin favoritos muestra estado vacío', ...);
```

- [x] **Paso 2:** `flutter test test/screens/tv/tv_channel_browser_test.dart` → FALLAN.
- [x] **Paso 3:** implementa; ajusta `tv_home.dart` para compilar; cambia `addCustomChannel`.
- [x] **Paso 4:** `flutter test test/screens/tv/` → PASAN; `flutter analyze` sin errores.
- [x] **Paso 5:** commit `feat(tv): explorador con foco nativo, menú de canal y debounce`.

---

### Tarea 5: Pantalla de búsqueda (H1, H4, H6)

**Archivos:** Reescribir `lib/screens/tv/tv_search.dart`; Test `test/screens/tv/tv_search_test.dart`

**Interfaces:**
- Consume: `buildTvSearchFilters`, `TvData`, `TvTextField`, `TvFocusable`, `TvChannelCard`, `showTvChannelMenu`, `TvPlayCallback`, `TvAddToPlaylistCallback`, `openTvPlayer`.
- Produce: `class TVSearch extends StatefulWidget { const TVSearch({super.key, TvData data = const TvData(), TvPlayCallback? onPlay, TvAddToPlaylistCallback? onAddToPlaylist}); }`. Keys: `ValueKey('tv-search-field')`, `ValueKey('tv-search-result-$index')`.

**Comportamiento:**
- **Nada** de `requestFocus` en `initState` (H4); el foco inicial lo pone `TVHome`.
- `TvTextField(label: 'Buscar canales', hint: 'Presiona OK para escribir', icon: Icons.search, textInputAction: TextInputAction.search)`; debounce 400 ms al escribir; al enviar: búsqueda inmediata y foco al primer resultado si hay.
- Número de petición: solo se aplica la última respuesta.
- Estado bajo el campo: `Escribe al menos 2 letras` / `Buscando…` / `{n} resultados` / `Sin resultados para "{q}"` / `Error al buscar. Intenta de nuevo.` (si lanza; `debugPrint`).
- Resultados: misma grilla y menú que la Tarea 4.

- [x] **Paso 1: tests que fallan:**

```dart
testWidgets('buscar muestra resultados (regresión H1)', ...);
//   OK; enterText 'canal 1'; receiveAction(search); pumpAndSettle → result-0 existe y con foco;
//   data.channelCalls.last.mediaTypes == [MediaType.livestream, MediaType.movie]
testWidgets('↓ desde el campo va al primer resultado y ↑ vuelve', ...);
testWidgets('no roba el foco al construirse (regresión H4)', ...);   // junto a TvFocusable autofocus 'nav'
testWidgets('menos de 2 letras no consulta', ...);
testWidgets('respuesta vieja no pisa a la nueva', ...);              // Completers 'ab' lento / 'abc' rápido [RF4]
testWidgets('error muestra mensaje', ...);
```

- [x] **Paso 2:** → FALLAN. **Paso 3:** implementa. **Paso 4:** `flutter test test/screens/tv/` → PASAN.
- [x] **Paso 5:** commit `feat(tv): búsqueda navegable con D-pad, estados y control de respuestas`.

---

### Tarea 6: Backend de fuentes — refresco y catálogo iptv-org (F1, F2, H14, H15)

**Archivos:**
- Crear: `lib/backend/source_refresher.dart`, `lib/backend/iptv_org_catalog.dart`
- Modificar: `lib/backend/sql.dart`, `lib/backend/m3u.dart`, `lib/backend/utils.dart`, `lib/screens/tv/tv_data.dart`, `test/screens/tv/fakes.dart`
- Test: `test/backend/source_refresher_test.dart`, `test/backend/iptv_org_catalog_test.dart`

**Interfaces:**
- Produce:
  - En `sql.dart`: `const String customSourceName = 'Custom Channels';`; `static Future<String?> getSetting(String key)`; `static Future<void> setSetting(String key, String value)` (usa `updateSettings`). `addCustomChannel` crea la fuente con `SourceType.m3u.index` (en vez de `0`) y `customSourceName`.
  - `Sql.updateGroups` corregido (H14) — dos sentencias limpias, sin `;` internos:
    ```sql
    INSERT INTO groups (name, image, source_id, media_type)
    SELECT group_name, image, ?, media_type FROM channels
    WHERE source_id = ? GROUP BY group_name
    ON CONFLICT(name, source_id) DO UPDATE SET media_type = excluded.media_type
    ```
    ```sql
    UPDATE channels SET group_id = (
      SELECT id FROM groups WHERE groups.name = channels.group_name AND groups.source_id = channels.source_id LIMIT 1)
    WHERE source_id = ?
    ```
    (segunda con parámetro `[sourceId]`).
  - `m3u.dart` `downloadM3U(String urlStr)`: cabecera `User-Agent: FredTV/1.3`, `.timeout(const Duration(seconds: 60))` en `send`, `client.close()` en `finally`, archivo temporal único `get_<microsecondsSinceEpoch>.m3u`. `processM3UUrl` borra ese archivo en `finally`. Un 404 lanza `HttpStatusException(int statusCode)` (clase nueva en `m3u.dart`).
  - `source_refresher.dart`:
    - `final ValueNotifier<int> tvSourcesVersion = ValueNotifier(0);` — se incrementa tras agregar, borrar, activar/desactivar o refrescar con éxito alguna fuente.
    - `class SourceRefreshResult { const SourceRefreshResult({required this.refreshed, required this.failedNames, this.alreadyRunning = false}); final int refreshed; final List<String> failedNames; final bool alreadyRunning; }`
    - `class SourceRefresher { SourceRefresher({required Future<List<Source>> Function() loadSources, required Future<void> Function(Source source) refreshOne, required Future<DateTime?> Function(int sourceId) lastRefresh, required Future<void> Function(int sourceId, DateTime at) saveRefresh, DateTime Function() now = DateTime.now}); static final SourceRefresher instance; static const Duration autoInterval = Duration(hours: 24); static bool isRefreshable(Source s); bool get isRunning; Future<SourceRefreshResult> refreshAll({bool onlyStale = false, int? onlySourceId}); }`
      - `isRefreshable`: `s.enabled && s.name != customSourceName && (s.url ?? '').isNotEmpty && (s.sourceType == SourceType.m3uUrl || s.sourceType == SourceType.xtream)`.
      - `refreshAll`: si ya hay una ejecución, devuelve **la misma** `Future` (una segunda llamada externa que quiera saberlo puede consultar `isRunning` antes). Secuencial; `try/catch` por fuente (un fallo no corta el resto; se agrega a `failedNames`); tras éxito `saveRefresh(id, now())`; con `onlyStale` salta las que tengan `lastRefresh` < `autoInterval`; `onlySourceId` limita a esa fuente. Si `refreshed > 0`, `tvSourcesVersion.value++`.
      - `instance` usa `Sql.getSources`, `Utils.refreshSource`, y las claves de settings `lastRefresh_<id>` (epoch en milisegundos como string).
    - `Utils.refreshAllSources()` pasa a llamar `SourceRefresher.instance.refreshAll()` (así el móvil deja de romperse con `Custom Channels`).
  - `iptv_org_catalog.dart`:
    - `enum IptvOrgKind { country, language, category }`
    - `class IptvOrgPlaylist { const IptvOrgPlaylist({required this.kind, required this.code, required this.name, this.flag}); final IptvOrgKind kind; final String code; final String name; final String? flag; String get url; String get sourceName => 'iptv-org · $name'; }` — `url` según las plantillas de F1 (país en minúsculas).
    - `List<IptvOrgPlaylist> parseIptvOrgCountries(String json)` (ordenado por `name`, ignora entradas sin `code`, guarda `flag`) y `List<IptvOrgPlaylist> parseIptvOrgCategories(String json)` (ignora `id == 'xxx'`, ordenado por `name`).
    - `class IptvOrgCatalog { IptvOrgCatalog({http.Client? client}); static const List<IptvOrgPlaylist> recommended; Future<List<IptvOrgPlaylist>> countries(); Future<List<IptvOrgPlaylist>> categories(); }` — GET a la API con timeout de 20 s, cache en memoria tras el primer éxito, lanza si el status ≠ 200.
    - `recommended` exacto, en este orden: país `pe` Perú, `mx` México, `ar` Argentina, `co` Colombia, `cl` Chile, `es` España, `ve` Venezuela, `ec` Ecuador, `us` Estados Unidos; idioma `spa` Todo en español; categoría `news` Noticias, `sports` Deportes, `kids` Infantil, `movies` Películas, `music` Música, `documentary` Documentales.
  - `TvData` gana: `Future<List<Source>> sources()`, `Future<void> addSource(Source s)` (si `Sql.sourceNameExists(s.name)` → `StateError('duplicate')`; luego `Utils.processSource(s)`; luego guarda `lastRefresh_<id>` con la hora actual buscando el id por nombre; `tvSourcesVersion.value++`), `Future<void> deleteSource(int id)`, `Future<void> setSourceEnabled(int id, bool enabled)` (ambas incrementan `tvSourcesVersion`), `Future<SourceRefreshResult> refreshSources({bool onlyStale = false, int? onlySourceId})`, `bool get isRefreshing`, `Future<DateTime?> lastRefresh(int sourceId)`, `Future<bool> autoRefreshEnabled()` (clave `tvAutoRefresh`, por defecto `true`), `Future<void> setAutoRefreshEnabled(bool v)` (`'1'`/`'0'`), `IptvOrgCatalog get catalog` (instancia compartida).
  - `FakeTvData` gana implementaciones en memoria de todo lo anterior (lista `sourcesList`, `addedSources`, `deletedIds`, `refreshCalls` con sus parámetros, mapa `lastRefreshes`, `autoRefresh` bool, y `catalog` inyectable por constructor `IptvOrgCatalog? catalog`), más `Object? addSourceError` para forzar errores.

- [x] **Paso 1: tests que fallan:**

```dart
// source_refresher_test.dart  (fakes de las 4 funciones; fuentes: A m3uUrl, B xtream, C m3uUrl deshabilitada,
//                              D 'Custom Channels' m3u url '', E m3uUrl url '')
test('solo refresca fuentes válidas', () async { ...; expect(refreshed, ['A', 'B']); });
test('onlyStale salta las actualizadas hace < 24 h', ...);   // A hace 2 h, B hace 30 h → solo B
test('un fallo no corta el resto', ...);                      // A lanza → failedNames == ['A'], refreshed == 1
test('llamadas simultáneas comparten la ejecución', ...);     // dos refreshAll() a la vez → cada fuente 1 vez
test('incrementa tvSourcesVersion si refrescó algo', ...);
test('guarda la hora de refresco', ...);                      // saveRefresh(idA, now)

// iptv_org_catalog_test.dart
test('parsea países y arma la URL', () {
  final l = parseIptvOrgCountries('[{"name":"Peru","code":"PE","languages":["spa"],"flag":"🇵🇪"},{"name":"Chile","code":"CL","languages":[],"flag":"🇨🇱"}]');
  expect(l.map((p) => p.code), ['CL', 'PE']);
  expect(l[1].url, 'https://iptv-org.github.io/iptv/countries/pe.m3u');
  expect(l[1].sourceName, 'iptv-org · Peru');
});
test('categorías sin xxx', ...);    // [{"id":"news","name":"News"},{"id":"xxx","name":"XXX"}] → solo news; url /categories/news.m3u
test('recomendado de idioma usa /languages/', () =>
    expect(IptvOrgCatalog.recommended.firstWhere((p) => p.kind == IptvOrgKind.language).url,
        'https://iptv-org.github.io/iptv/languages/spa.m3u'));
test('countries() cachea y lanza en error HTTP', ...);  // MockClient: 1.ª llamada 200, 2.ª no pega a la red; otro con 500 → throws
```

- [x] **Paso 2:** `flutter test test/backend/` → FALLAN.
- [x] **Paso 3:** implementa.
- [x] **Paso 4:** `flutter test` → PASA; `flutter analyze` sin errores.
- [x] **Paso 5:** commit `feat: refresco seguro de fuentes, catálogo iptv-org y arreglo de grupos`.

---

### Tarea 7: Backend de listas propias (F3)

**Archivos:**
- Crear: `lib/models/user_playlist.dart`, `lib/backend/user_playlists_sql.dart`
- Modificar: `lib/backend/db_factory.dart` (migración 4), `lib/screens/tv/tv_data.dart`, `test/screens/tv/fakes.dart`
- Test: `test/screens/tv/fake_user_playlists_test.dart` (prueba el fake que usarán las pantallas)

**Interfaces:**
- Produce:
  - Migración `SqliteMigration(4, …)`:
    ```sql
    CREATE TABLE "user_playlists" ("id" INTEGER PRIMARY KEY, "name" varchar(100) NOT NULL, "created_at" integer);
    CREATE UNIQUE INDEX index_user_playlists_name ON user_playlists(name);
    CREATE TABLE "user_playlist_items" ("id" INTEGER PRIMARY KEY, "playlist_id" integer NOT NULL,
      "source_id" integer NOT NULL, "channel_name" varchar(100) NOT NULL, "position" integer NOT NULL);
    CREATE UNIQUE INDEX index_user_playlist_items_unique ON user_playlist_items(playlist_id, source_id, channel_name);
    UPDATE sources SET source_type = 2 WHERE name = 'Custom Channels';
    ```
    (una `tx.execute` por sentencia).
  - `class UserPlaylist { const UserPlaylist({required this.id, required this.name, required this.channelCount}); final int id; final String name; final int channelCount; }`
  - `abstract final class UserPlaylistsSql` (métodos `static`):
    - `Future<List<UserPlaylist>> all()` — `SELECT p.id, p.name, COUNT(c.id) FROM user_playlists p LEFT JOIN user_playlist_items i ON i.playlist_id = p.id LEFT JOIN channels c ON c.source_id = i.source_id AND c.name = i.channel_name GROUP BY p.id ORDER BY p.name COLLATE NOCASE` (cuenta solo canales que existen hoy).
    - `Future<int> create(String name)` — lanza `StateError('duplicate')` si el nombre existe (sin distinguir mayúsculas).
    - `Future<void> rename(int id, String name)` — mismo `StateError('duplicate')`.
    - `Future<void> delete(int id)` — borra ítems y lista en una transacción.
    - `Future<bool> add(int playlistId, Channel c)` — `INSERT OR IGNORE` con `position = COALESCE(MAX(position), -1) + 1`; devuelve `true` si insertó.
    - `Future<void> remove(int playlistId, Channel c)`.
    - `Future<void> move(int playlistId, Channel c, int delta)` — `delta` = -1 o +1; intercambia `position` con el vecino inmediato en ese sentido (si no hay vecino, nada).
    - `Future<List<Channel>> channels(int playlistId)` — `SELECT c.* FROM user_playlist_items i JOIN channels c ON c.source_id = i.source_id AND c.name = i.channel_name WHERE i.playlist_id = ? ORDER BY i.position`, mapeado con `Sql.rowToChannel`.
    - `Future<Channel> addManualChannel({required String name, required String url})` — `Sql.addCustomChannel(name: name, url: url, group: 'Mis canales', favorite: false)` y devuelve el canal leído por `(name, source de customSourceName)`.
  - `TvData` gana: `userPlaylists()`, `createUserPlaylist(String name) → Future<int>`, `renameUserPlaylist(int id, String name)`, `deleteUserPlaylist(int id)`, `addToUserPlaylist(int playlistId, Channel c) → Future<bool>`, `removeFromUserPlaylist(int playlistId, Channel c)`, `moveInUserPlaylist(int playlistId, Channel c, int delta)`, `userPlaylistChannels(int playlistId)`, `addManualChannel({required String name, required String url}) → Future<Channel>` — delegan en `UserPlaylistsSql`.
  - `FakeTvData` implementa lo anterior en memoria con la **misma semántica** (duplicados sin mayúsculas → `StateError('duplicate')`, `add` devuelve `false` si ya estaba, `move` intercambia con el vecino, `channelCount` = tamaño de la lista).

- [x] **Paso 1: tests que fallan** (sobre `FakeTvData`, para fijar la semántica que usan las pantallas):

```dart
test('crear duplicado lanza', () async {
  final d = FakeTvData(); await d.createUserPlaylist('Noticias');
  expect(() => d.createUserPlaylist('noticias'), throwsStateError);
});
test('add devuelve false si ya estaba', ...);
test('move intercambia con el vecino y no sale de los bordes', ...);
test('channelCount refleja los canales', ...);
```

- [x] **Paso 2:** → FALLAN. **Paso 3:** implementa (migración, SQL, modelo, `TvData`, fake). **Paso 4:** `flutter test` → PASA; `flutter analyze` sin errores.
- [x] **Paso 5:** commit `feat: listas de canales propias (BD + fachada)`.

---

### Tarea 8: Ajustes TV — fuentes, iptv-org y M3U por URL (F1, F2, H2, H6)

**Archivos:**
- Reescribir: `lib/screens/tv/tv_settings.dart`
- Crear: `lib/screens/tv/tv_iptv_org_screen.dart`, `lib/screens/tv/tv_add_m3u_screen.dart`
- Test: `test/screens/tv/tv_settings_test.dart`, `tv_iptv_org_screen_test.dart`, `tv_add_m3u_screen_test.dart`

**Interfaces:**
- Consume: `TvData` (T1, T6), `TvFocusable`, `TvTextField`, `showTvConfirm`, `showTvOptions`, `formatAgo`, `IptvOrgPlaylist`, `HttpStatusException`.
- Produce:
  - `class TVSettings extends StatefulWidget { const TVSettings({super.key, TvData data = const TvData()}); }` — keys `tv-settings-iptv`, `tv-settings-m3u`, `tv-settings-refresh`, `tv-settings-auto`, `tv-source-<id>`.
  - `class TvIptvOrgScreen extends StatefulWidget { const TvIptvOrgScreen({super.key, required TvData data}); }` — keys `tv-iptv-section-<0|1|2>`, `tv-iptv-item-<index>`.
  - `class TvAddM3uScreen extends StatefulWidget { const TvAddM3uScreen({super.key, required TvData data}); }` — keys `tv-m3u-name`, `tv-m3u-url`, `tv-m3u-add`.

**Comportamiento:**
- `TVSettings` (lista vertical, máx. 720 dp, `TvFocusable` por fila):
  1. `Agregar desde iptv-org` → `push` `TvIptvOrgScreen`.
  2. `Agregar lista M3U por URL` → `push` `TvAddM3uScreen`.
  3. `Actualizar listas ahora` → si `data.isRefreshing` muestra `Ya se están actualizando las listas`; si no, `Actualizando listas…` → `data.refreshSources()` → `Listas actualizadas` o `{n} listas no se pudieron actualizar`.
  4. `Actualización automática (cada 24 h)` con valor `Activada`/`Desactivada`; OK alterna (`setAutoRefreshEnabled`).
  5. Encabezado `Mis fuentes` y una fila por `data.sources()`: nombre + `Actualizada {formatAgo}` / `Nunca actualizada` / `Desactivada`. La fuente `customSourceName` no se lista. OK → `showTvOptions`: `Actualizar` (`refreshSources(onlySourceId: id)`), `Activar`/`Desactivar`, `Eliminar` (tras `showTvConfirm('¿Eliminar la fuente «{nombre}» y sus canales?')`).
  - Recarga la lista al volver de las sub-pantallas y cuando cambia `tvSourcesVersion`. Mensajes en `TvTheme.success`/`TvTheme.error` según el resultado.
- `TvIptvOrgScreen`: título `Listas de iptv-org`; columna izquierda con 3 secciones (`Recomendados`, `Países`, `Categorías`; enfocar una la muestra); derecha `ListView` de `TvFocusable` con `flag` + `name` y chip `Agregada` si la `url` ya está en `data.sources()`. `Países`/`Categorías` se cargan al abrirse la sección; error → `No se pudo cargar el catálogo. Revisa tu conexión.` + `Reintentar`. OK en un ítem: si ya está → snackbar `Ya agregada`; si no → diálogo modal no cancelable `Agregando «{nombre}»…` → `data.addSource(Source(name: p.sourceName, url: p.url, sourceType: SourceType.m3uUrl))` → snackbar `«{nombre}» agregada` y chip; `HttpStatusException` → `Esta lista no está disponible`; `StateError('duplicate')` → `Ya existe una lista con ese nombre`; otro → `No se pudo agregar la lista`.
- `TvAddM3uScreen`: el formulario (título `Agregar lista M3U`, dos `TvTextField`, botón `Agregar lista`). Validación: vacíos → `Completa todos los campos`; sin `http://`/`https://` → `La URL debe empezar con http:// o https://`. Llama `data.addSource(...)` con `SourceType.m3uUrl`; mismos mensajes de error; éxito → `Lista agregada correctamente` y limpia. No usa `Error.tryAsync`.

- [x] **Paso 1: tests que fallan:**

```dart
// tv_settings_test.dart
testWidgets('↓ recorre todas las filas (regresión H2)', ...);
testWidgets('no lista Custom Channels y muestra "Actualizada hace 3 h"', ...);
testWidgets('Actualizar listas ahora llama refreshSources y muestra el resultado', ...);
testWidgets('con refresco en curso muestra "Ya se están actualizando las listas"', ...);
testWidgets('alternar actualización automática', ...);       // autoRefresh false; texto 'Desactivada'
testWidgets('eliminar fuente pide confirmación', ...);        // Cancelar → no borra; Eliminar → deletedIds == [id]

// tv_iptv_org_screen_test.dart  (catalog con MockClient)
testWidgets('Recomendados muestra Perú primero', ...);
testWidgets('agregar Perú llama addSource con la URL correcta', ...);  // url .../countries/pe.m3u, nombre 'iptv-org · Perú'
testWidgets('ítem ya agregado muestra chip y no vuelve a agregar', ...);
testWidgets('404 muestra "Esta lista no está disponible"', ...);       // addSourceError = HttpStatusException(404)
testWidgets('error del catálogo muestra Reintentar', ...);              // MockClient 500 en Países

// tv_add_m3u_screen_test.dart
testWidgets('↓ recorre nombre → URL → Agregar', ...);
testWidgets('vacíos / URL inválida / duplicado / éxito', ...);         // 4 casos, mensajes exactos
```

- [x] **Paso 2:** → FALLAN. **Paso 3:** implementa. **Paso 4:** `flutter test test/screens/tv/` → PASAN.
- [x] **Paso 5:** commit `feat(tv): ajustes con catálogo iptv-org, mis fuentes y actualización automática`.

---

### Tarea 9: Pestaña "Mis listas" y "Agregar a una lista…" (F3)

**Archivos:**
- Crear: `lib/screens/tv/tv_user_playlists.dart`
- Test: `test/screens/tv/tv_user_playlists_test.dart`

**Interfaces:**
- Consume: `TvData` (T7), `TvFocusable`, `TvChannelCard`, `showTvChannelMenu`, `showTvTextPrompt`, `showTvConfirm`, `showTvOptions`, `TvPlayCallback`, `openTvPlayer`.
- Produce:
  - `class TvUserPlaylistsScreen extends StatefulWidget { const TvUserPlaylistsScreen({super.key, TvData data = const TvData(), TvPlayCallback? onPlay}); }` — estado público `TvUserPlaylistsScreenState` con `Future<void> reload()`. Keys: `tv-playlist-<index>`, `tv-playlist-new`, `tv-playlist-add-url`, `tv-playlist-channel-<index>`.
  - `Future<void> showAddToPlaylistDialog(BuildContext context, {required TvData data, required Channel channel})` — `showTvOptions` con las listas existentes + `Nueva lista` al final; `Nueva lista` → `showTvTextPrompt(title: 'Nueva lista', label: 'Nombre de la lista', confirmLabel: 'Crear')` → crea y agrega. Snackbar `Agregado a «X»` / `Ya está en «X»` / `Ya existe una lista con ese nombre`.
  - Función de conveniencia `TvAddToPlaylistCallback tvAddToPlaylist(TvData data) => (ctx, ch) => showAddToPlaylistDialog(ctx, data: data, channel: ch);`

**Comportamiento:**
- Izquierda (`TvTheme.groupsWidth`): listas (`nombre` + `{n} canales`) y al final `Nueva lista`. Enfocar una lista carga sus canales (debounce 300 ms como en la Tarea 4). OK largo sobre una lista → `showTvOptions`: `Renombrar` (`showTvTextPrompt` con `initial`), `Eliminar` (`showTvConfirm('¿Eliminar la lista «{nombre}»?')`).
- Derecha: grilla igual a la Tarea 4; la primera tarjeta es `Agregar canal por URL` (icono `Icons.add_link`) → dos `showTvTextPrompt` (`Nombre del canal`, `URL del stream`; la URL debe empezar con `http://` o `https://`, si no muestra el mensaje de la tabla) → `data.addManualChannel` → `data.addToUserPlaylist`. OK en un canal → `onPlay(context, canales, i)` (sin contar la tarjeta de agregar). OK largo en un canal → `showTvOptions`: `Reproducir`, `Mover antes`, `Mover después`, `Quitar de la lista` (mantiene el foco en el canal movido / en el vecino al quitar).
- Vacíos: sin listas → `Crea tu primera lista con «Nueva lista».` con foco en `Nueva lista`; lista vacía → texto de lista vacía (la tarjeta `Agregar canal por URL` sigue presente).
- En `TVChannelBrowser` y `TVSearch` (instancias creadas en la Tarea 10) se pasará `onAddToPlaylist: tvAddToPlaylist(data)`.

- [x] **Paso 1: tests que fallan** (`FakeTvData` con canales y listas en memoria):

```dart
testWidgets('crear lista desde "Nueva lista"', ...);                 // aparece y queda seleccionada
testWidgets('nombre duplicado muestra mensaje', ...);
testWidgets('agregar canal por URL lo agrega a la lista', ...);
testWidgets('URL de stream inválida muestra mensaje', ...);
testWidgets('OK reproduce con índice sin contar la tarjeta de agregar', ...); // canal 0 → onPlay(..., 0)
testWidgets('Mover después y Quitar de la lista', ...);
testWidgets('Eliminar lista pide confirmación', ...);
testWidgets('showAddToPlaylistDialog agrega y avisa si ya estaba', ...);
```

- [x] **Paso 2:** → FALLAN. **Paso 3:** implementa. **Paso 4:** `flutter test test/screens/tv/` → PASAN.
- [x] **Paso 5:** commit `feat(tv): pestaña Mis listas y agregar canales a listas propias`.

---

### Tarea 10: `TVHome` — menú lateral y scopes de foco (H2, H3, H4, H11, H12, F2)

**Archivos:** Reescribir `lib/screens/tv/tv_home.dart`; Test `test/screens/tv/tv_home_test.dart`

**Interfaces:**
- Consume: `TvEdgeFocusAction`, `focusFirstIn`, `TVChannelBrowserState.reload`, `TvUserPlaylistsScreenState.reload`, `tvAddToPlaylist`, `tvSourcesVersion`, `TvFocusable`, `TvTheme`.
- Produce: `class TVHome extends StatefulWidget { const TVHome({super.key, TvData data = const TvData(), TvPlayCallback? onPlay}); }` (pasa `data`, `onPlay` y `onAddToPlaylist: tvAddToPlaylist(data)` a los hijos). Keys del menú `ValueKey('tv-nav-$index')`: 0 `Canales` (`Icons.live_tv`), 1 `Favoritos` (`Icons.star`), 2 `Mis listas` (`Icons.playlist_play`), 3 `Buscar` (`Icons.search`), 4 `Ajustes` (`Icons.settings`).

**Comportamiento:**
- **Se eliminan** el `Shortcuts`/`Actions` de flechas, los `_Navigate*Intent`, `_isNavigationFocused` y los `FocusNode` sueltos.
- `Scaffold(backgroundColor: TvTheme.background)` + `Padding(TvTheme.safeArea)`.
- Menú: `FocusScope(node: _sidebarScope)` con 5 `TvFocusable`. Ancho animado `sidebarCollapsed` (solo iconos) con foco en contenido / `sidebarExpanded` (icono + texto `fontBody`) con foco en el menú. La pestaña activa se marca con `TvTheme.accent`. `autofocus: true` en el ítem 0. Enfocar un ítem cambia la pestaña visible. OK o → → `_enterContent()` (el menú está envuelto en `Actions({DirectionalFocusIntent: TvEdgeFocusAction(onEdge: (d) { if (d == TraversalDirection.right) _enterContent(); })})`).
- Contenido: `IndexedStack` con hijos `ExcludeFocus(excluding: i != _selectedIndex, child: FocusScope(node: _tabScopes[i], child: …))`, envuelto en `Actions({DirectionalFocusIntent: TvEdgeFocusAction(onEdge: (d) { if (d == TraversalDirection.left) _focusSidebar(); })})`.
- `_enterContent()`: si `focusFirstIn(_tabScopes[_selectedIndex])` es `false`, el foco se queda en el menú.
- Al pasar a Favoritos → `reload()` del explorador de favoritos; a Mis listas → `reload()` de la pantalla de listas (vía `GlobalKey`).
- `tvSourcesVersion`: al cambiar, marca `_pendingReload = true`. Se aplica (recrear con `UniqueKey` el explorador de Canales y recargar Favoritos/Mis listas) **solo** cuando el foco está en el menú — inmediatamente si ya lo está, o en el próximo cambio de foco hacia el menú. Nunca mientras el foco está en el contenido.
- Atrás: `PopScope(canPop: <foco en el menú>, onPopInvokedWithResult: (didPop, _) { if (!didPop) _focusSidebar(); })`; recalcula `canPop` con `setState` al moverse el foco entre menú y contenido.

- [x] **Paso 1: tests que fallan** (`pumpTv(t, TVHome(data: fake, onPlay: …))`):

```dart
testWidgets('al iniciar el foco está en Canales (regresión H4)', ...);
testWidgets('→ desde Canales entra al primer grupo', ...);
testWidgets('← desde el grupo vuelve al menú en el mismo ítem', ...);
testWidgets('Buscar: → enfoca el campo sin abrir teclado (regresión H3)', ...);  // tv-nav-3
testWidgets('Ajustes: → enfoca la primera fila', ...);                             // tv-nav-4 → tv-settings-iptv
testWidgets('Mis listas sin listas: → enfoca "Nueva lista"', ...);                 // tv-nav-2 → tv-playlist-new
testWidgets('volver a Canales restaura la última tarjeta enfocada', ...);
testWidgets('Atrás desde el contenido vuelve al menú', ...);                      // t.binding.handlePopRoute()
testWidgets('Atrás con el campo de búsqueda en edición vuelve al menú', ...);     // [RF3]
testWidgets('pestaña sin enfocables: → deja el foco en el menú', ...);            // Favoritos vacío
testWidgets('favorito marcado en Canales aparece en Favoritos', ...);
testWidgets('actualización de fuentes no recarga mientras se navega', (t) async {
  // foco en tv-channel-3; tvSourcesVersion.value++; pumpAndSettle
  // → isFocused(tv-channel-3) y groupCalls sin llamadas nuevas;
  // ← ← hasta el menú → groupCalls aumenta (recarga aplicada)                    [RF2]
});
```

- [x] **Paso 2:** → FALLAN. **Paso 3:** implementa. **Paso 4:** `flutter test` (todo) → PASA; `flutter analyze` sin errores.
- [x] **Paso 5:** commit `feat(tv): menú lateral colapsable, 5 pestañas y scopes de foco`.

---

### Tarea 11: Arranque, detección de TV y Android (H9, H13, F2)

**Archivos:**
- Crear: `lib/screens/tv/tv_bootstrap.dart`, `android/app/src/main/res/drawable/tv_banner.xml`
- Modificar: `lib/main.dart`, `android/app/src/main/kotlin/com/example/open_tv/MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`, `ANDROID_TV_README.md`
- Test: `test/platform_detector_test.dart`, `test/screens/tv/tv_bootstrap_test.dart`

**Interfaces:**
- Produce:
  - `main.dart`: `class PlatformDetector { static const MethodChannel channel = MethodChannel('dev.fredol.open_tv/device'); static bool Function() isAndroidPlatform = () => !kIsWeb && Platform.isAndroid; static Future<void> init(); static bool get isAndroidTV; static bool get isMobile; }` — `isAndroidTV` es `true` si `const bool.fromEnvironment('FORCE_TV')` o si `init()` obtuvo `true` de `channel.invokeMethod<bool>('isTv')` (solo cuando `isAndroidPlatform()`); excepción → `false`. Se elimina `_forceTVMode`.
  - Kotlin `MainActivity.configureFlutterEngine`: `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.fredol.open_tv/device")`, método `"isTv"` → `(getSystemService(UI_MODE_SERVICE) as UiModeManager).currentModeType == Configuration.UI_MODE_TYPE_TELEVISION || packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)`.
  - `tv_bootstrap.dart`:
    - `Future<void> ensureDefaultTvSources({TvData data = const TvData()})` — si `!(await Sql.hasSources())`: `data.addSource(Source(name: 'IPTV Español', url: 'https://iptv-org.github.io/iptv/languages/spa.m3u', sourceType: SourceType.m3uUrl))` y luego `Sql.addTestChannels()`. Si ya hay fuentes, nada.
    - `class TvBootstrap extends StatefulWidget { const TvBootstrap({super.key, TvData data = const TvData(), Future<void> Function()? prepare, WidgetBuilder? homeBuilder}); }` — `prepare` por defecto `() => ensureDefaultTvSources(data: data)`; `homeBuilder` por defecto `(_) => TVHome(data: data)`. Pantalla: `Icons.live_tv` 96 dp + `Preparando canales…` + spinner. Error → `No se pudo descargar la lista de canales` + `Reintentar` (autofocus) y `Continuar`. Al mostrar el home: si `await data.autoRefreshEnabled()` → `unawaited(data.refreshSources(onlyStale: true))`.
  - `main()`: `WidgetsFlutterBinding.ensureInitialized(); MediaKit.ensureInitialized(); await PlatformDetector.init();` En TV: orientación landscape, `runApp` **inmediato** con `home: const TvBootstrap()` y `themeMode: ThemeMode.dark`. Móvil: flujo actual sin cambios.
  - Manifest: `android.software.leanback` → `required="false"`; `<application android:banner="@drawable/tv_banner" …>`.
  - `tv_banner.xml`: `layer-list` de 320×180 dp, fondo `#0E0E12`, `@mipmap/ic_launcher` centrado (`android:gravity="center"`, 96×96 dp).
  - `ANDROID_TV_README.md`: tablas de controles nuevas (explorador y reproductor), F1–F3, cómo forzar modo TV (`flutter run --dart-define=FORCE_TV=true`); elimina "Cambiar entre Modo Móvil y TV".

- [x] **Paso 1: tests que fallan:**

```dart
// platform_detector_test.dart
setUp(() => PlatformDetector.isAndroidPlatform = () => true);
// handler mock 'isTv' → true ⇒ isAndroidTV true; handler lanza PlatformException ⇒ false;
// isAndroidPlatform = () => false ⇒ false sin llamar al canal

// tv_bootstrap_test.dart
// prepare = Completer → 'Preparando canales…'; completa → Text('HOME'); refreshCalls == [onlyStale: true]
// autoRefresh = false → refreshCalls vacío
// prepare lanza → mensaje; isFocused(Reintentar); OK → prepare llamado 2 veces; 'Continuar' → HOME
```

- [x] **Paso 2:** → FALLAN. **Paso 3:** implementa Dart, Kotlin, manifest, banner y README.
- [x] **Paso 4:** `flutter test` → PASA; `flutter analyze` sin errores; `flutter build apk --debug` compila.
- [x] **Paso 5:** commit `feat(tv): detección real de TV, arranque con carga, auto-actualización y banner`.

---

### Tarea 12: Verificación final en el dispositivo

- [x] **Paso 1:** `flutter analyze` → 0 errores; sin avisos nuevos en archivos tocados respecto a la Tarea 0.
- [x] **Paso 2:** `flutter test` → todo PASA (pega el resumen `+N: All tests passed!`).
- [x] **Paso 3:** `flutter build apk --release` → anota el tamaño.
- [ ] **Paso 4:** `adb connect <IP_TV>:5555` y `adb install -r build/app/outputs/flutter-apk/app-release.apk`. **Pide la IP al usuario** si no la tienes (último uso conocido: `192.168.1.60:5555`). Para un arranque limpio, pregunta antes de borrar datos (`adb shell pm clear dev.fredol.open_tv` borra favoritos y listas).
- [ ] **Paso 5: checklist con el control remoto** (marca y anota fallos):
  - [ ] Banner en el launcher; en el primer arranque `Preparando canales…`.
  - [ ] Foco inicial en `Canales`; ↑↓ cambian de pestaña; → entra; ← vuelve; Atrás desde contenido → menú; Atrás desde el menú → sale.
  - [ ] Grupos: recorrer rápido no parpadea; OK pasa a la grilla; la grilla hace scroll con el foco visible.
  - [ ] OK largo en un canal → favorito (también se puede quitar France 24) y `Agregar a una lista…`.
  - [ ] Buscar: → enfoca sin teclado; OK abre teclado; "noticias" + enviar → resultados con foco; ↑ vuelve al campo.
  - [ ] Ajustes → `Agregar desde iptv-org` → `Perú` → se agrega; en Canales aparecen sus grupos **sin duplicarse** con los de la lista en español (H14); "Todos los canales" incluye ambos.
  - [ ] `Mis fuentes` muestra `Actualizada hace …`; `Actualizar` en una fuente funciona; `Actualizar listas ahora` no falla por `Custom Channels` (H15).
  - [ ] Auto-actualización: con una fuente de hace > 24 h (o cambiando el reloj), al abrir la app se actualiza sin mover el foco; favoritos y listas propias se mantienen.
  - [ ] Mis listas: crear "Mi lista", agregar 3 canales desde Canales y 1 por URL; mover y quitar; reproducir desde la lista con zapping dentro de la lista.
  - [ ] Reproductor en vivo: ↑↓ cambian de canal con overlay; OK info; ←→ no cortan el directo; OK largo → opciones; Atrás vuelve con foco en el último canal visto.
  - [ ] Canal caído: ≤ 30 s → `No se pudo reproducir este canal` con `Reintentar`/`Siguiente canal`/`Volver`.
  - [ ] 10 minutos viendo un canal: la pantalla no se apaga.
- [ ] **Paso 6:** si canales que en VLC funcionan fallan aquí, captura `adb logcat -d | grep -iE "mpv|media_kit|flutter"` y repórtalo al usuario en vez de seguir probando a ciegas (la siguiente opción sería ExoPlayer; fuera de este plan).
- [ ] **Paso 7:** commit final si hubo ajustes: `chore(tv): verificación en dispositivo`.
