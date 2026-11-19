# GUI simple «Resumen sin recortes» — design doc (EGM, modo elefante)

*   **Autor:** isaac4722 (dueño) · redactado por Super Z (GLM) como elefante EGM
*   **Estado:** Proposed
*   **Fecha:** 2026-11-20
*   **Método:** Elephant-Goldfish Model (elefante redacta con contexto
    completo; goldfish revisan sin contexto — ver hallazgos aplicados más
    abajo). Plugin: google/elephant-goldfish-model.
*   **Glosario breve:** BCV = Banco Central de Venezuela; SUDEBAN =
    superintendencia de bancos (el «código de banco» del pago móvil);
    LOTTT = ley laboral venezolana; CI = cédula de identidad; dp4 = versión
    histórica del diseño GUI del proyecto (linaje previo, ver
    docs/MIGRACION.md); «el contrato» = AGENT.md (reglas de trabajo del
    repo); «el spec» = docs/PARIDAD.md (auditoría de cobertura);
    TASK-13/16/17 = entradas de progress.md (bitácora append-only);
    manualRates = tasas manuales actuales (sobrescriben una fuente por id,
    sin nombre propio); Fase D = bloque de trabajo nativo Android pendiente
    del spec (widgets de inicio, shortcuts; hoy 1 de 13 widgets hechos);
    sala en vivo = lista compartida en tiempo real
    (3 transportes: servidor socket.io, Nearvy P2P y WiFi local); REA/JADX
    = herramienta de ingeniería inversa + decompilador usados para analizar
    el APK de CalculaYa (artefactos locales del análisis, no auditable desde
    este repo).

--------------------------------------------------------------------------------

## Overview

ValoraVE tiene hoy una GUI densa: shell de 6 pestañas + 8 rutas, cabecera con
4 acciones, Inicio con 14 secciones y un onboarding de 7 láminas. La función
está completa (paridad ~80-84 % contra el spec), pero la superficie visible
abruma. Este diseño **resume la interfaz sin quitar funciones**: reorganiza la
navegación en 5 pestañas con un hub «Más», condensa Inicio en 4 bloques con
despliegue progresivo, unifica el nombre del módulo de conversión y adopta las
3 mejores funciones comunes detectadas al comparar (con ingeniería inversa vía
REA/JADX) contra CalculaYa 1.1.0: teclado calculadora en el conversor,
pago móvil compartible y tasas personalizadas con brecha BCV.

## The Problem

1. **Densidad visual**: Inicio muestra 9 secciones top-level de una vez
   (héroe + 8 `SectionTitle`: cotización, sueldo, tiles de sueldo, divisas
   del foco, alertas, resumen del mes, tiendas, registros recientes,
   herramientas — `home_screen.dart:39-47`). El usuario tarda en encontrar
   la cifra que importa.
2. **Navegación inconsistente**: 6 pestañas (Material recomienda 3-5),
   «Historial» y «Ajustes» sin pestaña, y el mismo módulo llamado de 3 formas
   («Divisas» en el tab, «Conversor» en su cabecera y en el buscador).
3. **Fricción del conversor**: para convertir hay que teclear en campos
   pequeños; para compartir un monto en bolívares con datos de pago no existe
   camino (CalculaYa lo hace con su `share_payment_sheet`).
4. **Base rota**: 4 commits posteriores a TASK-16 (`4505826..4252b1b`)
   dejaron 1.926 errores de análisis (comillas escapadas, paquetes no
   declarados, rutas inexistentes). Ya revertidos en la rama de trabajo.

La solución: una GUI más simple que conserve el 100 % de los módulos y
funciones, adopte lo mejor del comparativo con CalculaYa y corrija los puntos
mal configurados — todo dentro del sistema de diseño «El Instrumento»
(evolucionándolo, sin reemplazarlo; paso 3 del método de AGENT.md).

## Goals

*   G1 — Reducir la primera pantalla visible a lo esencial: Inicio pasa de
    9 secciones top-level a 4 bloques; el resto queda a un toque («Ver
    todo»). Aceptación: 0 scrolls llegan al bloque «Tu mes»; toda sección
    anterior sigue alcanzable en ≤ 2 taps.
*   G2 — Navegación de 5 pestañas (Inicio · Divisas · Lista · Productos · Más)
    con TODOS los módulos accesibles; Finanzas, Análisis, Historial y Ajustes
    viven en el hub «Más» con descripción de una línea.
*   G3 — Un solo nombre por módulo: «Divisas» en tab, cabecera, buscador y
    docs.
