# Canales de YouTube en la TV — diseño

Fecha: 2026-11-10 · Estado: pendiente de aprobación del usuario

## Intención

El usuario sigue varios canales peruanos de YouTube y quiere verlos desde la
misma app de IPTV, sin cambiar de aplicación: entrar a un canal, ver sus
últimos programas del más reciente al más antiguo y, si está emitiendo, ver el
directo como primera opción.

## Lo que decidió el usuario

- Cada canal de YouTube aparece **como un canal más** de la app.
- Al abrirlo se muestra la **lista de sus últimos programas**, del más reciente
  al más antiguo.
- Si hay un **directo en curso, va primero** en la lista.
- Se reproduce **dentro de la app** con el reproductor oficial de YouTube
  incrustado («camino 1»). Probó también abrir la app de YouTube de la tele
  («camino 2») y lo descartó como vía principal: volver exige cuatro Atrás.
- La lista de programas se ve como **mosaico de miniaturas** (4 columnas,
  título a dos líneas), no como filas.
- Canales iniciales: La Encerrona, La República, Curwen, Paolo Benza y Carlos
  León Moya. Más adelante podría añadir otros.

## Objetivos

1. Los cinco canales disponibles en la app tras actualizar, sin configurar nada.
2. Lista de programas actualizada sola cada vez que se entra al canal.
3. Reproducción de grabados y directos en alta calidad, manejada con el mando.
4. Volver del reproductor a la lista con un solo Atrás.

## Fuera de alcance

- Iniciar sesión en YouTube (no retoma la posición ni aplica Premium).
- Shorts, playlists de YouTube, búsqueda, comentarios, chat del directo.
- Una pantalla específica para «añadir canal de YouTube» (ver «Canales
  futuros»: ya sirve la opción existente de añadir canal por URL).
- Reproducir YouTube con ExoPlayer o mpv.
- Guía de programación, cámara en recuadro y menú de opciones del reproductor
  normal para estos canales.

## Lo que haría que esto fracase aunque «funcione»

- Obtener vídeo haciéndose pasar por las apps oficiales de YouTube o
  extrayendo los flujos directamente. Se probó: solo da 360p de forma limpia,
  es frágil y quedó bloqueado por una regla de seguridad. **No usarlo.**
- Que un canal de YouTube rompa el zapping, los favoritos, la fila de inicio
  o la copia de seguridad de los canales normales.
- Que un fallo al leer YouTube deje una pantalla vacía sin explicación.

## Hallazgos de la investigación (2026-11-10, desde Perú)

Canales reales (el buscador devuelve cuentas vacías con nombres parecidos):

| Canal | Nombre en YouTube | Id | Handle |
|---|---|---|---|
| La Encerrona | Marco Sifuentes | `UCP0AJJeNkFBYzegTTVbKhPg` | `@canalYAAAAA` |
| La República | La República - LR+ | `UC-B7Xv56uNRDkj0vC3QW8Cg` | `@larepublica` |
| Curwen | El diario de Curwen | `UCHUD6A_lv3OXbzgVXwomtkw` | `@curwen` |
| Paolo Benza | Paolo Benza | `UCIpXj6C68YhT8Px3DGCafYA` | `@PaoloBenzaR` |
| Carlos León Moya | Carlos Leon Moya | `UCw2gXKyj0RcW2qcohj7Gqtg` | `@leonmoya` |

Lista de programas:

- El feed RSS (`/feeds/videos.xml?channel_id=…`) devuelve **404**: no sirve.
- El paquete `youtube_explode_dart` 3.1.0 falla o devuelve títulos vacíos al
  listar: YouTube cambió el formato de la página. **No usarlo.**
