# MVP-CRUD.md · Verdad funcional de ValoraVE

**Qué es este archivo:** la ÚNICA fuente de verdad funcional (AGENT.md).
Si el código y este MD discrepan, manda este MD; la desviación se anota
en `PROGRESS.md` y se decide: o se corrige el código, o se evoluciona
este documento con la orden del dueño.

> Nota de procedencia: el MVP-CRUD original (privado) nunca estuvo en
> git. Esta es la reconstrucción canónica desde el código implementado
> y el historial de órdenes del dueño (los antiguos archivos de paridad
> y el resumen del sistema de diseño, retirados en la consolidación
> documental, viven en el historial git). La numeración § respeta las
> citas históricas del repo
> (§4.10, §4.16, §5, §6, §7, §8, §9, §12.2, §14…), para que ninguna
> referencia vieja quede huérfana.

## §1 · Principios

1. **Offline-first:** la app vive del teléfono; la red es un lujo.
   Todo funciona sin conexión (outbox, caché, estados honestos).
2. **Honestidad de datos:** nada de cifras inventadas. Sin fuente hay
   «sin dato» visible, jamás un número decorativo.
3. **es-VE:** idioma, formato (1.234,56) y vocabulario local
   (vuelto, cesta, punto).
4. **Una cosa a la vez:** cada módulo resuelve SU trabajo sin invadir
   al vecino.
5. **Las órdenes del dueño mandan:** toda desviación consciente queda
   documentada en `PROGRESS.md` con la orden que la originó.

## §2 · Modelo de datos (`lib/core/models.dart`)

| Entidad | Rol | Operaciones (CRUD) |
|---|---|---|
| `Product` + `PriceRecord` | libro de precios por producto/tienda | crear/editar/retirar producto; agregar/editar récord de precio; disponibilidad; meta (TARGET_EPS, metSince auto) |
| `Purchase` + `PurchaseItem` | compra cerrada (asiento) | crear por checkout; filtrar/listar (pág. 20); exportar; anular |
| `CartItem` | renglón del carrito vivo | agregar/editar/tachar (checked/checkedBy)/borrar |
| `ShoppingTemplate` | plantilla de lista (máx. 20) | crear/aplicar/borrar |
| `Transaction` | (LEGADO) transacciones del módulo Finanzas retirado | solo round-trip de respaldos viejos |
| `RateEntry` / `RateBoard` | tasas por fuente con frescura | lectura del motor; manuales editables |
| `Settings` / `Budget` / `ConverterState` | preferencias (15 claves AppData: 13 originales + `customRates` y `accounts` de v23) | editar; persistir |
| `NotificationItem` (9 kinds) | centro de notificaciones | listar; leer; limpiar |
| `RecentConversion` / `SnapshotPoint` | recientes (dedupe 60s) / «vs ayer» | agregar/podar; snapshots diarios |
| `CustomRate` (v23) | tasa propia con nombre + brecha vs BCV (máx 8) | crear/retirar; aplicar (por el mecanismo manual) |
| `PayAccount` (v23) | cuenta de cobro para Pago Móvil (máx 4) | crear/retirar; candado biométrico opt-in |
| Semillas | 21 productos de arranque | primera ejecución |

Persistencia: Hive en 4 cajas JSON (`lib/data/store.dart`), migración
tolerante y merge HMR-safe. `AppData` es el agregado de las 15 claves.

## §3 · Motor de tasas

- **Fuentes:** 18 con kind/category + DEFAULT oficiales (BCV oficial,
  paralelo, manuales) + cripto v23.2 por orden del dueño: USDT
  (P2P «Referencia P2P», Global «tether» y Manual) —
  `lib/core/currencies.dart`. USDT↔Bs es arista DIRECTA. ETH se retiró en
  v27 por orden del dueño.