*   G4 — Conversor con teclado calculadora (estilo CalculaYa) + fichas de
    montos rápidos + interruptor decimales/redondeo.
*   G5 — Pago móvil: cuentas bancarias propias (banco, tipo, número, CI,
    teléfono) y «Compartir por Pago Móvil» desde el resultado del conversor.
    **Protección obligatoria** (hallazgo goldfish): los datos de cuenta son
    el dato más sensible que guardará la app → ver «Privacidad del dato
    bancario» en el plan técnico.
*   G6 — Tasas personalizadas con nombre (Zelle, Binance, Efectivo…) que se
    muestran junto al BCV/paralelo con su brecha porcentual automática.
*   G7 — Onboarding resumido: 7 láminas → 3 + CTA final; tutorial rejugable
    se conserva.
*   G8 — Cada pieza entra con `flutter analyze` = 0 y suite de tests verde
    (gates del contrato), en commits convencionales en español.

## Non-Goals

*   No se elimina ni oculta permanentemente ninguna función existente: si algo
    deja la vista raíz, queda a máximo un toque adicional (progresión
    «resumir sin quitar»).
*   No se cambia framework, arquitectura (provider + go_router + Hive) ni se
    reemplaza el sistema de diseño «El Instrumento» (solo evoluciona).
*   No se añaden widgets de inicio 1x1 USD/EUR de CalculaYa (backlog Fase D
    existente: 1/13 widgets; requiere Kotlin nativo y va en otra ronda).
*   No se añaden anuncios, compras internas, Firebase ni telemetría (CalculaYa
    los tiene; contradicen la política de privacidad de ValoraVE).
*   No se incluye calculadora aritmética genérica (CalculaYa la trae; fuera
    del dominio «cuánto vale mi dinero» — el encargo «resumir pero sin
    quitar» se refiere a lo existente, no a sumar módulos nuevos de otro
    dominio).

## Open Questions

*   **Q1 — ¿Logos de bancos?** CalculaYa empaqueta ~30 PNG de logos. Para no
    engordar el APK ni mantener assets de terceros, la v1 usa lista textual
    con código SUDEBAN (dato público). Si el dueño quiere logos, se agregan
    después como assets propios. *(Decisión por defecto: texto + código.)*
*   **Q2 — ¿Brecha de tasas personalizadas contra BCV o paralelo?** CalculaYa
    calcula la diferencia contra el BCV. Se mantiene BCV como referencia
    (mismo criterio, dato oficial). *(Decisión por defecto: BCV.)*

## Critical User Journeys (CUJs)

*   **CUJ-1 Verificar tasa y convertir en 10 segundos**
    *   Given: app abierta con tablero cargado.
    *   When: usuario abre «Divisas».
    *   Then: ve héroe BCV/paralelo, teclado numérico grande, fichas
        1/5/10/20/50/100 y el resultado con ruta del cálculo; el toggle
        «redondear» cambia la vista sin recargar.
*   **CUJ-2 Compartir un monto por Pago Móvil**
    *   Given: cuenta configurada en Ajustes → Cuentas (banco, tipo, número,
        CI, teléfono).
    *   When: convierte USD→VES y toca «Compartir Pago Móvil».
    *   Then: sheet muestra monto formateado es-VE + sus datos + código de
        banco, botón copiar y compartir (texto plano; sin apps de terceros).
*   **CUJ-3 Tasas personalizadas con brecha**
    *   Given: tasa «Zelle» definida en Ajustes → Monedas y tasas.
    *   When: abre Divisas o Inicio.
    *   Then: la fila «Zelle» aparece junto a BCV/paralelo con chip
        «+12,4 % vs BCV» (color warn si la prima es alta, neutral si < 5 %).
*   **CUJ-4 Encontrar lo poco frecuente**
    *   Given: cualquier pestaña.
    *   When: toca «Más».
    *   Then: hub con Finanzas, Análisis, Historial, Ajustes y Tutorial/legal,
        cada uno con subtítulo de una línea; las rutas profundas no se pierden
        (go_router igual, estado por rama conservado).
*   **CUJ-5 Onboarding breve**
    *   Given: primer arranque.
    *   When: completa bienvenida → país → 3 láminas → done.
    *   Then: aterriza en Inicio con 4 bloques; el tutorial completo sigue
        disponible en Ajustes → Tutorial y legal.

## Technical Plan