- Funciona leer la página pública: `https://www.youtube.com/channel/<id>/videos`
  y `…/streams` (GET con un User-Agent de navegador de escritorio y cookie
  `SOCS=CAI`). El HTML trae `var ytInitialData = {…};` con 30 elementos
  `lockupViewModel` por pestaña, en unos 0,5 s (alguna vez 8–15 s) y ~1 MB.
  De cada uno se saca:
  - `contentId` → id del vídeo;
  - `metadata.lockupMetadataViewModel.title.content` → título;
  - `…metadata…metadataParts[].text.content` → vistas y antigüedad
    («hace 16 h», «Transmitido hace 1 día», «Programado para el 11/11/26, 9:30»);
  - `contentImage…thumbnailBadgeViewModel.text` → duración («22:45») o
    «Próximamente» en los programados.
  - Miniatura: `https://i.ytimg.com/vi/<id>/mqdefault.jpg`.
- **Sin comprobar:** cómo aparece un directo *en curso* en `/streams` (ninguno
  de los cinco emitía). Se espera una insignia tipo «EN VIVO» con un
  `badgeStyle` propio y sin duración. Hay que verificarlo con un canal en
  directo al construir (La República emite a diario por la mañana).

Reproducción (prueba desechable instalada en la tele Hisense, WebView 156,
Android 12):

- Reproductor IFrame oficial (`https://www.youtube.com/iframe_api`) en una
  WebView de `webview_flutter` 4.13.1 (compatible con Flutter 3.32 / Dart 3.8).
- Arranca solo (hay que desactivar el requisito de gesto para reproducir) y
  alcanza `hd1080` en grabados, directos y directos ya emitidos.
- Pausa/reanudar y saltos por JavaScript (`playVideo`, `pauseVideo`, `seekTo`)
  desde las teclas del mando capturadas en Flutter: funcionan.
- La página se cargó con `loadHtmlString` y una `baseUrl` https (el reproductor
  exige un origen/Referer válido).
- No apareció publicidad de YouTube en tres vídeos (muestra pequeña).
- **Pendiente:** en la captura del directo la imagen parecía recortada por
  abajo; revisar el ajuste de tamaño de la página/viewport.

## Diseño

### Qué es un «canal de YouTube» en la app

Un canal manual normal (fuente `Custom Channels`, grupo «Mis canales»,
`MediaType.livestream`) cuya dirección es la de un canal de YouTube:
`https://www.youtube.com/channel/UC…` o `https://www.youtube.com/@handle`.
No hay tabla ni migración nuevas. Así hereda favoritos, listas propias, fila
de inicio de Android TV, búsqueda y copia de seguridad.

Una función pura reconoce esas direcciones (y nada más: un enlace a un vídeo
suelto no es un canal).

### Los cinco canales iniciales

En el arranque, una sola vez (marcada con un ajuste para que no reaparezcan si
el usuario los borra), se crean los cinco canales y una lista propia
**«YouTube»** que los contiene, en el orden de la tabla. Vale tanto para
instalaciones nuevas como para la tele del usuario, que ya tiene datos. No se
marcan como favoritos: eso lo decide el usuario. *(Decisión mía.)*

Nombres visibles: «La Encerrona», «La República», «Curwen», «Paolo Benza»,
«Carlos León Moya». Imagen del canal: la que el constructor considere viable
(avatar de YouTube o ninguna).

### Abrir un canal

`openTvPlayer` es el único punto por el que hoy se abre un canal (Canales,
Favoritos, Búsqueda, listas propias, enlaces `fredtv://play`). Si el canal
elegido es de YouTube, en lugar del reproductor normal se abre la **pantalla
de programas**. El valor devuelto (índice para recuperar el foco) se mantiene.

Zapping: al cambiar de canal dentro del reproductor normal, los canales de
YouTube **se saltan**. *(Decisión mía.)*

### Pantalla de programas

- Cabecera con el nombre del canal.
- Mosaico de 4 columnas con el estilo de `TvTheme`: miniatura 16:9, duración
  abajo a la derecha, título a dos líneas, antigüedad debajo.
- Orden:
  1. directos en curso, con insignia roja «EN VIVO»;
  2. vídeos subidos y directos ya emitidos mezclados, del más reciente al más
     antiguo.
- Los directos **programados** («Próximamente») no se muestran. *(Decisión mía:
  La República programa varios al día y taparían la parte alta de la lista.)*
- Se carga al entrar, con indicador de carga. Foco inicial en el primer
  elemento. OK reproduce; Atrás vuelve a donde se estaba.
