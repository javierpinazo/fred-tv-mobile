# On demand: reproductor de películas y Pluto TV — Diseño

Fecha: 2026-11-15 · Continúa `2026-11-14-on-demand-design.md` · Reemplaza la nota
«On demand de Pluto TV (futuro)».

## Para qué

Segundo servicio del menú «On demand», después de Cineaparte: las películas
gratuitas (con anuncios) de Pluto TV. Decidido con el usuario el 2026-11-15:
**solo películas** en esta entrega (las series con temporadas quedan para
después, solo si esto funciona bien en la TV). Orden de los servicios:
Pluto → Internet Archive → YouTube (películas, con canales que dé el usuario);
Plex se deja en «Próximamente» (catálogo vacío desde Perú, probado 2026-11-15).

Pluto e Internet Archive entregan vídeo directo (HLS / MP4), no una página
web: hace falta un **reproductor nativo de películas**, que se construye aquí
y lo reutilizará Internet Archive.

## Qué ve el usuario

```
On demand → [Pluto TV] ─OK→  Pluto TV
                             ┌ Categorías ┐ [cartel][cartel][cartel][cartel]
                             │ Todas      │  Título  Título  Título  Título
                             │ Acción     │
                             │ Comedia …  │   (OK → ficha con «Ver» → reproductor)
```

- Pantalla de catálogo **genérica** (la de Cineaparte pasa a ser esta misma): si
  el servicio trae categorías, columna izquierda con «Todas» + categorías
  (como los grupos de canales); si no, solo la cuadrícula, como hoy.
- Ficha con «Ver» / «Volver», igual que Cineaparte.
- Reproductor de películas a pantalla completa: OK pausa/reanuda, ←/→ saltan
  10 s, Atrás sale; al pausar o saltar, barra mínima con posición/duración.

## Metas

- Reproductor nativo `TvVodPlayer` sobre `ExoEngine` (ya existente), con
  cabeceras HTTP, y mantiene la pantalla encendida.
- `PlutoVodProvider`: sesión anónima, catálogo de **películas** con categorías,
  URL de reproducción resuelta en el momento de ver.
- Catálogo genérico con categorías; Cineaparte sigue funcionando igual.
- Tarjeta de Pluto TV activa; Plex, Internet Archive y YouTube siguen
  «Próximamente».

## No metas

- Series, temporadas y capítulos de Pluto.
- Elegir audio o subtítulos; mpv de respaldo (solo ExoPlayer).
- Favoritos, «seguir viendo», búsqueda de películas, perfiles.
- Internet Archive, YouTube películas y Plex (entregas posteriores).

## Anti-metas

- Descargar los 7 MB del catálogo y procesarlos en el hilo de la interfaz
  (se nota como congelación en la TV): se procesa en un `Isolate`.
- Reproducir con un token caducado: el token (24 h, renovable a las 8 h) se
  pide siempre fresco al pulsar «Ver» y no se guarda en el catálogo.
- Mostrar como gratis algo que no se pueda reproducir: si la resolución falla,
  mensaje claro y «Reintentar», no pantalla negra.

## Hallazgos que condicionan el diseño (sondeo 2026-11-15, desde Perú, sin cuenta)

- Sesión: `GET https://boot.pluto.tv/v4/start?appName=web&appVersion=9.0.0&deviceVersion=120.0.0&deviceModel=web&deviceMake=chrome&deviceType=web&clientID=<uuid>&clientModelNumber=1.0.0&serverSideAds=false`
  → `sessionToken` (JWT), `stitcherParams`, `servers.{api,channels,vod,stitcher}`.
- Catálogo: `GET https://service-vod.clusters.pluto.tv/v4/vod/categories?includeItems=true&offset=1000&page=1`
  con `Authorization: Bearer <token>`: 150 categorías, 4.428 ítems (2.491
  `movie`, 1.937 `series`). Campos útiles: `_id`, `name`, `summary`,
  `description`, `rating`, `genre`, `covers`, `poster16_9`, `originalContentDuration`.
- Reproducción (nota 2026-11-10, **a re-comprobar**): `<servers.stitcher>/v2/stitch/hls/episode/<id>/master.m3u8?<stitcherParams>&jwt=<token>`
  (para películas el `<id>` es el `_id` del ítem; confirmar en la prueba). Las
  listas de variantes dan 401 sin cabecera `Authorization: Bearer <token>`; los
  segmentos no la piden. HLS con AES-128 estándar, audio en español, anuncios
  incrustados.