```
Shell (main_shell.dart)
├─ Header: logo+live+frescura · [buscar] [campana] [ajustes]  (3 acciones)
├─ RateHealthBanner (igual)
├─ Ticker solo-Inicio (igual)
└─ NavBar 5 pestañas: Inicio · Divisas · Lista · Productos · Más
     └─ /mas (StatefulShellBranch nuevo, pantalla hub)
          ├─ Finanzas  → /finanzas  (rama existente, sin tab)
          ├─ Análisis  → /analisis  (rama existente, sin tab)
          ├─ Historial → /historial (rama existente, sin tab)
          ├─ Ajustes   → /ajustes   (rama existente, sin tab)
          └─ Tutorial y legal → /legal
```

Las 8 rutas de go_router se conservan; «Más» ES una rama más del
StatefulShellRoute (indexedStack) para no perder estado de Finanzas/Análisis/
Historial/Ajustes al navegar. El hub renderiza botones que hacen
`navigationShell.goBranch(i)`.

```
Conversor (converter_screen.dart)
├─ PageHeader 'Divisas' (nombre unificado)
├─ _DualInput (igual) + fichas rápidas 1/5/10/20/50/100
├─ VeKeypad (NUEVO en widgets/ui.dart: 0-9 · , · ⌫ · C; tipografía
│    tabular Space Grotesk; háptica ligera; respeta disableAnimations)
├─ Toggle fila: [Decimales | Redondear]  (prefs del store)
├─ _RutaCalculo + _TablaFuentes + customRates con GapChip
└─ Acciones: [Compartir PNG] [Compartir Pago Móvil (VES)] [Nota]
```

```
Ajustes (settings_screen.dart)
├─ 1 País · 2 Personalización (compacta: cinta+tema juntos)
├─ 3 Monedas y tasas → editor «Tasas personalizadas» (nombre+valor,
│    lista, máximo 8) + manualRates clásicos
├─ 4 Cuentas y Pago Móvil (NUEVO): banco (lista SUDEBAN), tipo
│    (corriente/ahorro), número 20 dígitos, CI, teléfono; multi-cuenta
├─ 5 Alertas · 6 Respaldo · 7 Tutorial y legal
```

```
Inicio (home_screen.dart) — 4 bloques
├─ B1 Héroe: BCV + paralelo + brecha + hora (compacto, tap = refrescar)
├─ B2 Acciones: [Convertir] [Nueva compra] [Escanear] + divisas del foco
├─ B3 Tu mes: sueldo (derivadas LOTTT) + resumen de gastos
└─ B4 Actividad: recientes (3) + tiendas (3) + «Ver todo» → sección
     completa desplegable (alertas de precios y herramientas incluidas)
```

### Navegación: mapeo exacto tab ↔ rama (hallazgo goldfish #3)

Insertar `/mas` como **rama índice 4** del StatefulShellRoute (orden final:
`/`, `/conversor`, `/lista`, `/productos`, `/mas`, `/finanzas`,
`/analisis`, `/historial`, `/ajustes`). Reglas:

*   Tab activa: ramas 0-3 → tab 0-3; ramas 4-8 («Más» y sus hijos) →
    tab 4 resaltada (hoy `/historial` y `/ajustes` no resaltan nada;
    mejorar eso). El mapeo se hace explícito en `MainShell` con una
    función `tabForBranch(i)`, no por coincidencia de índices.
*   Hijos del hub: se llega con `goBranch(5..8)`; el botón atrás se
    comporta exactamente como hoy en `/historial`/`/ajustes` (sin cambio
    de ciclo de vida del router).
*   `Tutorial y legal` usa `context.go('/legal')` (fuera del shell, igual
    que hoy: `app_router.dart:85`).

### Privacidad del dato bancario (hallazgo goldfish #1 — blocker resuelto)

1.  `android:allowBackup="false"` en AndroidManifest (la app ya tiene su
    propio respaldo JSON controlado por el usuario; evita el Auto Backup
    de Hive en claro a Google Drive).
2.  La sección «Cuentas y Pago Móvil» se protege con el servicio
    biométrico EXISTENTE (`lib/services/biometric.dart`) tras un toggle
    «Bloquear cuentas con huella» (opt-in, default OFF).
3.  El texto legal se actualiza en el MISMO commit: deja de decir «no te
    pide datos personales» y pasa a declarar qué guarda Cuentas, dónde
    (local) y qué comparte el botón (texto plano al compartir).
4.  El sheet de compartir lleva una línea de aviso: «Compartes tus datos
    de cobro con la persona que reciba el mensaje».

