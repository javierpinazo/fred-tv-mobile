# Fred TV - Guía de Android TV

Fred TV detecta automáticamente Android TV (modo televisión o `leanback`) y muestra una interfaz pensada para el control remoto. En teléfonos y tablets se usa la interfaz móvil original.

## Controles

### Navegación general
| Tecla | Acción |
|---|---|
| ↑ ↓ ← → | Mover el foco |
| OK | Seleccionar / reproducir |
| Mantener OK (o MENU / INFO) | Opciones del canal (favorito, agregar a una lista…) |
| ← en el borde izquierdo | Volver al menú lateral |
| → en el menú lateral | Entrar al contenido de la pestaña |
| Atrás | Contenido → menú lateral; menú lateral → salir de la app |

Pestañas del menú: **Canales**, **Favoritos**, **Mis listas**, **Buscar**, **Ajustes**.

### Escribir texto (búsqueda, nombres, URLs)
Al pulsar OK en un campo de texto se abre un **teclado propio** que se maneja con el D-pad: mueve el foco por las teclas y pulsa OK para escribir. Incluye números, `. - _ : / @`, **Mayús**, **Espacio**, **Borrar**, **Limpiar** y el botón principal (**Buscar**/**Listo**). Atrás cancela sin cambiar el texto. La tecla **Voz / sistema** abre el teclado de Android (voz, teclado físico o el de tu celular). La búsqueda se ejecuta al pulsar **Buscar**.

### Reproductor
| Tecla | En vivo | Película / VOD |
|---|---|---|
| ↑ / ↓ (o CH+ / CH−) | Canal anterior / siguiente | Muestra la información |
| ← / → | Muestra la información (no hace seek) | Retrocede / avanza 10 s |
| OK | Muestra u oculta la información | Pausa / reanuda |
| Mantener OK (o MENU / INFO) | Opciones: audio, subtítulos, ajustar imagen, favorito | igual |
| PLAY / PAUSE | Pausa / reanuda | igual |
| Atrás (o STOP) | Salir | Salir (guarda la posición) |

Si un canal no se puede reproducir, la pantalla muestra el error con **Reintentar**, **Siguiente canal** y **Volver**. La app prueba primero decodificación por hardware y, si no sale imagen en 15 s, por software; en directo reconecta sola hasta 3 veces.

## Funciones de la interfaz de TV

- **Recientes**: el grupo *Recientes* de *Canales* lista lo último que viste.
- **Zapping**: con un canal en directo, teclea su número (1,5 s o OK para confirmar) o usa la tecla *Último canal* / la opción "Volver al canal anterior" de Mantén OK. ↑↓ saltan los canales caídos.
- **Canales caídos**: tras dos fallos seguidos un canal se marca (7 días). Se puede marcar/quitar a mano desde Mantén OK, ocultar de Canales y Búsqueda y limpiar desde Ajustes.
- **País**: en *Buscar*, el selector *País* filtra por el país del `tvg-id` (`.pe`, `.us`…). Tras actualizar a esta versión las listas se recargan una vez para rellenarlo.
- **Control parental**: en Ajustes, *Ocultar contenido adulto* (grupos XXX, Adult, +18…) y un PIN de 4 dígitos que protege desactivarlo.
- **Copia de seguridad**: *Ajustes → Copia de seguridad* exporta/importa favoritos, listas propias, canales propios, listas M3U por URL y ajustes (nunca el PIN ni listas Xtream). Se guarda en la carpeta `backups` de la app; se puede importar desde ella, desde una URL o desde un archivo.
- **Guía de programación**: Mantén OK → *Ver programación*. TV Perú usa su web oficial; el resto, el XMLTV de epgshare01 de los países de tus favoritos (por defecto Perú) y, opcionalmente, una URL propia (*Guía personalizada*).
- **Accesibilidad**: tamaño de letra (100/115/130 %) y alto contraste.
- **Pantalla de inicio de Android TV**: fila *Favoritos* y enlaces `fredtv://play?name=…` / `fredtv://search?q=…`; la app también atiende el intent de búsqueda.
- **mpv**: *Decodificación de video (mpv)* → *Sin copia* es experimental (`hwdec=mediacodec`) y vuelve a la automática si no da imagen.

> ExoPlayer no permite elegir pista de audio con la versión de Flutter del proyecto (la API exige Flutter ≥ 3.35); para eso usa "Usar mpv en este canal".

## Listas de canales

- **Agregar desde iptv-org** (Ajustes): lista recomendada en español, todos los países y las categorías de [iptv-org](https://github.com/iptv-org/iptv).
- **Agregar lista M3U por URL** (Ajustes): cualquier lista `http://` o `https://`.
- **Actualización automática**: al abrir la app se actualizan, en segundo plano, las listas con más de 24 h. Favoritos, historial y *Mis listas* se conservan. También puedes actualizar todas o una sola desde **Ajustes → Mis fuentes**.
- **Mis listas**: crea tus propias listas, agrega canales con *Mantener OK → Agregar a una lista…* o por URL, y reordénalos. Las listas siguen funcionando cuando se actualizan los enlaces de las fuentes.

## Probar el modo TV en un teléfono

```bash
flutter run --dart-define=FORCE_TV=true
```

## Instalación en Android TV

### APK directo
1. `flutter build apk --release`
2. Copia `build/app/outputs/flutter-apk/app-release.apk` a la TV (USB o red) e instálalo.

### ADB
```bash
adb connect <IP_DE_TU_TV>:5555
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Android Studio
Conecta la TV por ADB y ejecuta `flutter run` con la TV como dispositivo.

## Requisitos de Android TV en el manifiesto

- Categoría `LEANBACK_LAUNCHER` (aparece en el launcher de TV) y banner `@drawable/tv_banner`.
- `touchscreen` no requerido y `android.software.leanback` opcional (la app también se instala en teléfonos).

## Solución de problemas

- **No aparece en el launcher de TV**: verifica la categoría `LEANBACK_LAUNCHER` y el banner en `AndroidManifest.xml`.
- **El control remoto no responde**: reinicia la app o prueba con otro control (o la app de control remoto del celular).
- **Se ve la interfaz de teléfono en la TV**: la detección usa el modo de UI de Android; fuérzalo con `--dart-define=FORCE_TV=true`.
- **Un canal no reproduce**: muchos canales gratuitos caen o tienen bloqueo geográfico. Prueba *Siguiente canal* o actualiza la lista.
- **Motor de video**: en *Ajustes → Motor de video* eliges *Automático* (ExoPlayer y, si falla o no da imagen en 10 s, mpv con hardware y luego por software) o *Solo mpv*. ExoPlayer no permite elegir audio/subtítulos ni usa el buffer configurable; en las opciones del reproductor (mantén OK) puedes pasar ese canal a mpv.
- **La lista de iptv-org no carga**: revisa la conexión; el catálogo se descarga de `iptv-org.github.io`.

## Roadmap

- [ ] Guía de programación (EPG)
- [ ] Búsqueda por voz
- [ ] Integración con Android TV Channels
- [ ] Picture-in-Picture (PiP)
- [x] Reproductor ExoPlayer nativo (con mpv de respaldo)
