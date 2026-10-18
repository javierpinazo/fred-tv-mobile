# Crear Banner para Android TV

## Requisitos del Banner

Android TV requiere un banner específico para aparecer en el launcher de TV. El banner debe cumplir con estas especificaciones:

### Especificaciones Técnicas
- **Tamaño**: 320x180 píxeles (ratio 16:9)
- **Formato**: PNG con transparencia
- **Nombre del archivo**: `ic_banner.png`
- **Ubicación**: `android/app/src/main/res/mipmap-xhdpi/`

### Diseño Recomendado
- Logo de la aplicación prominente
- Nombre de la aplicación ("Fred TV")
- Fondo que contraste con el texto
- Evitar demasiados detalles pequeños (se verá desde lejos)
- Usar colores vibrantes para destacar en el launcher de TV

## Pasos para Crear el Banner

### Opción 1: Usar una Herramienta de Diseño

1. **Abre tu editor de imágenes favorito** (Photoshop, GIMP, Figma, Canva, etc.)

2. **Crea un nuevo documento**:
   - Ancho: 320px
   - Alto: 180px
   - Resolución: 72 DPI mínimo

3. **Diseña el banner**:
   - Coloca el logo de Fred TV en el centro o izquierda
   - Agrega el texto "Fred TV" con una fuente legible
   - Usa un fondo con gradiente o color sólido
   - Asegúrate de que sea visible en pantallas grandes

4. **Exporta el archivo**:
   - Formato: PNG
   - Nombre: `ic_banner.png`
   - Mantén la transparencia si es necesario

5. **Copia el archivo a las carpetas de recursos**:
   ```bash
   cp ic_banner.png android/app/src/main/res/mipmap-xhdpi/
   cp ic_banner.png android/app/src/main/res/mipmap-xxhdpi/
   cp ic_banner.png android/app/src/main/res/mipmap-xxxhdpi/
   ```

### Opción 2: Usar Comando para Crear un Banner Básico

Si no tienes un diseño listo, puedes crear un banner temporal básico:

#### Usando ImageMagick (si lo tienes instalado):
```bash
convert -size 320x180 xc:"#1976D2" \
  -gravity center \
  -pointsize 48 \
  -fill white \
  -annotate +0+0 "Fred TV" \
  android/app/src/main/res/mipmap-xhdpi/ic_banner.png
```

#### Usando Python PIL (si tienes Python instalado):
```python
from PIL import Image, ImageDraw, ImageFont

# Crear imagen
img = Image.new('RGB', (320, 180), color='#1976D2')
draw = ImageDraw.Draw(img)

# Agregar texto
font = ImageFont.truetype("arial.ttf", 48)
text = "Fred TV"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
x = (320 - text_width) / 2
y = (180 - text_height) / 2
draw.text((x, y), text, fill='white', font=font)

# Guardar
img.save('android/app/src/main/res/mipmap-xhdpi/ic_banner.png')
```

### Opción 3: Usar el Logo Existente

Si ya tienes un logo de Fred TV, puedes adaptarlo:

```bash
# Redimensionar el logo existente al tamaño del banner
# (reemplaza 'logo.png' con la ruta a tu logo)
convert logo.png -resize 320x180! android/app/src/main/res/mipmap-xhdpi/ic_banner.png
```

## Verificar el Banner

1. **Compila y ejecuta la app en Android TV**:
   ```bash
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Verifica en el launcher de TV**:
   - Ve al launcher principal de Android TV
   - Busca la aplicación "Fred TV"
   - Deberías ver tu banner en lugar del icono estándar

## Ejemplo de Banner

Aquí hay un diseño sugerido en código:

```
┌────────────────────────────────────┐
│                                    │
│     📺   Fred TV                   │
│     Streaming de Canales           │
│                                    │
└────────────────────────────────────┘
```

## Recursos Útiles

- [Guía oficial de Android TV Banners](https://developer.android.com/training/tv/start/start#banner)
- [Asset Studio de Android](https://romannurik.github.io/AndroidAssetStudio/)
- [Canva](https://www.canva.com/) - Herramienta de diseño en línea gratuita
- [GIMP](https://www.gimp.org/) - Editor de imágenes gratuito

## Nota Importante

El banner es **obligatorio** para que la aplicación aparezca en el launcher de Android TV. Sin él, la aplicación seguirá funcionando pero no aparecerá en la pantalla principal de TV.

Si no creas un banner personalizado, se usará el icono de la aplicación por defecto, lo cual no se ve bien en Android TV.