### Modelo de datos (extensiones tolerantes, sin migración destructiva)

```dart
// core/models.dart — AppData (nuevos campos con default vacío)
List<CustomRate> customRates;   // [{id, name, bsPerUsd}]
List<PayAccount> accounts;      // [{bankCode, bankName, type, number, docId, phone}]

// fromJson tolerante: ausencia ⇒ const [] (los respaldos viejos cargan igual)
```

`CustomRate.bsPerUsd` aparece en `_TablaFuentes` como **fuente seleccionable**
(kind `custom`, color violeta como manual hoy): al tocarla, el conversor
    convierte con esa tasa (cierra el hallazgo goldfish #5: no hay dos
    mecanismos desconectados — manualRates sigue siendo «sobrescribir una
    fuente por id» y customRates es «tus tasas con nombre», ambas editables
    bajo «Monedas y tasas» con subtítulos distintos). La brecha se calcula
    en display: `(bsPerUsd / bcv - 1) * 100`; si BCV no está disponible
    (primer arranque offline), el GapChip NO se muestra (sin «NaN»).

### Merge de respaldo para las entidades nuevas (hallazgo goldfish #4)

`customRates` y `accounts` hacen **merge por id** (unión, dedupe por id;
    mismo patrón que productos en `backup.dart`), NO el criterio
    «conserva solo locales» de manualRates. Test obligatorio del caso
    «instalación limpia + restaurar con modo merge» conserva las cuentas
    del respaldo.

### Validaciones de cuenta (hallazgo goldfish #6)

*   Número de cuenta: validación **suave** — advierte si ≠ 20 dígitos
    (aviso, no bloqueo; la longitud real varía por banco).
*   CI: admite 5-9 caracteres (V/E + dígitos), aviso suave.
*   Multi-cuenta en el sheet: si hay > 1 cuenta, chips para elegir cuál
    compartir; si hay 1, directa.

### Comparativo con CalculaYa 1.1.0 (evidencia de la ingeniería inversa)

| Función común | ValoraVE hoy | CalculaYa 1.1.0 | Decisión |
|---|---|---|---|
| Conversor | campos duales + ruta + fecha histórica | teclado calculadora + redondeo/decimales | **híbrido**: teclado de CalculaYa + ruta/fecha de ValoraVE |
| Tasas | 15 fuentes + manual sin nombre | BCV + USDT + custom nombradas con brecha BCV | **adoptar nombres + brecha** sobre manualRates |
| Pago móvil | — | cuentas + share sheet | **adoptar** (con código de banco SUDEBAN extra) |
| Historial tasas | Análisis: brecha/devaluación 180d | gráfico + «calcula con tasas históricas» | ValoraVE ya cubre (fecha histórica del conversor); sin cambio |
| Widgets home | 1 (BCV) | 6 (USD/EUR/dual + forecast) | no-goal esta ronda (Fase D) |
| Escáner | códigos de barras | OCR de precios (ML Kit ~6,7 MB/ABI) | ValoraVE mantiene el suyo (más liviano) |
| Lista compras | sala en vivo 3 transportes | compartir carrito estático | ValoraVE superior; sin cambio |
| Onboarding | 7 láminas | directo | **resumir a 3** |
| Anuncios/compras/FCM | — | sí | no adoptar (privacidad) |

### Correcciones de configuración detectadas

1. Nombre del módulo inconsistente (Divisas/Conversor) → unificado a
   «Divisas» (tab, PageHeader, buscador, docs, tests).
2. 6 pestañas → 5 (guía Material 3-5 destinos; pantallas pequeñas).
3. Toggle de tema en cabecera duplica Ajustes→Apariencia → sale de la
   cabecera (queda en Ajustes); cabecera 4→3 acciones.
4. `_slides` del onboarding: 7 textos largos → 3 concisos.
5. Commits corruptos post-TASK-16 → revertidos (hecho, base verde).

## Alternatives Considered

*   **A1 — Dejar 6 pestañas y solo densificar Inicio.** No resuelve el exceso
    de destinos ni la inconsistencia; el encargo pide «GUI más simple».
    Rejected by author: no cumple G2.
*   **A2 — NavDrawer lateral (cajón).** 2 gestos para todo, peor descubrimiento
    en móvil, rompe el patrón dp4 de tabs stateful. Rejected by author: más
    taps que el hub «Más».
