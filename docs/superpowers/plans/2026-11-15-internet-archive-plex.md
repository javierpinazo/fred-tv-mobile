# Internet Archive y Plex on demand — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activar Internet Archive y Plex en el menú «On demand» con el mismo patrón que Pluto (proveedor + `OnDemandResolver` + `TvCatalogScreen` + `TvVodPlayer`).

**Architecture:** Un parser puro y un proveedor por servicio, como `pluto_vod_*`. Ambos implementan `OnDemandProvider` y `OnDemandResolver`; el catálogo se parsea fuera del hilo de la interfaz y se cachea 30 min; la URL de vídeo se resuelve al pulsar «Ver». Sin cambios en las pantallas.

**Tech Stack:** Flutter 3.32, `http`, `compute`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-15-servicios-restantes-design.md` (YouTube queda fuera de este plan: espera los canales que dé el usuario).

## Global Constraints

- Solo películas (Plex: `type == 'movie'`); sin series, subtítulos ni favoritos.
- Cualquier fallo de red/HTTP/forma del JSON → `OnDemandUnavailableException`; nunca pantalla vacía.
- Catálogo en caché 30 min, parseado con `compute`; el token de Plex no se guarda con el catálogo (`resolve()` pide sesión nueva).
- Identificadores validados antes de concatenarlos en una URL: Plex `^[A-Za-z0-9_-]{1,64}$`, Archive `^[A-Za-z0-9._-]{1,128}$` → `ArgumentError`.
- Internet Archive no está moderado: se descartan títulos con contenido para adultos con un filtro de palabras (ver Task 1); es un filtro de mínimos, no una garantía.
- Reutilizar `OnDemandStream`/`OnDemandResolver`/`PlutoVodProvider` como modelo (`lib/backend/ondemand/pluto_vod_provider.dart`); `TvVodPlayer` ya reproduce `OnDemandStream` con cabeceras.
- No push; un commit por tarea con `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Los tests de TV fijan locale `es`.

## Review Focus

- Archive: película con descripción larguísima o con HTML, sin año, sin `.mp4` en sus archivos, con varios `.mp4` de formatos distintos.
- Archive: títulos para adultos que el filtro debe dejar fuera, y que no descarte títulos legítimos por coincidencia parcial (p. ej. «Adulto» en «Adultos»… decidir con test; «adult» como palabra completa).
- Plex: la misma película en varios estantes (una vez, con todos), estantes con solo series (no aparecen como categoría vacía), película sin `Part` HLS (resolve → excepción clara).
- Plex: `resolve()` sin `Media` de `protocol == hls` o con token caducado → `OnDemandUnavailableException`, no URL rota.
- Ids con caracteres raros llegando a `resolve()`.

---

## File Structure

- Modify `lib/backend/ondemand/on_demand_provider.dart` — `ArchiveSource`, `PlexSource`.
- Create `lib/backend/ondemand/archive_vod_parser.dart`, `archive_vod_provider.dart`, `plex_vod_parser.dart`, `plex_vod_provider.dart`.
- Modify `lib/backend/ondemand/on_demand_registry.dart`, `lib/screens/tv/ondemand/on_demand_play.dart` (el `case` provisional de fuentes nuevas).
- Tests: `test/backend/ondemand/archive_vod_parser_test.dart`, `archive_vod_provider_test.dart`, `plex_vod_parser_test.dart`, `plex_vod_provider_test.dart`; actualizar `test/screens/tv/tv_ondemand_test.dart`.

---

### Task 1: Modelos y parser de Internet Archive

**Files:**
- Modify: `lib/backend/ondemand/on_demand_provider.dart`, `lib/screens/tv/ondemand/on_demand_play.dart` (casos provisionales `ArchiveSource`/`PlexSource` en el `switch` de `onDemandPlayerFor`: lanzan `UnsupportedError`, igual que `PlutoSource`)
- Create: `lib/backend/ondemand/archive_vod_parser.dart`
- Test: `test/backend/ondemand/archive_vod_parser_test.dart`

**Interfaces:**
- Produces: `class ArchiveSource extends OnDemandSource { const ArchiveSource(super.videoId); }` (`videoId` = identifier), `class PlexSource extends OnDemandSource { const PlexSource(super.videoId); }` (`videoId` = ratingKey); `List<OnDemandTitle> parseArchiveSearch(String json)`; `bool isAdultText(String text)`; `String archiveDecade(int? year)`.