- **Respaldos por región (v23.2):** VE → DolarAPI → DolarVZLA → Worker
  CalculaYa (`calculaya-api.jalvarezgw19.workers.dev/tasas`, hallado por
  REA del APK 1.1.0; `usd` = BCV verificado al dígito en vivo) — el
  respaldo NUNCA pisa dato fresco. COP mercado → AwesomeAPI → remesas
  CalculaYa. Cripto: USDT P2P desde CalculaYa; tether global desde
  CoinGecko; si CalculaYa cae, Bs/USDT se DERIVA del paralelo × tether
  global (guard sanidad 0.2–2 USD; el sello sigue «Mercado»).
- **Plan de conversión:** `RateContext.plan` devuelve la ruta VISIBLE
  (path + sourceIds), incl. puente USD y ruta EUR de 4 tramos
  (`ConversionPlan.direct`).
- **Histórico honesto:** fecha elegible desde 2023-01-03 (PICKER_MIN);
  día sin dato = «sin dato», no relleno.
- **Ingesta:** polling + SSE opcional (`sse_stream.dart`) comparten
  pipeline.
- **Modo Cachea (v27.3):** simulador de compra con inicial + cuotas
  quincenales sin intereses (3 · 6 · 9 · 12) en la Lista. Es un cálculo,
  no un método de pago: `lib/core/cachea.dart` y `cachea_sheet.dart`.

## §4 · Decisiones técnicas

- **§4.10 — Sala multi-transporte:** el MISMO protocolo lista-sync sobre
  cuatro transportes: Servidor socket.io (URL configurable),
  Cerca (Nearby Connections, sin internet), Bluetooth clásico
  (RFCOMM/SPP) y WiFi local (ServerSocket 48130 + broadcast UDP).
- **§4.16 — Flutter SIEMPRE última stable** en CI; el gate protege de
  roturas (analiza y testea en cada push).
- Obfuscación de release con `--split-debug-info`; firma v2; símbolos
  aparte en artefactos.
- Cobertura total de builds (v31, orden del dueño): **solo APK** — 1
  universal + arm64-v8a + armeabi-v7a + x86_64 — más ZIP único con LEEME
  y checksums. El AAB se retiró del CI en v31 por orden del dueño;
  prohibido retirar un ABI o el ZIP sin orden expresa del dueño. (x86 32
  bits no es construible: Flutter no distribuye ese motor.)
- Software PROPIETARIO: licencia de titular privado (LICENSE).

## §5 · Reglas de tasas y salud

- Frescura visible por `fetchedAt` («hace X min»).
- **Banner de salud:** tasas con más de 15 min sin refrescar activan
  `RateHealthBanner`; `stale` jamás instantáneo.
- Récord de precio del producto = último válido por tienda; disponibilidad
  con aviso al usuario.
- Color de datos SOLO con significado: oficial verde · mixto ámbar ·
  paralelo rojo · manual violeta; sube/baja pos/neg.
- **v23.3 · Ingesta:** el stream SSE FUSIONA por id contra el tablero
  vigente (`mergeSseSources`: lo ausente sobrevive, un push viejo no pisa
  un dato fresco del poll); el respaldo de CalculaYa se consulta solo tras
  el bloque de euros (antes en cada ronda) y con memo de 30 s compartido
  por VE/CO/cripto; el sello de una tasa DERIVADA es el mín de sus
  insumos (tan fresco como el más viejo); el auto-poll pausado en
  background no revive con flaps de red (`_autoPaused` hasta startAuto).

## §6 · Sala en vivo (protocolo lista-sync)

- **Sincronización:** operaciones granulares, LWW por timestamp, GC de
  ítems, presencia, typing; el que se une pierde su lista previa (por
  diseño: la del anfitrión manda).
- **Acceso:** código de sala + nombre; **PIN de 4 emojis** opcional
  (paleta fija de 12, validación del anfitrión, reintento con mensaje
  humano; v19.8).