*   **A3 — Adoptar OCR de precios de CalculaYa (ML Kit).** Añade ~6,7 MB por
    ABI y un escaneo más lento; el escáner de códigos actual cubre el caso
    principal. Rejected by author: coste/beneficio.
*   **A4 — Rediseño completo tipo «Linear» con shadcn_ui + lucide (lo que
    intentaron los commits rotos).** Viola el paso 3 del método de AGENT.md
    («sin cambiar framework, arquitectura ni sistema visual — solo
    evolucionarlos»), añade 2 dependencias nuevas y reescribe pantallas
    enteras. Rejected by author: contrato.
*   **A5 — Quitar secciones de Inicio sin más.** El encargo dice «resumir
    pero sin quitar»; el despliegue progresivo conserva todo.
    Rejected by author: contradice el encargo.

## Detailed Implementation

Commits (uno por pieza, cada uno con analyze 0 + tests verdes):

1.  **`feat(shell): 5 pestañas + hub Más y cabecera de 3 acciones`**
    *   `lib/features/shell/main_shell.dart` — 6→5 tabs con mapeo
        explícito `tabForBranch` (ver sección Navegación), `_Header` pierde
        el toggle de tema (queda búsqueda+campana+ajustes), tab «Divisas».
        Rationale: G2/G3, densidad de cabecera.
    *   `lib/features/more/more_screen.dart` (NUEVO) — hub con 5 entradas
        (Finanzas, Análisis, Historial, Ajustes, Tutorial y legal) con
        subtítulo de una línea cada una. Rationale: G2.
    *   `lib/widgets/app_router.dart` — rama `/mas` insertada en índice 4;
        las 9 ramas se conservan. Rationale: conservar estado por rama.
    *   `test/widgets_test.dart` — tests de tabs actualizados (5 pestañas,
        hub navega, etiqueta «Divisas»). Rationale: G8.
2.  **`feat(home): inicio de 4 bloques con despliegue progresivo`**
    *   `lib/features/home/home_screen.dart` — reordena las 9 secciones
        top-level en B1-B4; `_AlertasPrecios`, `_TusTiendas`,
        `_RegistrosRecientes`, `_Herramientas` quedan tras «Ver todo»
        (ExpansionTile del sistema, sin widget nuevo). Rationale: G1 sin
        quitar (A5).
3.  **`feat(converter): teclado VeKeypad + fichas rápidas + redondeo`**
    *   `lib/widgets/ui.dart` — `VeKeypad` (números tabulares, `,` decimal
        es-VE, ⌫, C, TapScale 0.96, háptica `selectionClick`, respeta
        `MediaQuery.disableAnimations`). Rationale: G4, mejor patrón de
        CalculaYa.
    *   `lib/features/converter/converter_screen.dart` — fichas
        1/5/10/20/50/100, toggle Decimales/Redondear (persistido en settings
        como `numMode`), renombra cabecera a «Divisas». Rationale: G3/G4.
    *   `lib/core/models.dart` + `lib/data/store.dart` — settings.numMode
        ('decimales'|'redondeo', default 'decimales', fromJson tolerante).
    *   `test/widgets_test.dart` + `test/store_test.dart` — keypad escribe,
        fichas ponen monto, toggle persiste. Rationale: G8.
4.  **`feat(tasas): tasas personalizadas nombradas con brecha BCV`**
    *   `lib/core/models.dart` — `CustomRate {id, name, bsPerUsd}` +
        `AppData.customRates` tolerante. Rationale: G6, datos.
    *   `lib/data/store.dart` — CRUD customRates (máx 8, id uuid), merge de
        respaldo: mantiene las locales (mismo criterio que manualRates).
    *   `lib/features/settings/settings_screen.dart` — editor en «Monedas y
        tasas» (nombre + Bs/USD, lista con borrar).
    *   `lib/features/converter/converter_screen.dart` (`_TablaFuentes`) +
        `lib/features/home/home_screen.dart` — fila por tasa custom con
        `GapChip` (nuevo widget en ui.dart: «+12,4 % vs BCV», color semántico
        warn > 5 %, neutral < 5 %). Rationale: G6.
    *   `lib/data/backup.dart` — export/import incluye customRates.
    *   tests: CRUD, brecha, merge, límite 8. Rationale: G8.
