# Widgets de escritorio Android (AppWidgets)

La familia de tasas vive en el launcher, fuera de la app: «Tasa BCV»,
«Paralelo» y «Brecha» — los tres leen las mismas claves que
`lib/services/widget_service.dart` escribe tras cada `fetchBoard` OK
(vía `home_widget`, archivo `HomeWidgetPreferences`).

## Cómo los ve el usuario

**Antes de añadir (selector de widgets).** Desde Android 12 el selector
renderiza el layout REAL (`previewLayout` en `res/xml/widget_*_info.xml`)
— mismo fondo, tipografía y jerarquía que el widget instalado. En
Android 5–11 entra el PNG estático `drawable-nodpi/widget_preview_*.png`
(generado por `scripts/gen_widget_previews.py` fuera del repo, cifras de
la semilla documentada). Cada uno también trae su descripción corta
(`values/strings.xml`) bajo el nombre.

**Redimensionado.** `resizeMode=horizontal|vertical` con límites
explícitos: por defecto 4×1 (`targetCellWidth/Height` en Android 12+,
`minWidth=250dp` antes), mínimo ~2×1 (`minResizeWidth=110dp`) y máximo
4×2 (`maxResize*`). Al soltar el marco, `onAppWidgetOptionsChanged`
vuelve a renderizar.

**Contenido adaptativo.** `BaseRatesWidget.bucketOf()` mide el espacio
garantizado (retrato: `OPTION_APPWIDGET_MIN_WIDTH/HEIGHT`) y elige:

| Bucket | Dispara en | Qué muestra |
|--------|-----------|-------------|
| COMPACT | ≤140 dp de ancho o ≤80 dp de alto | Solo la cifra (18sp) |
| NORMAL | resto | Título + cifra (30sp) + secundario + hora |
| BIG | ≥250×120 dp (4×2) | Todo, cifras grandes (44sp) |

**Toque.** Tocar cualquier widget abre la app
(`PendingIntent` inmutable al launch intent).

## Flujo de datos (sin red en el widget)

1. `app_state` refresca el tablero (o `workmanager` en background).
2. `WidgetService.updateBcv()` guarda tasas es-VE + hora + brecha.
3. `HomeWidget.updateWidget()` emite `APPWIDGET_UPDATE` a los 3
   proveedores → `onUpdate` → `render(context, read(ctx), bucket)`.
4. Cada 30 min (`updatePeriodMillis`) el sistema re-renderiza con lo
   último guardado — la hora visible se refresca sola.

## Verificación manual

1. `flutter run` en un device/emulador, esperar primer fetch OK.
2. Launcher → widget picker → buscar «ValoraVE» → las tres previews.
3. Añadir «Tasa BCV» → cifra real, no «—».
4. Mantener pulsado y estirar a 4×2 (BIG) y encoger a 2×1 (COMPACT):
   el contenido se recompone al soltar el marco.
5. Tocar el widget → abre ValoraVE.

Nota: `flutter analyze`/`flutter test` no compilan Kotlin — el gate
real del lado nativo es el build de Actions (los workflows CI/Build del
repo compilan los 4 APK + AAB y el paso 8 del contrato los verifica).