- **Invitación por QR:** `valorave://sala?c=CÓDIGO&m=MODO&p=0|1` — desde
  la cámara/navegador abre la app (BROWSABLE) y prellena la hoja de
  unirse; dentro de la app se escanea con el lector.
- **Offline:** outbox común; los cambios salen al reconectar.
- **v19.9 — flujo de unión:** 1º config de conexión → 2º nombre →
  3º código+PIN → botón unirse; escucha en tiempo real.

## §7 · Alertas

Nueve kinds (centro con anillo a 50): spikes (cooldown 30 min),
targets (histéresis), gap, daily, reminder + centro + descartables.
Recordatorio diario REAL (prefs + claim por día; camino in-app y
WorkManager ±1 h). Motor: `lib/services/alerts.dart` +
`workmanager_service.dart`.

## §8 · Diseño «El Instrumento»

Fuente canónica de tokens y firmas: `lib/core/theme.dart` +
`lib/widgets/ui.dart`. Resumen operativo:
papel-tinta (claro canónico, grafito oscuro), Inter cuerpo / Space
Grotesk display con cifras tabulares, borde `border` SIEMPRE 100 %,
sin gradientes ni tricolor, `label-caps` para rótulos técnicos,
componentes firma (ReadWindow, Stamp, LedgerRow, SkeletonPaper;
RateTicker se retiró en v26 con la cinta del Inicio). **El sistema se
evoluciona; no se reemplaza.**

## §9 · Pantallas y flujos (por módulo)

| Módulo | Pantalla | Flujo esencial |
|---|---|---|
| Bienvenida | `welcome_screen` | 0+país+done; tutorial rejugable (13 pasos) |
| Shell | `main_shell` | 8 rutas / móvil 5 tabs; tasas del país al pie del sidebar de escritorio (RateTicker retirado de Inicio en v26); badge carrito; banner salud; búsqueda global |
| Inicio | `home_screen` | v23: héroe fresco + «vs ayer»; cotización + divisas del foco + tu mes a la vista; «TODO LO DEMÁS · Ver todo» (despliegue progresivo: alertas, tiendas, registros, herramientas, App Widgets); bloque «Libro» (Historial·Tickets·Ajustes) siempre visible al pie; tasas propias «TUS TASAS» con GapChip vs BCV (aplicar = mecanismo manual). v23.2: RateTile compacto (~50dp), Divisas del foco + Tu mes tras «Ver todo», estados offline/primera carga a una línea |
| Conversor | `converter` + reference + history | v23.2 patrón calculadora (depurado en v29): teclado VeKeypad (0-9 · «,» · ⌫, teclas 44) como PISO FIJO abajo — cifra del resultado SIEMPRE a la vista, sin subir/bajar; arriba: fecha (Ayer/Hoy/Mañana/Fecha) + dual input + ajustes ± y acciones (compartir/copiar iconos · Pago Móvil con destino VES: mensaje de cobro); Fuentes/Tabla/Recientes fuera y Notas inline (v29); [Decimales\|Redondear] numMode persiste; puente visible, fecha histórica, notas (5000), recientes 10 |
| Lista | `lista_screen` (+checkout, item_editor) | presupuesto, plantillas, vuelto, dividir cuenta, checkout con foto ticket, sala en vivo. v23.2: captura en 2 filas, héroe 48, frecuentes+totales+plantillas tras «Más» |
| Productos | `products_screen` (+product_sheet) | libro de precios, sparklines, metas, CSV⇄, escáner. v23.2: chips de categoría en una línea deslizable |
| Historial | `history_screen` | asientos por compra, filtros, pág. 20, 2 CSV |
| Constancias | `statement_screen` | estado de cuenta exportable |
| Análisis | `insights_*` | barra segmentada de 4 secciones — Divisas · Inflación · Canasta · Gastos (Gastos alimentado por compras) —, brecha, proyección amortiguada, heatmap con meses con datos, rankings, canasta, exportación. v23.3: barra FIJA (título+secciones+rango fuera del scroll), gráficos a 184, pestañas con Semantics(selected) |
| Sala | `room_*` + `sala_viva` + `join_sheet` + `pin_emoji` | lobby (conexión→nombre→código+PIN), sala viva, PIN emojis, QR |
| Ajustes | `settings_*` | UNA pantalla por secciones (v32: 9 encabezados, cero subpantallas), respaldo replace/merge, tema, fuentes por módulo, Zona de peligro; v23: «Cuentas y Pago Móvil» (máx 4, biométrico opt-in) y «Tus tasas con nombre» (máx 8) bajo Monedas y tasas; v23.3: altas de tasas/cuentas con chrome+kit Ve (VeField/VeInput/VeSelect, pie VeBtn) |
| Escáner | `scanner_screen` | continuo + linterna + fallback manual + debounce; Productos/Lista consumen |
| Tickets | `tickets_screen` | foto de ticket 1024px ≤12MB, zoom 1–8× |

