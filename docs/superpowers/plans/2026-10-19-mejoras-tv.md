# Mejoras de la app de TV — plan de implementación

> Ejecutar con superpowers:executing-plans (TDD, commits locales, **nunca `git push`**).

**Objetivo:** las 10 mejoras acordadas tras la guía de TV Perú: Recientes, estado de canales, país, zapping rápido, control parental, respaldo, guía XMLTV, pistas de audio en ExoPlayer, integración Android TV y accesibilidad.

**Restricciones globales**
- Sin dependencias **pub** nuevas (se puede subir la versión de `video_player` que ya existe). Dependencias nativas de Gradle solo si son imprescindibles y quedan anotadas.
- Migraciones SQL numeradas a continuación de la 4 (`db_factory.dart`).
- La UI de TV vive en `lib/screens/tv/`; textos en español; teclas con `TvFocusable`.
- Cada tarea: tests primero, `flutter analyze` sin errores nuevos, commit local con `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Compilación limpia (receta en memoria) antes de instalar en la TV; instalar con `adb install -r`, jamás borrar datos.

## Decisiones (rulings)
- **Recientes**: grupo virtual al inicio de la lista de grupos de *Canales* (usa `ViewType.history`, ya guardado en `last_watched`, máx. 36).
- **Estado de canales**: tabla `channel_health(source_id, name, failed_at, manual)`; un canal cuenta como caído 7 días. Sin "reporte" externo: se puede marcar/quitar a mano y ajustar si se ocultan.
- **País**: columna `tvg_id` y país derivado del sufijo (`Nombre.pe@SD` → `pe`). Idioma: ya se cubre al añadir listas por idioma desde iptv-org; no hay dato de idioma por canal.
- **Respaldo**: sin QR (exigiría una dependencia); archivo JSON + importación desde archivo o URL.
- **Guía**: proveedor XMLTV genérico (URLs configurables, por defecto `epg_ripper_PE1` de epgshare01) cruzado por nombre normalizado; TV Perú sigue con su proveedor propio.
- **Audio ExoPlayer**: subir `video_player` para tener `getAudioTracks/selectAudioTrack`; subtítulos de Exo quedan fuera (solo mpv).
- **Android TV**: fila "Seguir viendo" (Watch Next) vía `androidx.tvprovider` + manejo del intent `SEARCH` para abrir la búsqueda. La búsqueda por voz del launcher completa (proveedor de sugerencias) queda fuera.

## Tareas

### Task 1 — Accesibilidad: tamaño de letra y alto contraste
Archivos: `tv_theme.dart`, `tv_data.dart`, `tv_settings.dart`, `main.dart`. Ajustes `tvTextScale` (100/115/130 %) y `tvHighContrast`. `TvTheme` lee la escala; fila nueva en Ajustes que alterna.
Tests: escala persistida/rotada, `TvTheme.scaled(x)`.

### Task 2 — Recientes + volver al último canal
Grupo virtual "Recientes" en `tv_channel_browser`; `TvData.lastWatched()`. Tests de listado y de orden.

### Task 3 — Zapping rápido (números y canal anterior)
`tv_player_keys.dart`: dígitos 0‑9 → `TvPlayerCommand.digit`; `TvChannelNumberBuffer` (1,5 s) pura y testeada; tecla "anterior" (`LogicalKeyboardKey.mediaLast`, `backspace` y `0` largo no; ver código) vuelve al canal anterior con `TvPlaylistCursor.previousVisited`.

### Task 4 — Estado de canales
Migración 5 `channel_health`; `ChannelHealthSql`; el reproductor marca caído al agotar los intentos y limpia al reproducir; `TvPlaylistCursor` salta caídos; `Filters.hideDead` y marca visual; opciones del menú "Marcar como caído / Quitar marca"; Ajustes: "Ocultar canales caídos" y "Limpiar marcas".

### Task 5 — Filtro por país (tvg-id)
Migración 6 `channels.tvg_id`; `m3u.dart` guarda el id; `Filters.country`; `TvData.countries()`; selector de país en Búsqueda.

### Task 6 — Control parental
PIN (hash SHA‑256 con sal en `settings`), `Filters.hideAdult` (grupos `XXX`, `Adult`, `Adultos`, `+18`, `NSFW`), pantalla en Ajustes con teclado numérico en pantalla; el PIN protege desactivar el filtro y cambiar el PIN.

### Task 7 — Respaldo y restauración
`BackupService` (JSON: favoritos, listas propias, ajustes, canales manuales); exportar a archivo; importar desde archivo (`file_picker`) o URL. Tests de ida y vuelta con datos falsos.

### Task 8 — Guía XMLTV
`XmltvGuide implements GuideProvider`: parser (`<channel>`, `<programme>`, `+0000`), caché, coincidencia por nombre normalizado y por `tvg_id`; URLs configurables en Ajustes. Tests con XML real recortado.

### Task 9 — ExoPlayer: pista de audio
Subir `video_player`; `ExoEngine.audioTracks/selectAudio`; `supportsTracks` pasa a verdadero solo para audio; menú de opciones. mpv: medir tirones (`frame-drop-count`) y, si aporta, probar `hwdec=mediacodec` como ajuste.

### Task 10 — Integración Android TV
Gradle `androidx.tvprovider`; `MainActivity` expone `MethodChannel` para publicar "Seguir viendo"; intent `SEARCH` abre Buscar con la consulta. Verificación por ADB.

## Cierre
`flutter test`, `flutter analyze`, compilación limpia, instalación en la TV y checklist manual.
