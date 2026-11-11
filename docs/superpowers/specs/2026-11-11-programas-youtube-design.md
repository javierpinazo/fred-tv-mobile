# Programas dentro de un canal de YouTube — Diseño

Fecha: 2026-11-11 · Rama: `feat/canales-youtube` · Continúa
`2026-11-10-canales-youtube-design.md`.

## Para qué

Un canal de YouTube emite varios programas distintos: «Canal Ya» (el canal
que la app llama «La Encerrona») tiene La Encerrona, Centrífugos, Pequeñas
Islas, La Frikitona…; La República tiene Sin Guion, Fuerte y Claro, Arde
Troya…; Paolo Benza tiene La Contra, Contraataque, Helado B. Hoy la pantalla
del canal los muestra todos mezclados por fecha y cuesta encontrar «el de
hoy» del programa que el usuario sigue.

El usuario quiere entrar al canal y ver **arriba su programa preferido con
sus últimas emisiones**, debajo los demás programas separados, y poder
**cambiar con el mando qué programa va arriba**.

## Vocabulario

- **Emisión**: un vídeo o directo concreto. En el código ya existe como
  `YoutubeProgram` (no se renombra).
- **Programa**: la serie a la que pertenece una emisión (La Encerrona, Sin
  Guion…). En el código nuevo: `YoutubeShow`.

## Qué ve el usuario

```
▶ La Encerrona                                   (nombre del canal en la app)

La Encerrona        [hoy] [ayer] [lunes] [viernes] →     ← programa prioritario
Centrífugos         [última] [anterior] →
Pequeñas Islas      [última] [anterior] →                  hasta 5 filas
La Frikitona        [última] [anterior] →
Planeta Mar         [última] [anterior] →
Todo lo último
[·] [·] [·] [·]                                           ← mosaico de siempre
[·] [·] [·] [·]
```

Decidido por el usuario:

1. La pantalla del canal se organiza en **filas por programa**: título del
   programa y debajo un carrusel horizontal con sus emisiones, **de la más
   reciente a la más antigua**.
2. **Como máximo 5 filas de programa.** La primera es el programa
   prioritario.
3. Después de las filas va **todo mezclado**, por fecha.
4. Prioridad inicial: **La Encerrona** en el canal La Encerrona, **Sin
   Guion** en La República, **La Contra** en Paolo Benza.
5. La prioridad se cambia **manteniendo OK sobre un programa**, con opciones
   para **moverlo en el orden**.

Decidido por mí (el usuario lo vio descrito y no lo objetó, salvo donde se
indica «no visto»):

- Las filas que el usuario no ha ordenado se colocan según cuál tiene la
  emisión más reciente.
- Un directo en curso va primero en la fila de su programa, con «EN VIVO»,
  igual que hoy.
- El menú de mantener OK ofrece «Poner primero», «Subir» y «Bajar».
- El orden se guarda por canal y se respeta siempre.
- Curwen y Carlos León Moya no tienen prioritario inicial.
- *(no visto)* El bloque final «Todo lo último» es el mosaico actual de 4
  columnas, no un carrusel: se recorre mejor cuando hay 40–60 emisiones.
- *(no visto)* Un programa sin emisiones en los últimos 30 días no ocupa
  fila, salvo que el usuario lo haya ordenado él mismo.
- *(no visto)* Si un canal no deja reconocer ningún programa, la pantalla
  queda como hoy: solo el mosaico, sin el título «Todo lo último».

## Cómo se sabe de qué programa es cada emisión

Comprobado contra YouTube real el 2026-11-11:

- `/channel/<id>/playlists?hl=es` trae las listas del canal como
  `lockupViewModel` con `contentId` que empieza por `PL` y el título en el
  mismo sitio que los vídeos. `contentType` es
  `LOCKUP_CONTENT_TYPE_PLAYLIST` o `LOCKUP_CONTENT_TYPE_PODCAST`. El orden
  de esa página **no** es por actividad reciente y la miniatura no siempre
  identifica el último vídeo: no sirven para ordenar.
- `/playlist?list=<id>&hl=es` trae hasta 100 emisiones de la lista como
  `lockupViewModel` de vídeo, con duración y antigüedad («hace 11 h»): el
  lector actual `parseYoutubeTab` las entiende sin cambios. Las listas de
  programa vienen de la más reciente a la más antigua.