- [ ] **Step 1: Write the failing tests** (`archive_vod_parser_test.dart`), con un helper `search(List<Map> docs)` que arma `{"response":{"docs":[...]}}`:
  - `campos`: `{identifier:'carne-1968', title:'Carne', year:'1968', description:'Una película…', downloads:5}` → `id`, `title`, `posterUrl == 'https://archive.org/services/img/carne-1968'`, `source` es `ArchiveSource('carne-1968')`, `categories == ['1960s']`, `details == '1968'`.
  - `año ausente o inválido` → categoría `'Sin fecha'` y `details == ''`; `year` puede venir como número, texto o lista.
  - `description` larga con HTML (`<br/>`, `<b>`) → sin etiquetas, espacios colapsados, recortada a 400 caracteres con «…»; ausente → `''`; puede venir como lista de textos.
  - `title` puede venir como lista → se usa el primero; sin `identifier` o sin título → descartado.
  - `isAdultText`: verdadero para `'XXX'`, `'Película erótica'`, `'sexploitation'`, `'explotación sexual'`, `'porn'`, `'18+'`, `'nsfw'`; falso para `'Los adultos y el cine'`, `'Adulto contemporáneo'` no… — **regla**: palabras completas (`\b`) de la lista `xxx, porn, porno, erotic, erótic(a|o|os|as), erotica, sexploitation, nsfw, 18+, +18, explotación sexual, explotacion sexual, hardcore` y la palabra `adult` / `adults` solo si va acompañada de `film|movie|only|content|entertainment`; falso para `'Los adultos y el cine'` y `'Un adulto mayor'`.
  - `el filtro se aplica a título y descripción`: un doc con `'erótica'` en la descripción se descarta.
  - `JSON inválido, sin response.docs o sin ningún título válido` → `OnDemandUnavailableException`.
  - `archiveDecade(1968) == '1960s'`, `archiveDecade(2003) == '2000s'`, `archiveDecade(null) == 'Sin fecha'`, `archiveDecade(1800) == 'Sin fecha'` (fuera de 1890–2099).

- [ ] **Step 2: Run** `flutter test test/backend/ondemand/archive_vod_parser_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** los modelos, los `case` provisionales y `archive_vod_parser.dart` (un campo del JSON de Archive puede ser texto o lista: helper `_first(Object?) -> String`).

- [ ] **Step 4: Run** `flutter test test/backend/ondemand test/screens/tv` — Expected: PASS; `flutter analyze lib` sin errores (el `switch` sellado debe seguir exhaustivo).

- [ ] **Step 5: Commit** `feat(ondemand): modelos y parser de Internet Archive`.

---

### Task 2: Proveedor de Internet Archive

**Files:**
- Create: `lib/backend/ondemand/archive_vod_provider.dart`
- Test: `test/backend/ondemand/archive_vod_provider_test.dart`

**Interfaces:**
- Consumes: Task 1 (`parseArchiveSearch`, `ArchiveSource`) y `OnDemandProvider`, `OnDemandResolver`, `OnDemandStream`, `OnDemandUnavailableException`.
- Produces: `class ArchiveVodProvider implements OnDemandProvider, OnDemandResolver { ArchiveVodProvider({http.Client? client, DateTime Function()? now, Duration ttl = const Duration(minutes: 30), Future<List<OnDemandTitle>> Function(String json)? parse}); }` con `id == 'archive'`, `name == 'Internet Archive'`; `OnDemandStream pickArchiveStream(String identifier, String metadataJson)` (función pura, pública para probarla).

- [ ] **Step 1: Write the failing tests** con `MockClient`:
  - `titles()` pide `https://archive.org/advancedsearch.php` con `q=mediatype:movies AND collection:feature_films AND language:(spanish OR Spanish OR spa)`, `fl[]` = `identifier,title,year,description`, `rows=2000`, `output=json` y `sort[]=downloads desc`; pasa el cuerpo (UTF-8) a `parse`; caché de 30 min (2 llamadas → 1 petición; +31 min → otra).
  - `pickArchiveStream`: con `files` de formatos `h.264 IA`, `MPEG4`, `512Kb MPEG4` elige `h.264`; sin `h.264` elige `MPEG4`; luego `512Kb MPEG4`; luego cualquier `.mp4`; ignora archivos que no sean `.mp4`; nombres con espacios y paréntesis → URL `https://archive.org/download/<id>/Carne%20Argentina%20%281968%29.ia.mp4` (codificar cada segmento con `Uri.encodeComponent`); sin ningún `.mp4` → `OnDemandUnavailableException`; `headers` vacío.
  - `resolve()`: pide `https://archive.org/metadata/<id>` y devuelve `pickArchiveStream`; título que no es `ArchiveSource` o con id inválido (`a/b`, `x?y`, vacío, >128) → `ArgumentError`.
  - Errores: HTTP 500, `ClientException`, timeout y JSON roto en `titles()`/`resolve()` → `OnDemandUnavailableException`; el fallo no se cachea.