- Sin paginación: los ~30 + ~30 más recientes bastan.
- Si falla la carga: mensaje claro y botón «Reintentar». Si el canal no tiene
  programas: mensaje de lista vacía.

Mezcla por fecha: YouTube solo da antigüedades relativas. Se piden las páginas
en un idioma fijo (inglés, con `hl=en` / `Accept-Language`) para interpretarlas
de forma estable, se convierten en una antigüedad aproximada y se mezclan las
dos pestañas con un orden estable (a igual antigüedad se respeta el orden de
YouTube). La antigüedad se muestra en el idioma de la app con textos propios
(«hace 3 h», «hace 2 días»…), en los 6 idiomas. *(Decisión mía.)*

### Reproductor de YouTube

Pantalla propia, a pantalla completa, con la WebView y el reproductor IFrame
oficial sin sus controles táctiles.

- OK / Play-Pause: pausa y reanuda.
- Izquierda / derecha: salta 30 s atrás / adelante (en directo, solo dentro
  de lo que YouTube permita).
- Atrás: cierra y vuelve a la lista, con el foco en el programa que se veía.
- Al terminar un vídeo: vuelve a la lista. *(Decisión mía; sin reproducción
  automática del siguiente.)*
- Una barra propia y breve muestra título y estado (pausa, salto, posición)
  al pulsar una tecla, coherente con el reproductor normal.
- La pantalla no se apaga mientras se reproduce (`wakelock_plus`, ya en el
  proyecto).
- Errores del reproductor (vídeo no incrustable, no disponible, sin red):
  mensaje claro con dos opciones, «Abrir en YouTube» (lanza la app de YouTube
  de la tele con ese vídeo; es el «camino 2» ya probado) y «Volver».
  *(Decisión mía.)*

### Canales futuros

No se construye nada específico. Como un canal de YouTube es un canal manual
con dirección de YouTube, el usuario puede añadir otros con la opción que ya
existe en las listas propias («Agregar canal por URL»), escribiendo la
dirección del canal. Requisito: que esa vía funcione de verdad con
`youtube.com/@handle` y `youtube.com/channel/UC…`.

## Restricciones

- Flutter 3.32.4 / Dart 3.8: no subir de versión. `webview_flutter` 4.13.x
  resuelve con estas versiones.
- Interfaz en 6 idiomas (ARB + gen-l10n): todo texto nuevo va localizado.
- Navegación solo con mando; foco visible según `TvTheme`.
- Tests: el análisis de la página de YouTube se prueba con HTML guardado
  (casos: vídeos, directos emitidos, programados, canal vacío, formato
  inesperado). La mezcla/orden y el reconocimiento de direcciones, con tests
  unitarios. Las pantallas, con tests de widgets como el resto de la TV
  (foco por teclas, no `tap`).
- No borrar datos de la app en la tele; instalar con `adb install -r`.

## Riesgos aceptados

- La lista depende de la página pública de YouTube, no de un servicio oficial.
  Si cambia, la lista deja de cargar hasta ajustarla; la reproducción no se ve
  afectada. El usuario lo sabe.
- Puede aparecer publicidad de YouTube.
- Algún vídeo puede no permitir reproducción incrustada: para eso está
  «Abrir en YouTube».

## Queda a criterio del constructor

- Estructura de archivos y nombres (seguir lo que ya hay en `lib/screens/tv`
  y `lib/backend`).
- Caché breve de la lista para no recargar al volver del reproductor.
- Origen (`baseUrl`) exacto de la página del reproductor.
- Imagen de cada canal.
- Textos exactos y sus traducciones.

## Comprobación final en la tele

1. Tras actualizar aparece la lista «YouTube» con los cinco canales.
2. Cada canal muestra sus programas recientes en mosaico, ordenados.
3. Con un canal emitiendo, el directo aparece primero con «EN VIVO» y se ve.
4. Un grabado se reproduce en alta calidad; OK pausa, flechas saltan, Atrás
   vuelve a la lista con un solo toque.
5. El zapping entre canales normales no se detiene en los de YouTube.
6. La imagen no sale recortada.