- Los títulos suelen llevar el programa: `… #LaEncerrona`, `… | CENTRÍFUGOS`,
  `… - Pequeñas Islas`, `… | SIN GUION CON ROSA MARÍA PALACIOS`,
  `… | #ContraAtaque 10/11`, `… | #HeladoB 10/11`.
- No siempre: los vídeos de «La Contra» no lo llevan (solo patrocinadores,
  `#verisure`…), pero están todos en la lista «La Contra Podcast». Y al
  revés: la emisión de hoy de La Encerrona aún no estaba en su lista pero sí
  llevaba `#LaEncerrona`. Hacen falta **las dos señales**.
- La República no publica listas de sus programas diarios; solo se
  reconocen por el título.
- YouTube devuelve a veces una página sin `ytInitialData` (pasó en la tele
  con `/streams` y en el PC con `/videos`); al repetir la petición llega
  bien.

### Programas conocidos de un canal

1. **Las listas del canal.** El nombre del programa es el título de la
   lista. Su *clave* es el título normalizado (minúsculas, sin tildes, solo
   letras y dígitos) tras quitarle los finales `envivo` y `podcast`. Dos
   listas con la misma clave son un solo programa con dos listas («La Contra
   EN VIVO» + «La Contra Podcast» → «La Contra»); el nombre mostrado es el
   título más corto sin ese final.
2. **Programas incorporados**, para canales que no publican listas. Solo La
   República (`UC-B7Xv56uNRDkj0vC3QW8Cg`): Sin Guion, Fuerte y Claro, Que No
   Se Te Olvide, La Verdad a Fondo, Arde Troya.

Los incorporados también fijan el **nombre mostrado** de una clave cuando el
título de la lista no es presentable: la lista `#LaEncerrona` (clave
`laencerrona`) se muestra como «La Encerrona». Los demás se muestran con el
título de su lista tal cual, sin `#` inicial («CENTRÍFUGOS», «Pequeñas
Islas»).

Claves de los prioritarios iniciales: `laencerrona` (canal
`UCP0AJJeNkFBYzegTTVbKhPg`), `singuion` (`UC-B7Xv56uNRDkj0vC3QW8Cg`),
`lacontra` (`UCIpXj6C68YhT8Px3DGCafYA`).

Una emisión de antigüedad desconocida no cuenta como reciente.

Las claves de menos de 5 caracteres no se usan para reconocer por título
(«yo», «ppk» aparecerían dentro de cualquier palabra); esos programas solo
tienen las emisiones de su lista.

### Emisiones de un programa

Una emisión pertenece a un programa si **está en una de sus listas** o si
**su título normalizado contiene la clave** del programa. Si el título
contiene varias claves gana la más larga («La Contra Opina» antes que «La
Contra»). Una emisión puede estar en varios programas si varias listas la
incluyen; no es un problema.

### Qué listas se leen

Leer las 29 listas de un canal es demasiado. Por cada carga de un canal se
leen como máximo **6 páginas de lista**, en este orden de preferencia:

1. programas que el usuario ha ordenado y el prioritario inicial;
2. programas con emisiones recientes reconocidas por título, del más
   reciente al más antiguo;
3. si aún queda cupo, el resto de listas en el orden de la página (así un
   canal con pocas listas y títulos sin etiqueta, como Curwen, también
   obtiene filas).

Las emisiones de un programa son la unión, sin repetir, de las de sus listas
leídas y las reconocidas por título entre las recientes (`/videos` +
`/streams`), ordenadas con la misma regla que hoy (`mergeYoutubePrograms`:
directos en curso primero, luego por antigüedad). Cada fila muestra hasta 20.

## Orden de las filas

Función pura, sin red:

1. Se descartan los programas sin emisiones.
2. Primero, los programas del **orden guardado** del usuario para ese canal,
   en ese orden. Si no hay orden guardado, hace de orden guardado el
   prioritario inicial del canal (si existe).
3. Después, los demás programas cuya emisión más reciente tiene menos de 30
   días (un directo en curso cuenta como «ahora»), del más reciente al más
   antiguo; a igualdad, por nombre.
4. Se cortan a 5.

### Mover un programa

Mantener OK sobre cualquier emisión de una fila de programa abre un menú
con el nombre del programa y:

- **Poner primero** — no aparece si ya es la primera fila;
- **Subir** — no aparece en la primera fila;
- **Bajar** — no aparece en la última fila visible.

Al mover, se toma el orden visible en ese momento (las claves de las filas
mostradas), se aplica el movimiento y esa lista completa pasa a ser el orden
guardado del canal. Las filas se reordenan en el acto, sin volver a
descargar, y el foco se queda en el programa movido.

Mantener OK en el mosaico «Todo lo último» no hace nada.

### Dónde se guarda

En los ajustes de la app (`Sql.setSetting`), una sola clave
`tvYoutubeShowOrder` con un JSON `{ "<ruta del canal>": ["clave", …] }`,
donde la ruta es la misma que ya identifica al canal en la caché
(`/channel/UC…` o `/@handle`). Un JSON ilegible se trata como «sin orden».

## Reintento

Cada página (`/videos`, `/streams`, `/playlists`, una lista) se pide una
segunda vez, tras ~1 s, si la respuesta no es 200 o no trae `ytInitialData`.
Solo una vez.

## Fallos

- Falla `/playlists` → se usan solo los programas incorporados; el resto de
  la pantalla funciona.
- Falla una lista → ese programa se queda con lo reconocido por título.
- Fallan `/videos` y `/streams` → pantalla de error con «Reintentar», como
  hoy, aunque las listas hayan cargado.
- Nada de esto muestra avisos nuevos al usuario.

## Caché

Como hoy: resultado completo del canal 2 minutos en memoria; «Reintentar»
la ignora. El orden del usuario no forma parte de la caché (se aplica al
mostrar).

## Idiomas

Cadenas nuevas en los 6 ARB: «Todo lo último», «Poner primero», «Subir»,
«Bajar». Los nombres de los programas no se traducen.

## Restricciones

- Flutter 3.32; sin dependencias nuevas.
- La letra grande de Ajustes no debe cortar textos: el alto de filas y
  títulos sigue al tamaño de letra, como ya hace la tarjeta.
- El foco con el mando: arriba/abajo cambia de fila (y entra/sale del
  mosaico), izquierda/derecha recorre el carrusel; la fila enfocada queda
  siempre visible entera. Al volver del reproductor el foco regresa a la
  emisión que se abrió.
- No tocar el reproductor ni el zapping.
- Nunca `git push`; no borrar datos de la app en la tele.

## Fuera de alcance

- Renombrar, ocultar o crear programas a mano.
- Leer más allá de la primera página de una lista o de las pestañas.
- Elegir prioridad desde Ajustes (solo desde la pantalla del canal).
- Recordar por dónde iba cada emisión.

## Sería un fracaso si…

- el programa de hoy tarda más en encontrarse que antes;
- abrir un canal se vuelve claramente más lento (las filas no deben retrasar
  lo que ya cargaba: 2 páginas → hasta 9, en paralelo);
- una fila de programa sale vacía o con emisiones de otro programa de forma
  habitual;
- un cambio de formato de las listas de YouTube deja la pantalla sin nada:
  siempre debe quedar al menos el mosaico.

## Comprobación final en la tele

1. La Encerrona: primera fila «La Encerrona» con la emisión de hoy primero;
   debajo, otros programas del canal; al final «Todo lo último».
2. La República: primera fila «Sin Guion»; con el programa en directo, su
   tarjeta va primera con «EN VIVO».
3. Paolo Benza: primera fila «La Contra» con emisiones recientes.
4. Curwen y Carlos León Moya abren sin error, con o sin filas.
5. Mantener OK → «Bajar» / «Poner primero» reordena en el acto; al salir y
   volver a entrar (y tras reiniciar la app) el orden se mantiene.
6. Con la letra grande no se corta ningún título; el foco nunca se pierde ni
   deja la fila a medias fuera de pantalla.
7. Reproducir desde una fila y volver con Atrás deja el foco donde estaba.

## Queda al criterio de quien lo construya

- Forma exacta de los tipos y de la división en archivos.
- Tamaño de las tarjetas del carrusel (misma tarjeta que el mosaico).
- Cómo repartir en paralelo las peticiones y los tiempos de espera.
- Aspecto del menú (reutilizar los diálogos de TV existentes).
