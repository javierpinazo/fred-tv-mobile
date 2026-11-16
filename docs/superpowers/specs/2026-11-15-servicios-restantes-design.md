# On demand: Internet Archive, Plex y YouTube — Diseño

Fecha: 2026-11-15 · Continúa `2026-11-15-pluto-vod-design.md` (Pluto ya funciona
en la TV real) y `2026-11-14-on-demand-design.md`.

## Para qué

El usuario pidió completar **todos** los servicios del menú «On demand», no solo
Pluto. Quedan tres tarjetas «Próximamente»: Plex, Internet Archive y YouTube
(películas). Todos usan lo ya construido: `OnDemandProvider`/`OnDemandResolver`,
`TvCatalogScreen` (cuadrícula + columna de categorías + ficha) y `TvVodPlayer`
(ExoPlayer, probado en la TV real con Pluto el 2026-11-15).

## Hallazgos (sondeo 2026-11-15, desde Perú, sin cuenta)

- **Plex** (corrige lo dicho antes: el catálogo no está vacío): sesión anónima
  `POST https://clients.plex.tv/api/v2/users/anonymous` (cabeceras
  `X-Plex-Client-Identifier` aleatorio, `X-Plex-Product`, `X-Plex-Version`,
  `X-Plex-Platform`) → `authToken`. Estantes: `GET https://vod.provider.plex.tv/hubs/promoted`
  (12, con título y `key`, p. ej. «En Español», «Most Popular in Peru»); cada
  estante se pide por su `key` + `?count=N` → `Metadata[]` (movie/show;
  «En Español» trae 99). Ficha: `GET /library/metadata/<ratingKey>` →
  `Media[].Part[].key` con `protocol: hls` (`/library/parts/<id>-hls.m3u8`), sin
  DRM; se sirve con `?X-Plex-Token=<token>`; las listas de variantes responden
  200.
- **Internet Archive**: `GET https://archive.org/advancedsearch.php?q=mediatype:movies AND collection:feature_films AND language:(spanish OR Spanish OR spa)&fl[]=identifier,title,year,description,subject&rows=…&output=json`
  → 1.414 largometrajes. Archivos: `GET https://archive.org/metadata/<id>` →
  `files[]` con `.mp4`; descarga directa `https://archive.org/download/<id>/<archivo>`,
  sin cabeceras. Cartel: `https://archive.org/services/img/<id>`.
- **YouTube**: el canal oficial «YouTube Movies» responde «Las películas no están
  disponibles» desde Perú; no hay catálogo oficial accesible. Solo se pueden
  usar **canales concretos** de películas completas subidas por quien tiene los
  derechos (la app ya sabe leer canales de YouTube: `lib/backend/youtube/`).

## Qué ve el usuario

Igual que Pluto: tarjeta del servicio → catálogo con columna de categorías →
ficha con «Ver» → reproductor. Las tres tarjetas dejan de decir «Próximamente».

| Servicio | Categorías | Reproducción |
|---|---|---|
| Plex | los estantes de Plex (p. ej. «En Español») | `TvVodPlayer` con el HLS de Plex |
| Internet Archive | década (1950s, 1960s…; «Sin fecha») | `TvVodPlayer` con el MP4 |
| YouTube | el nombre del canal | reproductor de YouTube que ya existe |

## Metas

- `PlexVodProvider`, `ArchiveVodProvider` y `YoutubeMoviesProvider`, cada uno
  con su parser puro, probado como Pluto, y su resolución al pulsar «Ver».
- Activar las tres tarjetas en el registro.
- Probar cada servicio en la TV real (catálogo, una película, audio, Atrás).

## No metas

- Series, temporadas, audio/subtítulos, favoritos, búsqueda, «seguir viendo».
- Subtítulos de Plex (la lista los declara; no se ofrece elegirlos).
- Un catálogo propio de YouTube: solo los canales que se acuerden.

## Anti-metas

- Presentar como película algo que no lo es: YouTube solo muestra vídeos de
  **60 min o más** de los canales elegidos; Plex solo `type == 'movie'`.