- [ ] **Step 2: Run** `flutter test test/backend/ondemand/archive_vod_provider_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** el proveedor, con la misma estructura de errores/caché que `PlutoVodProvider` (timeouts: búsqueda 60 s, metadata 20 s); parse por defecto `compute(parseArchiveSearch, json)`.

- [ ] **Step 4: Run** `flutter test test/backend/ondemand` — Expected: PASS.

- [ ] **Step 5: Probar contra Archive real** (test efímero, no se commitea): `titles()` devuelve entre 800 y 1.500 títulos, ninguno con texto de adultos según `isAdultText`, y `resolve` del primero da una URL que responde 200/206 a `GET` con `Range: bytes=0-1023`. Anotar cuántos descartó el filtro.

- [ ] **Step 6: Commit** `feat(ondemand): proveedor de Internet Archive`.

---

### Task 3: Parser del catálogo de Plex

**Files:**
- Create: `lib/backend/ondemand/plex_vod_parser.dart`
- Test: `test/backend/ondemand/plex_vod_parser_test.dart`

**Interfaces:**
- Consumes: `PlexSource` (Task 1).
- Produces: `List<OnDemandTitle> parsePlexHubs(List<({String title, String json})> hubs)` — cada elemento es un estante (nombre + cuerpo JSON de `…/hubs/sections/movies/<hub>?count=100`).

- [ ] **Step 1: Write the failing tests** (helper `hub(Map)` → `{"MediaContainer":{"Metadata":[...]}}`):
  - `solo películas`: un ítem `type:'show'` se descarta.
  - `sin duplicados con todos sus estantes como categorías, en orden de aparición`.
  - `campos`: `ratingKey`, `title`, `summary`, `thumb` → `posterUrl` (si falta, `art`; si falta, `''`), `details == '2012 · PG-13 · 82 min.'` (`duration` en ms; omite las partes ausentes), `source` es `PlexSource(ratingKey)`.
  - `incompletos`: sin `ratingKey` o sin `title` → descartado.
  - `estante sin películas` no aporta categorías; `estante con JSON inválido` se ignora si los demás son válidos.
  - `todos los estantes inválidos o sin películas` → `OnDemandUnavailableException`.

- [ ] **Step 2: Run** `flutter test test/backend/ondemand/plex_vod_parser_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** `parsePlexHubs` (mismo estilo que `parsePlutoVodCatalog`).

- [ ] **Step 4: Run** `flutter test test/backend/ondemand` — Expected: PASS.

- [ ] **Step 5: Commit** `feat(ondemand): parser del catálogo de Plex`.

---

### Task 4: Proveedor de Plex

**Files:**
- Create: `lib/backend/ondemand/plex_vod_provider.dart`
- Test: `test/backend/ondemand/plex_vod_provider_test.dart`

**Interfaces:**
- Consumes: `parsePlexHubs` (Task 3), `PlexSource`.
- Produces: `class PlexVodProvider implements OnDemandProvider, OnDemandResolver { PlexVodProvider({http.Client? client, DateTime Function()? now, Duration ttl = const Duration(minutes: 30), Future<List<OnDemandTitle>> Function(List<({String title, String json})> hubs)? parse}); }` con `id == 'plex'`, `name == 'Plex'`; `OnDemandStream pickPlexStream(String ratingKey, String token, String metadataJson)` (función pura).

