# progress.md · Registro de turnos de agentes

Documento para agentes únicamente: no se enlaza desde el README ni
sustituye la documentación humana. Cada turno añade una sección al final
con la plantilla de `AGENT.md`.

---

## [TASK-0] Arranque · repo orfanado · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Rescate de `assets/brand/` (icon.png, icon-maskable.png,
    splash-logo.png) y `assets/fonts/` (Inter 400–700, Space Grotesk
    500/700) del repo anterior ANTES del borrado.
  - Release `v1.0.0-beta` eliminada vía API autenticada (HTTP 204).
  - 5 tags remotos eliminados (v1.0.0-beta, v15.0.0-beta, v15.1.0-beta,
    v17.1.0, v17.1.1) vía API (HTTP 204 × 5).
  - Commit inicial huérfano: AGENT.md + progress.md + README mínimo +
    arte rescatado + server/lista-sync/ (servidor socket.io del protocolo
    lista-sync portado 1:1 del original v15).
- Decisiones:
  - El servidor lista-sync se porta con el protocolo EXACTO del §6 de
    MVP-CRUD.md (código de 6 letras sin O/I, límites 8/120/16KB,
    granularidad item_*, LWW, presencia 5s/35s, typing 3s).
  - Versionado arranca en `1.0.0-beta+1` (no se hereda v15/v17).
- Gates: no aplica (sin código Dart aún).
- Bloqueos: ninguno.
- Siguiente: Fase 1 · lectura del spec + inventario de fuentes + design
  system; luego Fase 2 · scaffold Flutter + dominio.


---

## [TASK-1..10] Construcción completa de la app · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Fase 1: MVP-CRUD.md leído completo; inventario de dp4/dp6/v15;
    tokens dp4 extraídos → docs/DESIGN-SYSTEM.md.
  - Fase 2: scaffold `flutter create --org ve.valorave`; dominio portado
    (currencies 15 fuentes + RateContext, models tolerantes, fmt es-VE,
    analytics, stores) + datos (AppStore Hive §2, board 4 regiones,
    backup merge §4, rate_history 180d, SSE propio sobre dio).
  - Fase 3: tema «El Instrumento» (tokens dp4 exactos) + lib/widgets/ui.dart
    (Stamp, ReadWindow, LedgerRow, RuleDouble, SourceDot, TrendBadge,
    AnimatedNumber, RateTicker 3×3×3, RateHealthBanner, etc.) + shell 6
    pestañas / 8 rutas + onboarding 0+país+7+done.
  - Fase 4: 10 pantallas completas + búsqueda global + centro de
    notificaciones + constancias (PNG/PDF/print) + respaldos.
  - Fase 5: RoomTransport con 3 transportes (socket.io / Nearby P2P_STAR /
    WiFi LAN UDP+TCP) + protocolo lista-sync compartido + outbox +
    server/lista-sync (Bun/Node) ya en el commit inicial.
  - Fase 6: plugins oficiales (docs/DEPENDENCIAS.md con las 5 trampas),
    manifest con permisos justificados 1 a 1, keystore nuevo como secrets
    (KEYSTORE_BASE64/PASSWORD/KEY_ALIAS/KEY_PASSWORD), firma release via
    keystore.properties, ProGuard, widget BCV en Kotlin.
  - Fase 7: 104 tests verdes (motor, modelos/backup/snapshots, store con
    Hive real, protocolo sala, widget tests de pantallas/componentes) +
    integration_test/app_test.dart (5 flujos, corren local antes de tag).
  - Fase 8: workflows ci.yml (gates) y build.yml (firma+ofuscación+release).
  - Fase 10: README, CHANGELOG, docs/{DESIGN-SYSTEM,DEPENDENCIAS,RELEASE,
    PARIDAD,MIGRACION}.md.
- Decisiones:
  - Hive guarda JSON por clave (migraciones/backup unificados).
  - Currency enum lowercase + code getter uppercase (JSON compatible web).
  - Sin cifras de tasas inventadas: primer arranque sin red = estado
    degradado honesto + editor manual (la web v15 tampoco trae semillas).
  - Desviaciones conscientes D1–D5 documentadas en docs/PARIDAD.md
    (sueldo variable, heatmap pictórico, coach-marks, shortcuts, canvas
    PNG exacto) — el MD manda y quedan anotadas.
- Gates: analyze=0 issues · test=104/104 · build=CI (local sin Android SDK
  por disco; la build real la hace el runner con 16 GB — §Fase 6 nota RAM).
