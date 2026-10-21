# Fred TV Mobile

Fred TV for Android and iOS

<a href="https://apps.apple.com/ca/app/open-tv-open-source-iptv/id6742751800">
  <img src="https://raw.githubusercontent.com/Fredolx/open-tv/refs/heads/main/readme_imgs/app-store.svg" width=300 />
</a>
<a href="https://play.google.com/store/apps/details?id=dev.fredol.open_tv">
  <img src="https://raw.githubusercontent.com/Fredolx/open-tv/refs/heads/main/readme_imgs/gplay.png" width=330>
</a>

# Please consider donating on [Github](https://github.com/sponsors/Fredolx), [Patreon](https://www.patreon.com/fredol), [Paypal](https://paypal.me/fredolx) or directly by [crypto](#crypto)

![Screenshot 2025-07-07 at 7 36 14 AM](https://github.com/user-attachments/assets/baf0c53b-a33a-4bb7-bf48-24b8dd20fb20)

---

## Fork: mejoras para Android TV

Este fork añade una interfaz pensada para el control remoto y hace que la app sea estable en Android TV. En teléfonos y tablets sigue usándose la interfaz móvil original. Guía completa de controles e instalación: [ANDROID_TV_README.md](ANDROID_TV_README.md).

**Reproducción estable**
- **ExoPlayer como motor principal y mpv de respaldo**: si un canal no da imagen, se prueba con mpv por hardware y luego por software. Se puede forzar mpv para todos los canales o para uno solo.
- **Reconexión automática** en directo y reintentos con mensajes de error claros (*Reintentar*, *Siguiente canal*, *Volver*).
- **Buffer configurable** y opciones de mpv que evitan cortes en HLS; audio de HLS que declara solo video corregido; decodificación sin copia (experimental) con vuelta automática si falla.
- **Canales caídos**: se marcan tras dos fallos seguidos, el zapping los salta y se pueden ocultar o limpiar.

**Control con D-pad**
- Foco nativo en todas las pantallas, menú lateral colapsable y cinco pestañas: Canales, Favoritos, Mis listas, Buscar y Ajustes.
- **Teclado propio** manejable con el control (con opción de teclado del sistema o voz).
- **Mantén OK** abre las opciones del canal; zapping por número, tecla de último canal y grupo *Recientes*.

**Canales y datos**
- Alta de listas desde el catálogo de **iptv-org** o por URL M3U, con **actualización automática** cada 24 h.
- **Mis listas** propias (con canales manuales), filtro por **país** y **copia de seguridad** exportable e importable.
- **Guía de programación (EPG)**: TV Perú y XMLTV por país, con URL propia opcional.
- **Control parental** con PIN, **tamaño de letra** y **alto contraste**.
- Integración con Android TV: fila *Favoritos* en la pantalla de inicio, enlaces `fredtv://` y búsqueda del sistema.

**Cámara de seguridad en un recuadro**
- Configura la dirección RTSP en *Ajustes → Cámara de seguridad* y aparece como un canal más.
- Con cualquier canal en pantalla, *Mantén OK → Mostrar cámara* la abre en un recuadro, sin audio; se puede **intercambiar con el canal** a pantalla grande, hacer **zoom** (1x a 4x con desplazamiento) y ocultarla. Usa su propio mpv por TCP y se reconecta sola.

La interfaz de TV se cubre con más de 390 pruebas automáticas.