- Ofrecer contenido sin derechos en YouTube: **solo canales que el usuario
  confirme**; la app no busca películas por su cuenta.
- Dejar el token de Plex caducado o compartido: se pide sesión nueva en cada
  «Ver», igual que Pluto.

## Enfoques considerados

1. **Un proveedor por servicio, mismo patrón (elegido).** Cada uno implementa
   `OnDemandProvider` (+ `OnDemandResolver` si resuelve la URL al ver).
2. Un proveedor «mega» que mezcla los cuatro catálogos: una sola lista enorme y
   sin forma de distinguir el origen; peor para el mando y para los fallos.
3. Abrir los tres en WebView: sin código nativo, pero mala experiencia con mando
   y sin control de errores.

## Diseño

**Modelos** (`on_demand_provider.dart`): nuevas fuentes `PlexSource(ratingKey)`,
`ArchiveSource(identifier)` y reutilizar `YoutubeSource` para YouTube.

**Plex** — `plex_vod_parser.dart`: `parsePlexHub(String json, String hubTitle)` y
`parsePlexVodCatalog(...)`: solo películas, sin duplicados, con todas sus
estantes como categorías; ficha «año · clasificación · NN min.». `PlexVodProvider`:
sesión anónima (cliente aleatorio), `titles()` baja los estantes de
`/hubs/promoted` (en paralelo, `count=100`), parsea fuera del hilo de la interfaz
y cachea 30 min; `resolve()` pide sesión nueva, `GET /library/metadata/<ratingKey>`
y devuelve `OnDemandStream(url: vod + partKey + ?X-Plex-Token=…, headers: {X-Plex-Token})`
con el `Part` de `protocol == hls`. `ratingKey` validado con `^[A-Za-z0-9_-]{1,64}$`.

**Internet Archive** — `archive_vod_parser.dart`: `parseArchiveSearch(String json)`
(título, descripción recortada, año, cartel `services/img`, categoría por década);
`ArchiveVodProvider.titles()` pide una página grande (rows 2000, ordenada por
descargas) y cachea 30 min; `resolve()` pide `metadata/<id>` y elige el mejor
`.mp4` (preferencia: formato `h.264`, luego `MPEG4`, luego `512Kb MPEG4`; el
mayor tamaño dentro de lo razonable), URL `https://archive.org/download/<id>/<nombre codificado>`.
Identificador validado con `^[A-Za-z0-9._-]{1,128}$`.

**YouTube** — `YoutubeMoviesProvider` recibe una lista de canales
(`{name, url}`, constante `defaultYoutubeMovieChannels`, **a rellenar con los
canales que confirme el usuario**), lee sus vídeos con el servicio de canales
existente y deja los de **≥ 60 min**; categoría = nombre del canal; reproduce con
`TvYoutubePlayer` y el canal sintético «YouTube películas» (como Cineaparte).

**Registro** (`on_demand_registry.dart`): los tres proveedores; `kOnDemandEnabledServices`
pasa a contener `'plex'`, `'archive'`, `'youtube-movies'`. Sin cambios en las pantallas.

## Pruebas

Parser de cada servicio con JSON de muestra (películas/series, duplicados,
incompletos, JSON roto, vacío). Proveedores con `MockClient`: sesión, catálogo,
caché, `resolve` con sesión nueva, errores HTTP/red, ids peligrosos. YouTube:
filtro de duración y asignación de categorías con un servicio de canales falso.
Después, TV real: abrir cada servicio, ver una película con audio, saltar, Atrás.

## Lo que queda al implementador

- Qué estantes de Plex entran (propuesta: todos los de `/hubs/promoted`).
- Tope de títulos por estante y de la página de Internet Archive.
- Cómo se resumen las descripciones largas del Archive (propuesta: 400 caracteres).

## Notas mías (no acordadas)

- Plex pasa de «no viable» a viable: el primer sondeo leyó estantes vacíos
  («placeholder») sin pedir sus `key`. Lo corrijo aquí.
- Las categorías del Archive son décadas porque sus etiquetas (`subject`) son
  libres y desordenadas.
- El orden de entrega propuesto: Internet Archive → Plex → YouTube (este último
  espera los canales).