- [ ] **Step 1: Write the failing tests** con `MockClient`:
  - Sesión: `POST https://clients.plex.tv/api/v2/users/anonymous` con cabeceras `X-Plex-Client-Identifier` (UUID v4 válido), `X-Plex-Product: Plex Web`, `X-Plex-Version`, `X-Plex-Platform`, `Accept: application/json`; la respuesta trae `authToken`; sin `authToken` o HTTP ≠ 2xx → `OnDemandUnavailableException`.
  - `titles()`: `GET https://vod.provider.plex.tv/hubs/promoted` (con `X-Plex-Token`), luego un `GET` por cada `Hub[].key` con `?count=100`; pasa `[(title, cuerpo)]` a `parse`; un estante que falla se omite si hay otros; todos fallan → excepción; caché 30 min.
  - `pickPlexStream`: del `Metadata[0].Media[]` elige el `Part` con `protocol == 'hls'` y devuelve `url == 'https://vod.provider.plex.tv<key>?X-Plex-Token=<token>'` con `headers == {'X-Plex-Token': token}`; sin `Media` HLS → `OnDemandUnavailableException`.
  - `resolve()`: sesión nueva (no la del catálogo) → `GET /library/metadata/<ratingKey>` → `pickPlexStream`; id inválido o título que no es `PlexSource` → `ArgumentError`; 2 resolves → 2 sesiones.
  - Errores de red/HTTP/JSON roto → `OnDemandUnavailableException`; no se cachean.

- [ ] **Step 2: Run** `flutter test test/backend/ondemand/plex_vod_provider_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** el proveedor; los estantes se piden en paralelo con `Future.wait` (límite: los 12 de `/hubs/promoted`); timeouts 20 s; parse por defecto con `compute`. `X-Plex-Client-Identifier` generado con `Random.secure()` (mismo UUID v4 de `PlutoVodProvider`; extraerlo a una función compartida `newUuidV4()` en `lib/backend/ondemand/uuid.dart` y que ambos la usen, con un test).

- [ ] **Step 4: Run** `flutter test test/backend/ondemand` — Expected: PASS.

- [ ] **Step 5: Probar contra Plex real** (test efímero): `titles()` devuelve entre 150 y 600 películas, sin `show`, y `resolve` del primero da una URL cuyo maestro responde 200 y cuya primera lista de variantes también.

- [ ] **Step 6: Commit** `feat(ondemand): proveedor de Plex`.

---

### Task 5: Activar los servicios y probar en la TV

**Files:**
- Modify: `lib/backend/ondemand/on_demand_registry.dart`
- Test: `test/screens/tv/tv_ondemand_test.dart` (actualizar)

**Interfaces:**
- Consumes: `PlexVodProvider`, `ArchiveVodProvider`.
- Produces: `kOnDemandEnabledServices = {'cineaparte', 'pluto', 'plex', 'archive'}`; en el registro Plex e Internet Archive con su proveedor. YouTube sigue sin proveedor y «Próximamente».

- [ ] **Step 1: Write the failing tests**: servicios habilitados `['cineaparte','pluto','plex','archive']`; «Próximamente» solo en YouTube (1 tarjeta); OK en Plex y en Internet Archive abre `TvCatalogScreen` (con proveedor falso inyectado vía `services:`).

- [ ] **Step 2: Run** `flutter test test/screens/tv/tv_ondemand_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** el registro.

- [ ] **Step 4: Run** `flutter test` completo y `flutter analyze lib test` — Expected: todo PASS, sin avisos nuevos en archivos de on demand.

- [ ] **Step 5: Commit** `feat(ondemand): Internet Archive y Plex conectados a la TV`.

- [ ] **Step 6: Prueba en la TV real** (receta de `fred-tv-build-and-tv-testing`; TV en `192.168.1.60:5555`): para cada servicio, abrirlo, comprobar categorías y carteles, ver una película (imagen y audio con `dumpsys audio`), pausa, saltos y Atrás sin audio residual. En Internet Archive revisar con capturas que no salgan títulos para adultos entre los primeros carteles. Anotar tiempos de carga.

---

## Self-review

- Cobertura del diseño: Plex (T3–T4), Archive (T1–T2), registro (T5), pruebas en TV (T5), filtro de adultos (T1), validación de ids (T2, T4). YouTube queda fuera por decisión (espera canales).
- Cambios respecto al diseño (míos): el filtro de adultos es nuevo (el Archive no está moderado y su lista por descargas incluye títulos explícitos); `newUuidV4()` se extrae a un archivo compartido.
- Nombres consistentes: `ArchiveSource`, `PlexSource`, `parseArchiveSearch`, `parsePlexHubs`, `pickArchiveStream`, `pickPlexStream`, `ArchiveVodProvider`, `PlexVodProvider`, `kOnDemandEnabledServices`.