- Bloqueos: ninguno.
- Siguiente: verificación remota de Actions/Release tras el push y el tag.

---

## [TASK-11] Ronda build-fix · widget BCV + integration en host · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - (Ronda previa sin registrar, commits 05773e0/188b700/79d9c21: Gradle
    8.14, AGP 8.11.1, Kotlin 2.2.20, core library desugaring y su sintaxis
    Kotlin DSL — mínimos exigidos por el tooling de Flutter 3.47.)
  - Causa raíz del Build rojo encontrada: `BcvWidgetProvider.kt` importaba
    `es.antonioheres.home_widget.HomeWidgetPlugin` (paquete inexistente y
    además clase de plugin no visible en compile time) → fallaba
    `:app:compileReleaseKotlin`.
  - Fix: el provider lee DIRECTAMENTE el SharedPreferences
    «HomeWidgetPreferences» (verificado en la fuente de home_widget 0.9.x:
    `HomeWidgetPlugin.getData()` es exactamente ese `getSharedPreferences`;
    los String se guardan crudos con `putString`; `setAppGroupId` es no-op
    en Android). Cero acoplamiento al paquete del plugin.
  - proguard-rules.pro: keep explícito de `BcvWidgetProvider`
    (`Class.forName` reflexivo de home_widget) y de `ve.valorave.app.**`
    (workmanager).
  - build.yml: paso del keystore reescrito con env indirection (los secrets
    ya no pasan por heredoc con expansión de shell).
  - main(): seam `documentsDir` + try/catch honesto en notificaciones,
    home_widget y workmanager — el arranque nunca depende de un canal.
  - widget_service.updateBcv: tolerante a canal ausente (errores async no
    manejados imposibles).
  - integration_test: corre en host (`-d flutter-tester`) con directorio
    temporal por test + mock del canal home_widget (solo infra de test);
    expect EUR→COP corregido (arista directa 4500 ⇒ 450.000, el 88,89
    anterior era un error del test, no del motor); flujo UI de onboarding
    con gate de dispositivo.
  - Push 55c8ee0 → Build en runner: SUCCESS (artifact valorave-binarios,
    116 MB: 3 APK + AAB + símbolos, retención 30).
- Decisiones:
  - SharedPreferences directo en lugar de importar el plugin: mismo
    mecanismo documentado en el código del provider.
  - El flujo UI de onboarding en host se salta con motivo registrado: el
    binding live de integration_test no despacha taps a la vista en
    flutter-tester (multi-view 3.47); se valida en emulador/dispositivo
    (docs/RELEASE.md §2) y el onboarding ya está cubierto por widget
    tests de test/.
- Gates: analyze=0 issues · test=104/104 · integration=5/5 en host ·
  build=SUCCESS en runner (main 55c8ee0).
- Bloqueos: entorno de ejecución con filesystem inestable (lecturas que
  a veces vuelven vacías/parciales) y display del shell que traga la
  secuencia literal `[m` — se trabajó con escrituras/lecturas verificadas
  byte a byte. Sin Android SDK local (disco): build real validada por el
  runner de 16 GB (nota §Fase 6).
- Siguiente: re-apuntar tag v1.0.0-beta → Release con 3 APK + AAB →
  verificación de firma → informe final de paridad.

---

## [TASK-12] Release v1.0.0-beta publicada y verificada · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Build en main verde (55c8ee0) tras el fix del widget BCV.
  - Primer intento de tag: el paso de Release falló con 403 «Resource
    not accessible by integration» — `github.token` por defecto es
    read-only en este repo. Fix: `permissions: contents: write` a nivel
    de workflow (privilegio mínimo, futuro-proof aunque ACTIONS_TOKEN
    desaparezca).
  - Tag re-apuntado a 82103f7 → Build del tag VERDE → **Release
    v1.0.0-beta publicada** con 4 assets: 3 APK (armeabi-v7a 23,4 MB ·
    arm64-v8a 27,2 MB · x86_64 29,8 MB) + AAB (63,6 MB).
  - Verificación de binarios (scripts/verify_apk_sig.py, parser propio
    del APK Signing Block — sin dependencias pesadas): los 3 APK con
    esquema v2 PRESENTE, content digest recalculado COINCIDE (íntegros),
    firma RSA-PKCS1v15/SHA-256 VÁLIDA, cert CN=ValoraVE (keystore de
    secrets). AAB válido: manifest + dex + mapa ProGuard (ofuscación).
  - PARIDAD.md ítem 18 actualizado con la evidencia; README con enlace
    de descarga.