- API no oficial: puede cambiar; debe fallar con error claro.
- Internet Archive y Plex: ver sondeo en la conversación; no se tocan aquí.

## Enfoques considerados

1. **Reproductor nativo + proveedor genérico (elegido).** Reutiliza
   `ExoEngine`; Internet Archive entra después solo con su proveedor.
2. Abrir Pluto en un WebView de su web: sin código nativo, pero la web de Pluto
   no está pensada para mando y trae su propia interfaz y publicidad.
3. Convertir las películas en «canales» de la lista y usar `TvPlayer`: reutiliza
   mucho, pero mezcla ~2.500 películas con los canales en vivo y ese reproductor
   está pensado para directos (zapping, número de canal).

## Diseño

**Backend** — `lib/backend/ondemand/`
- `on_demand_provider.dart` (cambios): `OnDemandTitle` gana `categories`
  (`List<String>`, por defecto vacía); `OnDemandSource` gana `PlutoSource` (con
  el `_id` del ítem); `OnDemandProvider` gana
  `Future<OnDemandStream> resolve(OnDemandTitle title)` con una implementación
  por defecto que lanza `UnsupportedError` (Cineaparte no la usa);
  `OnDemandStream { String url; Map<String,String> headers; }`.
- `pluto_vod_parser.dart`: función pura que recibe el JSON del catálogo y
  devuelve las películas (sin series), una sola vez cada una aunque esté en
  varias categorías, con todas sus categorías; descarta ítems sin `_id` o sin
  nombre.
- `pluto_vod_provider.dart`: `titles()` pide sesión + catálogo y parsea en un
  `Isolate` (`compute`); caché de 30 min; `resolve()` pide una sesión fresca y
  arma la URL del maestro y las cabeceras (`Authorization: Bearer`). Errores de
  red/HTTP → `OnDemandUnavailableException`.
- `on_demand_registry.dart`: Pluto con `PlutoVodProvider`; la constante pasa a
  ser por servicio (`kOnDemandEnabled = {'cineaparte', 'pluto'}`).

**Pantallas** — `lib/screens/tv/ondemand/`
- `tv_cineaparte_screen.dart` → `tv_catalog_screen.dart` (`TvCatalogScreen`):
  añade columna de categorías cuando algún título las trae; sigue pasando por la
  ficha y por `playOnDemandTitle`.
- `on_demand_play.dart`: `playOnDemandTitle(context, provider, title)`; para
  `PlutoSource` llama a `provider.resolve` (con indicador de carga y error con
  «Reintentar») y abre `TvVodPlayer`.
- `tv_vod_player.dart`: `TvVodPlayer(url, headers, title)` sobre `ExoEngine`;
  teclas como los otros reproductores; `wakelock`; error → pantalla con
  «Volver» y «Reintentar».

## Pruebas

- Parser de Pluto con JSON de muestra: solo películas, sin duplicados, con
  varias categorías, ítems incompletos descartados, JSON sin categorías → error.
- Proveedor con `MockClient`: sesión + catálogo, caché, token en la URL de
  `resolve`, 401/500/red → excepción, y que `resolve` pide sesión nueva.
- Catálogo: columna de categorías filtra; sin categorías no se muestra.
- Reproductor con un `TvEngine` falso: teclas, pausa, fin, error y wakelock.
- En la TV real: abrir Pluto, ver una película y comprobar audio, saltos,
  pausa, anuncios y salida con Atrás.

## Lo que queda al implementador

- Qué imagen del ítem usar como cartel (`covers` vs `poster16_9`) tras mirar
  el JSON real: se prefiere la vertical.
- Cómo se muestra el nombre de categorías raras o repetidas (orden alfabético).
- Reintentos de red dentro de `resolve` (propuesta: ninguno; el usuario pulsa
  «Reintentar»).

## Notas mías (no acordadas)

- La constante de activación pasa a un conjunto por servicio para poder
  encender uno sin tocar los demás.
- Solo ExoPlayer: si en la TV se ve que falla el audio o el vídeo con el HLS de
  Pluto, se añade mpv de respaldo en una entrega aparte.