v23.3 · Chrome de hojas UNIFICADO: las 7 hojas que quedaban crudas
(fuentes del Conversor, export×2, Pago Móvil, alta de tasa propia, alta
de cuenta, calendario histórico, galería de App Widgets) usan
`showVeSheet`/`showVeHalfSheet` — radio 14, asa, cabecera 48 + ✕, pie
con VeBtn. Targets táctiles: botones sueltos 44 (visual 32), steppers de
fila 36.

## §10 · Persistencia y respaldo

Hive 4 cajas JSON; `migrate` + merge tolerante; respaldo JSON
replace/merge manual + **automático semanal con retención 4**
(WorkManager). Round-trip de respaldos viejos garantizado (tests). v23:
customRates y accounts fusionan por id (unión, empate=local) — distinto
del criterio local-only de manualRates. v23.3: el modo REPLACE también
restaura customRates y accounts del respaldo (antes se perdían en
silencio; conteos en el toast de fusión); `detached` hace flush final de
las 4 cajas.

## §11 · Escáner y códigos

Escáner real continuo (cámara) con linterna, fallback manual y debounce;
código de barras abre ficha de producto o alta con código prellenado, o
agrega a la lista con precio vigente. QR de sala: §6.

## §12 · Nativo Android

- **§12.1 — Shortcuts:** 4/4 en el launcher (Lista · Conversor ·
  Escanear · Tasa BCV) + intent `valorave://sala`.
- **§12.2 — AppWidgets:** familia BCV/Paralelo/Brecha por subclassing
  Kotlin (`BcvWidgetProvider`), refresco desde `widget_service.dart`.
- Biometría opcional (puerta de marca al abrir; sin soporte no bloquea).
- Canal deep link `valorave/deeplink` en `MainActivity.kt`.

## §13 · Exportación y compartir

Todo módulo exporta por el componente unificado `export_sheet.dart`
(ExportSpec: formato → compartir|guardar): CSV de compras, CSV de
movimientos, constancias, PNG del conversor, JSON de respaldo,
exportaciones de Análisis. Foto 1024px comprimida ≤12MB; print nativo.

## §14 · Matriz de paridad

La matriz viva con evidencia archivo/test por ítem se registraba en los
archivos de paridad retirados en la consolidación documental
(18 ítems + desviaciones conscientes D1–D5; scorecard histórico por
fase: A modelo/persistencia · B motor/tasas · C pantallas · D nativo,
recuperables del historial git).
Regla: cerrar un ítem de §14 exige evidencia (archivo o test), no
declaración.

---

**Cómo evoluciona este archivo:** con orden del dueño o con desviaciones
conscientes documentadas en `PROGRESS.md` y aceptadas por él. Un cambio
de comportamiento visible SIEMPRE actualiza la § correspondiente en el
mismo commit (Definición de Hecho).