- Decisiones:
  - bundletool no disponible local (sin JDK+build-tools completos); la
    validez del AAB se verificó por estructura (zip con base/manifest,
    base/dex, BUNDLE-METADATA/proguard.map). Documentado aquí como
    sustituto honesto de `bundletool build-apks`.
  - apksigner ausente: sustituido por el verificador propio que replica
    la verificación v2 (digests chunked por secciones + firma RSA).
- Gates: analyze=0 · test=104/104 · integration=5/5 host · build=SUCCESS
  (tag 82103f7) · release=publicada y verificada.
- Bloqueos: ninguno nuevo.
- Siguiente: informe final al dueño. Proyecto completo según §10.

---
## [TASK-13] v1.0.1-beta · fix bloqueante del router + icono real + ronda de paridad · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - DIAGNÓSTICO del «solo carga bienvenida y MAS NADA»: `buildRouter()` se
    invocaba dentro de `ValoraApp.build()` con `context.watch<AppStore>()`.
    Cada mutación del store (setCountry del paso 1 del onboarding,
    refresh del poller cada 60 s, cualquier registro) recreaba el
    GoRouter y reseteaba la navegación a initialLocation → usuario
    atrapado en la bienvenida. Confirmado por lectura del código.
  - FIX router: instancia única en `initState` (`late final`), onboarding
    vía `refreshListenable: store` + `redirect` (patrón canónico
    go_router); la raíz ya no observa el store (solo tema).
  - FIX icono: mipmaps legacy eran PNG 100% transparentes (verificado
    píxel a píxel). Regenerados desde assets/brand con script propio:
    legacy 5 densidades + round + adaptive (foreground maskable + bg
    #2749CB + monochrome para themed icons 13+).
  - Escáner REAL: `features/scanner/scanner_screen.dart` (continuo,
    linterna, debounce 800 ms, fallback manual). Cableado en Productos
    (ficha o alta con código prellenado) y Lista (agrega con precio
    vigente). La dependencia mobile_scanner estaba sin usar.
  - Sueldo variable (cierra D1): Settings +salaryMode/base/variable/min/max
    tolerantes en JSON, `effectiveSalary()` (promedio del rango), UI de
    3 modos en Home alimentando tiles y LOTTT.
  - Recordatorio diario real: prefs + AlertEngine.reminderCheck (in-app)
    y camino WorkManager horario (cerrada, ±1 h), claim por día; UI en
    Ajustes → Alertas con horas 7/8/9/12/19/21.
  - StoreSheet (detalle por tienda con an.storeDetail), compartir PNG del
    conversor (captureWidget 1080), barras Finanzas 6/12, héroe con
    frescura fetchedAt + píldora «vs ayer» (snapshots locales).
  - Docs: PARIDAD.md (D1 cerrada, #15/#16/#18 actualizados), CHANGELOG,
    README (descarga + novedades), pubspec 1.0.1-beta+2.
- Decisiones:
  - Redirect de onboarding en el router en lugar de recrearlo: conserva
    la pila de navegación y re-evalúa solo el flag (go_router docs).
  - Recordatorio sin plugin de timezone: ventana horaria exacta por
    claim + tarea horaria existente (precisión ±1 h honesta, sin deps).
  - Sin timers periódicos en el héroe (romperían pumpAndSettle de los
    widget tests): el poller notifica ~60 s y cada rebuild recalcula.
  - Sin sueldo variable NO se rompe nada viejo: fromJson tolerante y
    respaldos anteriores cargan igual (round-trip de tests intacto).
- Gates: analyze/test pendientes del runner (sin SDK local por disco);
  build real en GitHub Actions tras el push (branch → PR → main → tag).
- Bloqueos: npx skills add flutter/agent-plugins dart-lang/skills y
  thiennc-tesoglobal/flutter-skills — timeouts de red en este entorno;
  se trabajó con la familia flutter/* + dart/* ya presente en el agente.
- Siguiente: PR → CI verde → merge main → tag v1.0.1-beta → Release APK.

---
## [TASK-14] Release v1.0.1-beta publicada y verificada · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Ronda analyze-fix tras el primer CI rojo (8 issues): promoción de
    String?→String dentro de closures con `scanned` final local, scheme
    sin usar en el escáner, await sobre void en workmanager.
  - PR #1 CI VERDE (analyze 0 · tests verdes) → merge a main → Build de
    main SUCCESS (compila Android con los iconos nuevos).
  - Tag v1.0.1-beta → Build del tag SUCCESS → **Release v1.0.1-beta
    publicada**: 3 APK (arm64 28,7 MB · armeabi 24,7 MB · x86_64 31,4 MB)
    + AAB 67,0 MB, firmados y ofuscados.
  - Verificación de cierre sobre el APK descargado del release: iconos
    legacy/adaptive con contenido real (centro #2749CB en 48/72/96/144/
    192 legacy y 108/162/216/324/432 foreground), monochrome con glifo V
    blanco (7.892 px), manifest con versionName 1.0.1-beta y label
    ValoraVE.
- Decisiones:
  - El release v1.0.0-beta (icono roto + bug de bienvenida) se conserva
    como historia; README y /releases/latest ya apuntan a v1.0.1-beta.
- Gates: analyze=0 · test=verde (CI runner) · build=SUCCESS (main+tag) ·
  release=publicada y verificada byte a byte.
- Bloqueos: ninguno.
- Siguiente: instalar el APK en dispositivo y validar el flujo dorado
  (onboarding completo → Inicio); pendientes D2/D3/D4 (heatmap pictórico,
  coach-marks, shortcuts nativos).

## TASK-15 · v1.0.2-beta — paridad contra el spec cerrado MVP-CRUD.md

- Auditoría de 4 frentes (modelo/store · motor/tasas/alertas · 9
  pantallas · diseño/nativo) con evidencia file:line. Scorecard completo
  y honesto en docs/PARIDAD-MVP-CRUD.md: global pasó de ~65-70 % a
  ~80-84 %.
- Bugs de datos corregidos: addPurchase sin id (CRÍTICO: borrar una
  compra eliminaba el historial completo y el merge descartaba compras),
  setCountry→conversor, snapshotSeries days, resetAll §2.5, dedupe
  importProducts, rate-health >15 min real (§5).
- Diseño §8: héroes 48-64 px tabulares, sombras firma, PageTransition
  (slide 18/10 + fade, kEaseVe), header de marca (LogoMark+flag+live+
  frescura), bordes 100 %, Stamp 8 %, Space Grotesk en titulares,
  ticker anti-CLS, splash #F7F8F9/#121417 con logo, TapScale.
- Flujos §9 reales: Ayer/7d histórico, shareTotals PNG, StoreSuggest,
  importar CSV, editar/eliminar registros, ticket foto visible con zoom
  y share, finanzas 01→02→03 con confirm y mes previo, sueldo /176
  LOTTT + copySalary, Divisas del foco, Alertas de precios,
  autoRefresh, APP_VERSION «17.1», scanner zoom+vibración, constancia
  PNG real, AlertEngine→centro de notificaciones.
- Validación: PR #2 → CI gates (analyze 0 · test verdes) → merge a main
  (5b81ec7) → tag v1.0.2-beta → Build SUCCESS → Release publicada con
  3 APK (arm64 27,5 · armv7 23,7 · x86_64 30,1 MB) + AAB 64,1 MB.
  Verificado el APK del release: versionName 1.0.2-beta, label ValoraVE,
  splash embebido (drawable-nodpi, obfuscado por resource shrink).
- Pendiente (honesto, ver §3 del scorecard): quick_actions (4 shortcuts),
  widgets 2-13, biometría toggle, SSE vivo, heatmap/proyección en
  Análisis, ruta EUR 4 tramos, Decimal exacto, migración v1→v12 en cadena.

---
## [TASK-16] Verificación del contrato AGENT.md · entorno configurado y repo reconstruido · 2026-09-24 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - AGENT.md y progress.md leídos COMPLETOS antes del turno (Regla 1).
  - Auditoría de cumplimiento del contrato sobre main (7e8284d):
    Regla 5 OK — sin mocks en lib/, sin AppStateScope, sin directorio
    web/ ni patrones web (localStorage/ServiceWorker/indexedDB), sin
    tokens/keys en código (grep con evidencia); versión 1.0.2-beta+3
    dentro del rango 1.x.y-beta+z; commits en español con conventional
    commits (única excepción histórica 9238b19 «Set up devcontainer…»,
    generado por el asistente de devcontainer de GitHub, no por un turno
    de agente).
  - Entorno configurado desde cero: Flutter 3.47.5 stable (Dart 3.13.4)
    instalado y verificado — cumple `sdk: ^3.9.2` de pubspec y coincide
    con el tooling registrado en TASK-11 (Gradle 8.14/AGP 8.11.1).
  - Repo reconstruido: `flutter pub get` OK (150 deps, lockfile intacto
    y reproducible) · `flutter analyze` 0 issues · `flutter test`
    107/107 verdes (la suite creció de 104 → 107 desde TASK-15).
  - Hallazgo H1 (Regla 4): `MVP-CRUD.md` — la «única fuente de verdad
    funcional» — NO está en main; solo existe en el linaje antiguo
    (rama remota fix/v1.1.0-dp4-paridad, commit 08360df). Ocho docs lo
    citan (AGENT.md, PARIDAD*, MIGRACION, DESIGN-SYSTEM, CHANGELOG,
    server README). No se restauró unilateralmente: el spec puede ser
    privado y tocarlo sin encargo expuesto violaría el paso 1.
  - Hallazgo H2: la rama remota fix/v1.1.0-dp4-paridad es el linaje
    histórico v15/v19 (380 archivos, +53k líneas) e incluye web/ con
    patrones prohibidos por la Regla 5 — se deja SOLO como referencia;
    prohibido fusionarla tal cual.
- Decisiones:
  - No se tocó código: el encargo fue verificar/configurar/reconstruir;
    los gates ya pasaban y no había nada que corregir (auditoría verde
    a la primera — no se debilitó nada).
  - Sin Android SDK local (disco 9,3 GB tras instalar Flutter; igual
    criterio que TASK-11..15): la build firmada real la ejecuta el
    runner de Actions en el push de este commit.
- Gates: analyze=0 issues · test=107/107 · build=OK — paso 8 verificado
  sobre 126c77e: CI success (gates en runner, stable 3.47.5) y Build
  success (APK/AAB firmados) · runs 36023706765 / 36023706793.
- Bloqueos: ninguno.
- Siguiente: decidir con el dueño el destino de MVP-CRUD.md (restaurar
  en main desde el linaje antiguo vs. mantenerlo externo) y plan de
  fusiones para el linaje dp4 (saneado previo obligatorio).

---

## [TASK-17] v1.0.3-beta · GUI simple «resumen sin recortes» con EGM y comparativa contra CalculaYa · 2026-11-20 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - AGENT.md y progress.md leídos COMPLETOS antes del turno (Regla 1).
  - Base rota detectada y reparada: los 4 commits posteriores a TASK-16
    (4505826..4252b1b) dejaron 1.926 issues de analyze (comillas escapadas
    `\'`, imports de paquetes no declarados shadcn_ui/lucide_icons_flutter,
    rutas inexistentes). Revertidos en la rama de trabajo antes de tocar
    nada; base verde restaurada (analyze 0 · 107/107).
  - Ingeniería inversa de CalculaYa 1.1.0 (APK .apks de 49,4 MB) con REA
    (npx rea-agents@6.9.0 + jadx-headless-mcp 0.7.1): package
    com.juanalvarez.calculadorabcv, Flutter/Dart 3.13.5, 9 pantallas
    (home/calculator/arithmetic/history/utilities/payment/scan/settings/
    piracy_block), 6 widgets de inicio (USD/EUR/Dual + forecast), pago
    móvil con share sheet, tasas custom (Zelle/Binance/Remesas) con brecha
    BCV, OCR de precios ML Kit (~6,7 MB/ABI), anuncios+compras+FCM
    (rechazados por privacidad). Evidencia local: strings del snapshot
    Dart + manifiesto decodificado.
  - Design doc EGM modo elefante (docs/designs/2026-11-20-gui-simple.md):
    overview/problem/goals/non-goals/CUJs/plan/al alternatives/implementation,
    redactado con el método google/elephant-goldfish-model y revisado por
    2 goldfish SIN contexto (personas egm-comprehension y egm-design).
    Hallazgos resueltos en el doc: blocker de privacidad del dato bancario
    (allowBackup=false + biométrico opt-in + texto legal + aviso en sheet),
    mapeo tab↔rama explícito, merge por id, métrica G1 (9 secciones
    top-level), validaciones suaves de cuenta, cita corregida (paso 3 del
    método), /legal fuera del shell, glosario.
  - Implementación (una pieza por commit, gates en cada una):
    1. shell 6→5 pestañas + hub «Más» (/mas como rama índice 4,
       tabForBranch explícito) + cabecera 3 acciones + nombre «Divisas».
    2. Inicio 9 secciones → 4 bloques con despliegue progresivo
       («Ver todo»: alertas, tiendas, registros, herramientas).
    3. VeKeypad (52 px, tabulares, háptica, Semantics) + fichas
       1/5/10/20/50/100 + ajustes relativos bajo el teclado + toggle
       Decimales/Redondear (settings.numMode) + plegado del teclado.
    4. CustomRate {id, name, bsPerUsd} máx 8 + editor en Ajustes + fila
       con GapChip «+x,x % vs BCV» en Divisas (par USD→VES) que al tocar
       aplica la tasa como fuente manual VES (motor intacto).
    5. PayAccount + catálogo SUDEBAN (25 bancos, texto+codigo) + sección
       «Cuentas y Pago Móvil» (máx 4, validación suave, biométrico
       opt-in) + botón «Pago Móvil» en Divisas (VES) con sheet (monto
       es-VE + datos + selector de cuenta + copiar/compartir) +
       allowBackup=false + texto legal actualizado.
    6. Onboarding 7→3 láminas concisas (país y done intactos).
    7. Docs: README (tabla de módulos con hub), CHANGELOG 1.0.3-beta+4,
       DESIGN-SYSTEM (firmas VeKeypad/GapChip), pubspec 1.0.3-beta+4.
- Decisiones:
  - «Resumir sin quitar»: todo lo que salió de la vista raíz quedó a un
    toque (hub Más, «Ver todo», ajustes relativos bajo el teclado).
  - Las tasas propias usan el mecanismo manual EXISTENTE del motor al
    seleccionarse (ves-manual): cero cambios en el core de conversión.
  - Merge de customRates/accounts por id (unión, empate=local), distinto
    del criterio local-only de manualRates (hallazgo goldfish #4).
  - Sin logos de bancos (Q1: texto + código SUDEBAN, dato público).
  - Anuncios/compras/FCM/OCR de CalculaYa NO adoptados (privacidad y
    peso); widgets 1x1 USD/EUR quedan en el backlog de Fase D.
  - Toggle de tema fuera de la cabecera (vive en Ajustes→Apariencia).
- Gates: analyze=0 issues · test=123/123 (107+16 nuevos) en cada commit.
- Bloqueos: el entorno de ejecución no mantiene procesos en background
  (descargas/npx relanzados en primer plano). Sin Android SDK local:
  la build firmada la valida el runner de Actions (paso 8).
- Siguiente: push de feat/gui-simple-egm → CI → PR a main → tag
  v1.0.3-beta → Release; pendiente del backlog: widgets 1x1 USD/EUR
  (Fase D), quick_actions, heatmap de Análisis.

---

## [TASK-17b] Cierre de release v1.0.3-beta · 2026-11-20 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Push de feat/gui-simple-egm → PR #3 → CI VERDE (analyze 0 · test 123/123
    en el runner con Flutter 3.47.5) → merge a main (26a19e9).
  - Fix de CI necesario: el runner resolvía 'channel: stable' a Flutter
    3.50.0, que DEPRECA package:flutter/material.dart → 23 infos en TODA
    la app (gate analyze != 0, fallaba cualquier PR). Fijados ci.yml y
    build.yml a flutter-version 3.47.5 (entorno documentado TASK-16;
    material_ui no existe en 3.47.5, verificado localmente — migrar es
    tarea propia del día que se suba el SDK). Commit 510385d.
  - Build de main SUCCESS → tag v1.0.3-beta → Build del tag SUCCESS →
    **Release v1.0.3-beta publicada y marcada latest**: 3 APK firmados
    (arm64 27,9 MB · armeabi-v7a 24,1 MB · x86_64 30,5 MB) + AAB 64,9 MB.
  - Verificación del APK publicado con REA: package ve.valorave.app,
    versionName 1.0.3-beta (versionCode 2004), firma con esquemas
    consistentes (schemes_agree_on_signer=true, digests coinciden) y
    permiso USE_BIOMETRIC presente para el candado de Cuentas.
- Gates: analyze=0 · test=123/123 (runner + local) · build=SUCCESS (main
  26a19e9 y tag v1.0.3-beta) · release=publicada, latest y verificada.
- Bloqueos: ninguno.
- Siguiente: instalar v1.0.3-beta en dispositivo y validar el flujo
  dorado (onboarding 3 láminas → Inicio 4 bloques → Divisas con teclado →
  Pago Móvil). Backlog: widgets 1x1 USD/EUR (Fase D), quick_actions,
  heatmap de Análisis, migración a material_ui cuando toque subir el SDK.