5.  **`feat(pago-movil): cuentas propias, biométrico y compartir monto`**
    *   `lib/core/models.dart` — `PayAccount {bankCode, bankName, type,
        number, docId, phone}` + `AppData.accounts` tolerante. Rationale: G5.
    *   `lib/core/banks_ve.dart` (NUEVO) — catálogo SUDEBAN (código + nombre,
        ~40 bancos, dato público; sin logos, Q1).
    *   `lib/data/store.dart` + `lib/data/backup.dart` — CRUD + merge por id.
    *   `lib/features/settings/settings_screen.dart` — sección «Cuentas y
        Pago Móvil» (multi-cuenta, validación suave, toggle biométrico con
        `lib/services/biometric.dart`).
    *   `lib/features/converter/converter_screen.dart` — botón «Compartir
        Pago Móvil» cuando el destino es VES: sheet con monto es-VE + datos +
        código de banco + aviso de sensibilidad + selector de cuenta;
        copiar y compartir texto plano. Rationale: G5.
    *   `android/app/src/main/AndroidManifest.xml` — `allowBackup="false"`.
    *   `lib/features/legal/legal_screen.dart` — texto de privacidad
        actualizado (qué guarda Cuentas y qué comparte). Rationale: hallazgo
        goldfish #1 (el texto actual quedaría falso).
    *   tests: validaciones suaves, formato del texto compartido, merge por
        id, fresh-install + merge. Rationale: G8.
6.  **`feat(onboarding): 3 láminas y CTA`**
    *   `lib/features/welcome/welcome_screen.dart` — `_slides` 7→3 (Tasas,
        Herramientas del día a día, Tus datos contigo) + CTA final; pasos de
        país y done intactos. Rationale: G7.
    *   `test/widgets_test.dart` — onboarding actualizado. Rationale: G8.
7.  **`docs: README, CHANGELOG, DESIGN-SYSTEM y progress.md`**
    *   `README.md` (tabla de módulos con hub Más), `CHANGELOG.md`
        (1.0.3-beta+4), `docs/DESIGN-SYSTEM.md` (VeKeypad + GapChip como
        firmas), `progress.md` (entrada TASK-17 con plantilla del contrato),
        `pubspec.yaml` (versión 1.0.3-beta+4). Rationale: paso 6 del método.

Archivos que NO cambian: `lib/features/room/`, `lib/features/scanner/`,
`lib/features/products/`, `lib/features/history/`, `lib/features/finance/`,
`lib/features/insights/`, `lib/features/statement/`, `lib/features/legal/`
(solo se enlaza desde Más), `server/`, `android/` (widget BCV intacto),
workflows de CI.

Riesgos y mitigación (actualizados con los hallazgos goldfish):
*   Dato bancario en claro → plan completo en «Privacidad del dato
    bancario» (allowBackup=false + biométrico opt-in + texto legal + aviso
    en el sheet).
*   Mapeo tab↔rama → función explícita `tabForBranch`; ramas hijas del hub
    resaltan «Más»; back sin cambios respecto al comportamiento actual.
*   Merge de respaldo → unión por id para customRates/accounts (no el
    criterio local-only de manualRates).
*   Tests de widgets que dependen del orden de tabs/labels → se actualizan
    en el MISMO commit (no se debilitan: se re-escriben contra la nueva UI).
*   Regresión del bug del router (TASK-13) → no se toca el ciclo de vida
    del GoRouter; «Más» es solo una rama adicional.
*   Accesibilidad del VeKeypad → blancos ≥ 48 dp, `Semantics` por tecla
    (etiqueta + trazo), orden de foco lógico; GapChip se oculta si BCV
    no está disponible.
*   Densidad del conversor en pantallas pequeñas → el keypad es plegable
    (botón teclado en el campo activo) y la columna sigue el orden:
    héroe → campos → keypad/fichas → ruta → tablas.
*   Backup: campos nuevos ausentes en JSON viejos ⇒ defaults vacíos
    (mismo patrón tolerante existente; round-trip test).

### Revisión goldfish aplicada (registro EGM)

*   Comprensión (egm-comprehension): veredicto SÍ comprensible; 4 Should
    fix (glosario dp4/REA/Fase D/contrato) + 6 nits → resueltos con el
    glosario breve del encabezado y glosas inline.
*   Crítica de diseño (egm-design): veredicto CONDICIONAL con 1 blocker
    (privacidad del dato bancario) + 5 should fix → resueltos: sección
    «Privacidad del dato bancario», mapeo tab↔rama explícito, merge por
    id, métrica G1 corregida (9 secciones top-level), validaciones
    suaves + selector de cuenta, cita corregida (paso 3 del método),
    `/legal` fuera del shell, evidencia CalculaYa etiquetada como
    análisis local.
