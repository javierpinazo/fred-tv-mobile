# On demand (películas gratuitas) — Diseño

Fecha: 2026-11-14 · Rama: `feat/estabilidad-rendimiento-diseno` (o la que se cree
para esto) · Aplaza y reemplaza la nota «On demand de Pluto TV (futuro)».

## Para qué

El usuario quiere una sola app con varios servicios de películas legales y
gratuitas, además de los canales en vivo. Pidió una **pantalla aparte** en el
menú lateral de la TV, **debajo de Favoritos**, llamada «On demand», que
muestre los servicios a los que puede acceder. Primer servicio: **Cineaparte**
(cine peruano y latinoamericano), cuyas películas gratuitas se reproducen con
Vimeo y YouTube. Vendrán más (Pluto, Plex, Internet Archive, películas
oficiales de YouTube).

## Qué ve el usuario

```
 ☰ Canales        On demand
 ★ Favoritos      ┌──────────┐ ┌──────────┐ ┌──────────┐
 ▶ On demand  ←   │Cineaparte│ │  Pluto   │ │  Plex    │   (tarjetas de servicio)
 ≡ Mis listas     │ próximam.│ │ próximam.│ │ próximam.│
 ⌕ Buscar         └──────────┘ └──────────┘ └──────────┘
 ⚙ Ajustes
```

- Entrada nueva «On demand» en el menú lateral, justo debajo de Favoritos.
- La pantalla lista los servicios como tarjetas (misma estética y foco que la
  grilla de canales).
- **Decisión del usuario:** el reproductor de Vimeo y Cineaparte quedan
  programados y probados por dentro, pero **no se conectan a la pantalla de la
  TV todavía**. Por eso, en esta entrega todas las tarjetas, Cineaparte
  incluida, salen como «Próximamente» y no abren nada.

## Metas

- Menú «On demand» y pantalla de servicios en la TV, con foco y mando
  funcionando.
- Interfaz común de proveedor, para que añadir un servicio no toque la
  pantalla.
- Proveedor Cineaparte completo: leer catálogo, filtrar gratuitas, resolver la
  reproducción.
- Reproductor de Vimeo (página HTML + WebView) listo para usarse.

## No metas

- No se conecta Cineaparte a la pantalla ni se instala/prueba en la TV.
- No se implementan Pluto, Plex, Internet Archive ni YouTube películas.
- No se tocan las 122 películas de pago o con registro de Cineaparte.
- Sin cuentas, favoritos ni «seguir viendo» de películas en esta entrega.

## Anti-metas (sería un fracaso aunque compile)

- Mostrar un botón que parece funcionar y no hace nada sin decirlo (por eso
  «Próximamente» visible).
- Que el menú nuevo rompa el foco del mando en las pestañas existentes.
- Ofrecer películas de pago o con restricción de territorio como si fueran
  gratis.

## Hallazgos que condicionan el diseño

Sondeo hecho el 2026-11-14 sobre `https://www.cineaparte.com`:

- No hay API pública. **Todo el catálogo viene incrustado en la portada** como
  matrices JavaScript (`aTodoTitulo`, `aTodoSlug`, `aTodoAccesoVOD`,
  `aTodoVideoEmbedURL`, `aTodoAficheURL`, `aTodoDisponible`, …), 203 títulos.
- `aTodoAccesoVOD` = 1 en 81 títulos: 35 con `player.vimeo.com/video/<id>`, 40 con
  `youtube.com/embed/<id>`, 5 con `cineaparte.com/d/embed/<id>/<n>` y 1 sin
  reproductor. Las 122 con 0 abren la ficha de pago o registro.
- `/d/embed/…` de Cineaparte pide inicio de sesión: **no se usa**.
- `aTodoDisponible` indica territorio («Disponible en PE», «todo el mundo
  excepto ES»…); la mayoría viene vacío.
- Riesgo: es scraping de HTML; si la web cambia, el parser falla. Debe fallar
  con un error claro, no con una pantalla vacía.

## Enfoques considerados

1. **Proveedor genérico (elegido por el usuario).** `OnDemandProvider` con una
   implementación por servicio; la pantalla no sabe nada de cada servicio.
2. Cineaparte directo, sin interfaz común: más rápido hoy, se reescribe al
   llegar el segundo servicio.
