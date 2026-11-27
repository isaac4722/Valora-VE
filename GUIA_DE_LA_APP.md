# Cómo funciona ValoraVE — guía de la app

> Documento de referencia para el dueño y para quien llegue al código.
> Versión descrita: **1.18.0-beta (ronda v33)** · rama `v1.1.0-dp4-paridad`.
> La versión con formato (Word/PDF) se entrega junto a cada ciclo.

## 1. Qué es

ValoraVE es un **libro de precios y divisas de Venezuela** que vive en el
teléfono: ¿a cuánto está el dólar (y el euro) hoy?, ¿cuánto es mi dinero de
una moneda a otra? y ¿cuánto me cuesta lo que compro? Todo lo que guardas
permanece en el teléfono: **offline primero, sin cuentas, sin nube**.

## 2. Principios del producto

- **Una cifra protagonista** por pantalla (equivalencia en Inicio, total en
  Lista, resultado en Conversor).
- **Formato venezolano**: miles con punto, decimales con coma
  (`1.500,100 Bs`).
- **Compartir = imagen, Copiar = texto.**
- **El texto nunca se corta ni se encoge ilegible**: la cifra grande reduce
  tamaño gradualmente antes de romper la línea (`FittedBox.scaleDown`
  solo en valores); los subtítulos ENVUELVEN a 13.5 px reales.
- **Títulos/headers SOLOS**, con la separación requerida; las puertas
  (Sala, Historial, Cachea) viven en filas delineadas gemelas.
- **Iconos grandes y centrados**: `VeIconBtn` 36/17 por defecto; escáner
  40/18; «atrás» de pantallas internas 40/20.

## 3. Mapa de pantallas

| Pestaña / ruta | Qué hace |
| --- | --- |
| `/` Inicio | Equivalencia «1 USD = X Bs» de la fuente activa (BCV · Oficial por defecto), acciones del día, resumen del mes y actividad. Header sin lupa (avisos · tema · ajustes). |
| `/tasas` | Tablero de fuentes por divisa (Oficial · Promedio · Mercado · Manual), brecha, diagnóstico; fuente por módulo. |
| `/conversor` | Conversión con fecha **Ayer · Hoy · Mañana · Fecha**; escala única de precisión 2/3/4/«Completo»; panel de cobro (pago móvil, transferencia, Zelle) con Compartir (imagen) y Copiar (texto). |
| `/lista` | Calculadora de compras: captura QUÉ·CUÁNTO·DÓNDE, total en tarjeta, **Modo Cachea** (fila propia: inicial + cuotas quincenales, solo cálculo), presupuesto, cálculos, barra pegadiza con **Dividir cuenta** y **Cerrar compra** (checkout con vuelto multi-divisa y foto de ticket). |
| `/sala-viva` | Lista sincronizada P2P sin internet: modos Cerca/WiFi/Bluetooth/Servidor, código + QR centrados, roles anfitrión/editor/observador, PIN opcional de emojis. |
| `/analisis` | Divisas · Inflación · Canasta · Gastos (barra segmentada; rango de tiempo solo donde se usa). |
| `/productos`, `/tickets`, `/historial` | Libro de precios, fotos de recibos, compras cerradas con constancia. |
| `/ajustes` | Una pantalla por secciones (v32: encabezado único + filas planas del kit): cuentas por tipo, tasas, alertas, diagnóstico, país y decimales, datos y conexión, apariencia, respaldo, acerca de. |

## 4. Cuentas y cobro por tipo (H-43)

| Tipo | Campos | Nota |
| --- | --- | --- |
| Pago móvil | banco · cédula · teléfono (11) | el panel del Conversor arma el cobro; Compartir = imagen 1080×1080, Copiar = texto |
| Transferencia | banco · tipo (corriente/ahorro) · número (20) · cédula | sin teléfono — el tipo decide qué existe |
| Zelle | titular · correo o teléfono US | validación suave de correo/teléfono |

`PayAccount.dataLines` es la única fuente para fila, copiado, mensaje y
tarjeta; la migración de respaldos viejos no pierde datos.

## 5. Exportación (PDF/imágenes)

- Composición a **360 px lógicos** con la tipografía real (11 · 13.5 · 17 ·
  30) y rasterizado ×3 → 1080 px (constancia 4:5 exacto 1080×1350).
- PDF de constancia: fuentes de marca embebidas (Inter + Space Grotesk con
  degradación honesta), márgenes 44 pt, encabezado y pie en todas las hojas
  («Página n»), cabecera de tabla repetida.
- UNA tubería de render (`renderSharePng` → `renderOffstagePng`); errores en
  tres capas con mensajes en cristiano (generar / compartir / imprimir).

## 6. Builds (solo APK)

El paquete de cada ciclo lleva **exactamente 4 APK** + LEEME + checksums
(sin `.aab`, sin binarios no instalables):

| APK | Para qué |
| --- | --- |
| `universal` | cualquier teléfono (opción segura) |
| `arm64-v8a` | la mayoría desde 2016 |
| `armeabi-v7a` | teléfonos antiguos |
| `x86_64` | emuladores/tablets Intel |

La app avisa de versiones nuevas: Ajustes → Acerca de → Buscar
actualizaciones (GitHub Releases).

## 7. Datos y privacidad

Base local (Hive) · respaldo JSON exportable/importable (reemplazar o
fusionar) · fotos de tickets viajan dentro del respaldo · registros técnicos
solo en memoria · candado biométrico opcional al abrir y (aparte) para las
cuentas.

## 8. Verificación de cada ciclo

- `flutter analyze` 0 (solo infos de deprecación del SDK local).
- Suite completa verde (380 tests en v32).
- Gate visual web 390×844 (servir `build/web` y capturar pantallas).
- CI (analyze+tests+auditoría de prohibiciones) y Build (APKs) en GitHub
  Actions; ambos verdes antes de cerrar la ronda.