3. Navegador embebido de la web de Cineaparte: casi sin código, pero el mando
   funciona mal con una web hecha para ratón y no hay diseño propio.

## Diseño

Parecido al de YouTube (`lib/backend/youtube/`, `lib/screens/tv/youtube/`).

**Backend** — `lib/backend/ondemand/`
- `on_demand_provider.dart`: interfaz `OnDemandProvider` (`id`, `name`,
  `Future<List<OnDemandTitle>> titles()`), modelo `OnDemandTitle` (id, título,
  sinopsis, cartel, año/duración si hay, `OnDemandSource`) y
  `OnDemandSource` sellada: `VimeoSource(videoId)` | `YoutubeSource(videoId)`.
- `cineaparte_page_parser.dart`: función pura que recibe el HTML de la portada
  y devuelve la lista de títulos gratuitos (`aTodoAccesoVOD == 1` con embed de
  Vimeo o YouTube). Ignora `/d/embed/` y los que no tienen reproductor.
  Excluye los no disponibles en Perú si `aTodoDisponible` lo indica.
- `cineaparte_provider.dart`: descarga la portada con `http` (ya en el
  proyecto), llama al parser, cache en memoria con caducidad (30 min).
- `on_demand_registry.dart`: lista de servicios para la pantalla; Cineaparte
  figura con `enabled: false` mediante una constante
  `kOnDemandCineaparteEnabled = false`, y Pluto/Plex/etc. como entradas sin
  proveedor (solo «Próximamente»).

**Reproductor de Vimeo** — `lib/screens/tv/ondemand/vimeo_player_page.dart`
- `vimeoPlayerHtml(String videoId)`: HTML con el reproductor oficial de Vimeo
  (`player.vimeo.com` + `Player SDK`) a pantalla completa, con `autoplay`, sin
  controles propios, y canal JS hacia la app para estado/posición/fin, igual
  que `youtubePlayerHtml`. Valida el id (solo dígitos); lanza `ArgumentError`
  si no.
- Un widget de reproducción con WebView que lo carga, y mando: OK
  pausa/reanuda, ←/→ salta ±10 s, Atrás cierra. Reutiliza `tv_focusable` y el
  patrón de `tv_youtube_player.dart`. **Sin ruta que lo abra aún.**

**Pantalla y menú**
- `lib/screens/tv/tv_ondemand.dart`: pantalla de tarjetas de servicio.
- `tv_home.dart`: nueva pestaña en `_tabIcons` y `_tabLabels` entre Favoritos
  y Mis listas; los índices fijos hoy en el archivo (`index == 1` favoritos,
  `3` búsqueda) se ajustan.
- Textos nuevos en los ARB de los 6 idiomas: «On demand», «Próximamente»;
  los nombres de servicios no se traducen.

## Pruebas

- Parser: HTML de muestra (fixture recortado de la portada) → lista esperada;
  casos: Vimeo, YouTube, `/d/embed/`, sin embed, territorio excluido, HTML sin
  matrices (error claro).
- `vimeoPlayerHtml`: id válido produce HTML con el id; id inválido lanza.
- Widget: el menú tiene «On demand» tras Favoritos; la pantalla muestra las
  tarjetas y ninguna abre algo.
- Navegación: los saltos de foco existentes siguen funcionando (test de
  `tv_home` actualizado por el cambio de índices).
- No se prueba en la TV real (decisión del usuario).

## Lo que queda al implementador

- Nombres exactos de archivos y colores de tarjeta, siguiendo `tv_theme`.
- Cómo mostrar cada tarjeta (logo/icono) mientras no haya imágenes: icono y
  nombre. **Mi decisión**, a corregir si prefieres otra cosa.
- Duración de la caché (propuesta: 30 min).
- Si el estado del menú recuerda la última pestaña: se mantiene lo que ya hace
  la app.

## Notas de mi parte (mis decisiones, no acordadas)

- Mostrar Cineaparte como «Próximamente» en vez de ocultarlo: así se ve el menú
  completo sin prometer algo que no abre. Es un cambio de una constante el día
  que se conecte.
- Incluir películas de YouTube dentro del parser de Cineaparte (40 títulos):
  se reproducen con el reproductor de YouTube que ya existe.
