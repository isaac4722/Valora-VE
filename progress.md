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
## [DOC-AGENT-V2] AGENT.md v2 — método de 9 pasos + propagación a todas las ramas · 2026-09-13
- Agente: Super Z (GLM)
- Hecho: AGENT.md v2 con §Método de trabajo (ciclo obligatorio en 9 pasos:
  analiza → consulta web → aplica → audita → punto de control → documenta →
  guarda → Actions → cierra); README §Documentación ahora enlaza AGENT.md y
  progress.md; refs rotas §5.3/§5.4/§5.5 corregidas a Reglas 3/4/5 en
  docs/RELEASE.md y docs/PARIDAD.md; AGENT.md v2 cherry-pickado a TODAS las
  ramas (main 05e0e38, v1.0.1 a54bfcf, v1.0.2, test fccd28b).
- Decisiones: (1) nombre AGENT.md se mantiene — es la convención ya
  establecida y referenciada por docs; (2) método como lista numerada
  concisa (mejores prácticas AGENTS.md verificadas en la web: corto,
  imperativo, específico del repo, con comandos de verificación); (3) en
  test solo va AGENT.md v2 — su README es de otra era sin docs/ ni sección
  Documentación, y el commit de enlaces crearía refs rotas (cherry-pick
  abortado limpiamente); (4) entrada de progress.md solo en la rama
  activa (la bitácora no se replica en ramas archivadas).
- Gates: analyze=N/A (solo docs) · test=N/A (solo docs) · build=CI tras push
- Bloqueos: ninguno
- Siguiente: Ola 1 del protocolo v2 (walkthroughs coach-marks + país en
  bienvenida), sujeto a orden del dueño.

---
## [RECHECK-V17.6] Recheck ordenado por el dueño · auditoría progress/docs ↔ código · 2026-09-13 UTC
- Agente: Super Z (GLM)
- Encargo: auditar progress.md, verificar que TODO lo declarado está
  aplicado en el código de `fix/v1.1.0-dp4-paridad` (ciclo 9P completo),
  corregir lo que falle, documentar, compilar y cerrar.
- Hecho:
  - **Auditoría completa de progress.md (TASK-0..15 + DOC-AGENT-V2)
    contra el árbol real, con evidencia file:line. Veredicto: todo lo
    declarado EXISTE y está aplicado.**
  - Ronda 1.1.0-dp4 verificada 7/7: quick_actions 4/4
    (`lib/services/quick_actions.dart` + cableado en `main.dart:86`),
    `Decimal` exacto en `cartTotals`/`computeChange`
    (`lib/core/analytics.dart:27/51`), «Probar aviso» con notificación
    Android real + centro interno (`settings_screen.dart:776`), cabecera
    solo-nombre dp4 (`main_shell.dart:275`), héroe con `ReadWindow`
    displayNum 38 (`home_screen.dart:220`), búsqueda global a pantalla
    completa con fix dp5 (`GlobalSearchScreen` por `main_shell.dart:330`),
    bienvenida `PageView` 3 páginas (`welcome_screen.dart:91`).
  - Ronda v17.6 RECHECK verificada 6/6: `VeInk` como
    `ThemeExtension<VeInk>` registrado (`theme.dart:80/245`),
    `LoadingState`/`ErrorState`/`OfflineState` (`ui.dart:557/604/655`),
    escáner con `scanWindow` 72 %×32 % + `errorBuilder`
    (`scanner_screen.dart:106/110`), héroe salida 56/entrada 40 + swap
    centrado real (`converter_screen.dart:713/653/797`), date-picker que
    fusiona serie remota 180 d en vivo (`seriesForSource`,
    `converter_screen.dart:191`), Inicio con spinner/wifi_off/cloud_off
    por rama real (`home_screen.dart:377-401`).
  - v17.5 (showToast unificado en 10+ archivos, `CurrencyTag`
    `ui.dart:1379`), v17.4 (tickets, `dynamic_color`, diagnóstico de
    fuentes) y v17.2 (`offlineMode` `store.dart:201`, walkthroughs con
    replay `settings_screen.dart:951`) verificadas por muestreo con
    evidencia.
  - Claims estructurales TASK-11/13/15: router único `late final` +
    `refreshListenable` (`main.dart:76`, `app_router.dart:45`),
    `RateHealthBanner` montado (`main_shell.dart:96`), respaldo semanal
    con retención 4 (`workmanager_service.dart:20/118`),
    integration_test 5 flujos, protocolo server §6 con límites
    8/120/16KB + presencia/typing (`server/lista-sync/index.ts`).
  - Reglas del contrato: R5 LIMPIA (0 mocks en lib/, 0 `AppStateScope`,
    0 patrones web, 0 tokens/keys) · R7 LIMPIA (35 dependencias, todas
    de pub.dev, ninguna git:/path:).
  - Vía API (token del dueño): CI y Build VERDES en fb93678 (2026-09-13);
    AGENT.md v2 presente en las 5 ramas; latest release = v1.0.2-beta con
    4 assets. Logs del run verde extraídos: analyze «No issues found!
    (ran in 19.4s)» · test «🎉 107 tests passed.».
  - Falso positivo descartado: el trigger «branches: ain,...» de los
    workflows es el display comiéndose la secuencia `[m` (bug ya
    documentado en TASK-11); los bytes reales son
    `[main, 'fix/v1.1.0-dp4-paridad']` — YAML correcto.
  - Correcciones aplicadas por el recheck: (1) pubspec 1.5.0+12 →
    **1.5.0-beta+13** — restaurado el patrón `1.x.y-beta+z` de la Regla 5,
    con comentario honesto (el viejo mentía «v1.0.1-beta+2»); (2) README:
    «Descarga actual» v1.0.1-beta → v1.0.2-beta (el release real,
    verificado por API); (3) CHANGELOG: entrada de esta ronda arriba del
    todo. Cero cambios en lib/ y test/ — la auditoría no halló defectos
    de código, solo de contrato/documentación.
  - **Reconstrucción de bitácora (Regla 2)** — estas rondas estaban en
    git+CHANGELOG pero SIN entrada en progress.md; quedan registradas
    aquí con su rango real de commits, sin falsificar fechas:
    - 1.1.0-dp4 (068e89e..ddb4abd, 2026-09-10): paridad visual dp4 +
      quick_actions + Decimal + «Probar aviso» · CHANGELOG §1.1.0-dp4+6.
    - v17.2 (72b9799..58c001e, 2026-09-11): offline-first, sala
      full-screen 4 modos, conversor dp, walkthroughs por módulo ·
      CHANGELOG §1.2.0+7.
    - v17.4 (2d00a39..97bae53, 2026-09-11): GUI dp6 — tickets, Material
      You, diagnóstico de fuentes · CHANGELOG §1.3.0+10.
    - v17.5 (99756c6..0d71911, 2026-09-11): toast unificado, CurrencyTag,
      alertas de subida · CHANGELOG §1.4.0+11.
    - v17.6 RECHECK (6eefaf4..abb6bba, 2026-09-12): los 5 fallos
      confirmados del dueño resueltos · CHANGELOG §1.5.0+12.
    - Rework CI (91d8f26..fb93678, 2026-09-12/13): matriz por ABI
      anti-SIGTERM + cachés (infraestructura, gates ya verdes).
- Decisiones:
  - Versionado: la escalera 1.2.0+7→1.5.0+12 violaba la letra de la
    Regla 5 (perdió el prerelease `-beta`); se restaura como
    `1.5.0-beta+13` — misma línea 1.5.0 del CHANGELOG, build siguiente,
    patrón del contrato devuelto (Regla 4: el MD manda).
  - `kAppVersionVisible` «17.6» se CONSERVA: es la versión visible de
    marketing, convención que main ya usaba («17.1» con pubspec
    `1.0.2-beta+3`) — línea distinta del versionado del paquete.
  - Reconstrucción en UNA entrada de recheck en vez de 5 entradas
    retro-fechadas: los rangos de commits son la evidencia y no se
    inventan fechas de turno.
  - Entradas viejas NO se reescriben (Regla 2, append-only). La evidencia
    fantasma de TASK-12 (`scripts/verify_apk_sig.py`, nunca commiteado —
    era artefacto local de aquel entorno) queda anotada aquí, no
    corregida en el pasado.
- Gates: analyze=0 issues («No issues found», 19.4 s) · test=107/107
  («107 tests passed») · build=OK — CI y Build del runner sobre fb93678
  (lib/ y test/ byte-idénticos a este commit). El push de cierre
  re-gatea ambos workflows sobre el SHA nuevo; el turno SOLO cierra con
  verde (paso 8 verificado antes del cierre).
- Bloqueos: ninguno (sin SDK Flutter local por disco — gates en el
  runner, como en turnos anteriores; conteo extraído de los logs reales).
- Siguiente: Ola 1 del protocolo v2 (walkthroughs coach-marks + país en
  bienvenida), sujeto a orden del dueño — igual que quedó en DOC-AGENT-V2.

---
## [TASK-16] v17.7 · cambios pendientes + Ola 1 + reestructura · 2026-09-13 UTC
- Agente: Super Z (GLM)
- Encargo del dueño: «mejores la app en reestructura optimizar ect. Y
  realizar los cambios pendientes. Cuando yo te mencione que lo pase a
  la MAIN lo haces por ahora No» — TODO en fix/v1.1.0-dp4-paridad,
  main intacta.
- Hecho (7 commits, uno por pieza, gates locales ANTES de cada uno):
  - **Motor**: `ConversionPlan` como clase propia con `direct` (true solo
    en arista directa) + ruta EUR de 4 tramos COMPLETA en «Ruta del
    cálculo» (EUR→local→USD→destino con sello por tramo y rótulo del tipo
    de ruta) + `resolveEur().pairId` expuesto. 5 tests.
  - **Análisis 9.7**: rankings de compras por día de semana (barra + día
    fuerte) y por divisa (original + ≈USD) · proyección PUNTEADA DAMP
    (φ 0.85, semántica de predictPrice) sobre el costo de la canasta ·
    heatmap de devaluación 6 meses (cierra D2) · exportGapCsv · histórico
    multi-divisa (hasta 3 fuentes + CSV por columnas). 11 tests de
    helpers puros.
  - **Biometría con toggle** (pendiente «biometría sin toggle»): puerta
    de marca al abrir en main.dart, canCheck verificado antes de activar,
    degradación honesta sin canal. Settings 17.7: biometricLock/sseUrl.
  - **SSE vivo** (pendiente «cliente sin instanciar»): RatesPoller
    conecta RatesStream a /api/rates/stream del despliegue configurado,
    ingesta COMÚN _ingestBoard (mismo camino que el poll, regla
    changeEps, alertas, snapshots, widget), polling como latido,
    reintento 60 s/5 min, apagado en idle, punto de estado + diálogo.
  - **price_targets de producto en 2º plano** (pendiente):
    AlertEngine.checkProductTargets — cruce FRESCO (metSince de hoy o
    meta recién fijada) → canal price_targets + centro, claim por día,
    rearme al subir; cableado in-app (ficha) y workmanager (el
    comentario del dispatcher ya lo prometía). 2 tests del ciclo.
  - **Familia de widgets BCV** (plan subclassing documentado):
    BaseRatesWidget Kotlin + ParallelWidgetProvider + GapWidgetProvider
    (layouts, receivers con etiqueta, brecha en Dart + respaldo Kotlin),
    widget_service refresca los tres.
  - **Ola 1 del protocolo v2**: país EN la bienvenida (página 3 con
    chips; paso obligatorio preseleccionado) + coach-marks por feature
    (cierra D3): valorave.tips-dismissed, puntas ancladas con aro de
    foco, SOLO tras el walkthrough del módulo, 5 cableadas
    (Inicio/Conversor/Lista/Productos/Análisis). Test del ciclo completo
    + test de bienvenida reescrito (CO por chips).
  - **Reestructura**: converter_screen 1515→845 + converter_reference +
    converter_history (parts); settings_screen 1102→211 +
    settings_sections + settings_alertas + settings_system (parts).
    Cero renombres (privacidad de biblioteca compartida), analyze 0,
    suite verde.
  - **Docs**: CHANGELOG 1.6.0-beta+14 · PARIDAD-MVP-CRUD (scorecard
    ~92-94 % global, §3 con los cierres) · PARIDAD (D2/D3/D4 cerradas +
    extras v17.7) · DESIGN-SYSTEM (accentDark #242A32 documentado) ·
    pubspec 1.6.0-beta+14 · kAppVersionVisible 17.7.
- Decisiones:
  - Gates LOCALES por primera vez: SDK Flutter 3.47.4 instalado en el
    entorno (9.3 GB libres) — analyze + suite antes de CADA commit; el
    runner re-verifica (paso 8).
  - Coach-marks disparan SOLO tras el walkthrough del módulo (los
    recorridos v17.2 van primero; 900 ms de respiro) — nunca se apilan.
  - checkProductTargets respeta el ciclo de metSince de addRecord (v13.2):
    anuncia cruces frescos una vez al día; el 2º plano cubre metas fijadas
    sobre precios ya existentes.
  - Parts (no librerías separadas) para la reestructura: movimiento
    mecánico sin renombres, riesgo mínimo, mismo comportamiento.
  - SIN tocar main (orden explícita del dueño) y sin renumerar fuera de
    1.x.y-beta+z: 1.5.0-beta+13 → 1.6.0-beta+14.
- Gates: analyze=0 issues · test=126/126 local (Flutter 3.47.4; 19 tests
  nuevos) · build=Actions tras el push (verificado hasta verde, paso 8).
- Bloqueos: ninguno. Falsos positivos resueltos por el camino: cambios de
  modo 644→755 del clon (core.fileMode off), heredoc que se comió un
  nombre de campo, barrierLabel obligatorio en diálogo descartable.
- Siguiente: decidir si se fusiona a main (SOLO con orden explícita del
  dueño) o se continúa con las olas 2+ del protocolo v2; quedan como
  pendiente honesto: migración v1→v12 como cadena real, canvas
  pixel-perfect de la constancia (D5), split de ui.dart/home/lista,
  medición de rendimiento en dispositivo.

## [TASK-17] v17.8 · tutorial único + fin de Finanzas + IGTF fuera + offline real · 2026-09-14 UTC
- Agente: Super Z (GLM)
- Encargo del dueño: eliminar el tutorial tipo PageView y dejar UN
  walkthrough completo rejugable (los actuales se apilan y se salen de
  pantalla — capturas adjuntas; buscar plugin); incluir los assets de
  banderas; retirar el módulo de Finanzas y reubicar los gráficos de
  gastos en Análisis o Historial alimentados por las compras de Lista sin
  carga manual; eliminar TODA referencia al impuesto histórico; hacer la
  app realmente client-side + offline («constante no se logra»); y
  reaplicar el progress.md completo. TODO en fix/v1.1.0-dp4-paridad, main
  intacta (sin orden explícita de fusión).
- Hecho (5 commits, uno por pieza, gates locales ANTES de cada uno):
  - **98d9a3d · Finanzas fuera + Gastos**: pestaña/ruta/pantalla
    retiradas (shell 6→5); ancla «Gastos» en Análisis (total del rango +
    donut por tienda top-6+Obras + barras por mes) alimentada SOLO por
    compras de Lista (monthSpend/storeSpend puros, +6 tests: orden
    cronológico por bucket —no por etiqueta—, ventana, paidUSD,
    multitienda repartida); Home «Resumen del mes» por compras con delta
    honesto; constancia solo de compras; Transaction/FinanceCategory
    CONSERVADOS para round-trip de respaldos viejos (cero pérdida);
    CRUD de movimientos retirado por muerto; RateModule.finance vivo
    (tasa fichas/compras, etiqueta «Compras y fichas»).
  - **502402d · Tutorial único**: slides PageView de la bienvenida,
    walkthroughs por módulo (v17.2) y puntas Ola 1 ELIMINADOS (sus 2
    bugs de las capturas: overlays apilados por postFrames
    independientes + burbujas con altura estimada 150 px cortadas).
    Nuevo lib/widgets/app_tour.dart sobre tutorial_coach_mark 1.3.4
    (pub.dev): 13 pasos / 6 segmentos que CRUZAN pestañas (navega con
    go_router, espera layout, encadena overlays, restaura pestaña de
    origen), UN overlay a la vez (guard anti-reentrada), alineación con
    el rect REAL del ancla + useSafeArea, banderas reales de
    assets/flags en la tarjeta inicial y en los chips de país de la
    bienvenida; una oportunidad auto por instalación
    (valorave.tour-done, marca antes de mostrar) + replay único desde
    Ajustes; anclas centralizadas en TourKeys + GlobalKeys reales para
    nav-bar/header/hero. Tests: integridad del registro, flag
    una-sola-vez, pipeline E2E (arranque → Saltar → restaura '/').
  - **1f4a295 · Impuesto histórico fuera**: campo v14 de Purchase
    eliminado (constructor/copyWith/toJson/fromJson); respaldos viejos
    lo IGNORAN al parsear y el round-trip no lo re-escribe (+test de
    regresión); hints y comentarios reescritos.
  - **9ac8817 · Offline REAL**: ConnectivityService (connectivity_plus
    7.3.1) tolerante sin canal; RatesPoller come la señal: sin red NO
    consulta (fin de las cargas falsas de 7 s), NO martilla cada 60 s
    (latido y SSE se apagan), al volver la red refresca solo (modo
    offline ELEGIDO y autoRefresh mandan); flag inicial tomado del
    servicio (arranque sin red cubierto); retryNow() con re-consulta
    real; héroe con wifi_off honesto inmediato; RateHealthBanner con
    causa (sin conexión calmado vs >15 min con Reintentar). Tests con
    plataforma falsa inyectada (4: tolerancia, arranque sin red con
    CERO consultas, reconexión con refresco, modo offline manda).
  - **cf39e0a · Reaplicación progress.md**: auditoría MD↔código tras la
    restructura (claims verificados: héroe, quick_actions, Decimal,
    biometría, SSE, widgets, offlineMode); sueldo LOTTT retirado de
    README/PARIDAD (obsoleto desde v17.2 — hallazgo de la auditoría);
    PARIDAD fila 8 🔄, D3 evolucionada, PARIDAD-MVP-CRUD 9.6 RETIRADA.
  - **Este commit**: versión 1.7.0-beta+15 · kAppVersionVisible 17.8 ·
    CHANGELOG v17.8 · esta bitácora.
- Decisiones:
  - Plugin sobre mano propia (orden del dueño «busca un plugin»):
    tutorial_coach_mark 1.3.4 (ago-2026, pub.dev) — posicionamiento por
    ancla real + safe-area; el driver multi-pestaña es nuestro (el
    paquete no navega solo). connectivity_plus 7.3.1 para la señal de
    red. Ambos documentados en DEPENDENCIAS.md (Regla 7).
  - Tour por SEGMENTOS con un overlay por pestaña (no todos los targets
    en un solo run): las anclas de branches no visitados no existen aún;
    navegar-entre-segmentos es lo que hace el tour «completo» de verdad.
  - Desviación de MVP-CRUD §9.6 (Finanzas): la manda la ORDEN EXPLÍCITA
    del dueño (Regla 4); anotada aquí y en PARIDAD-MVP-CRUD.
  - kNavBarKey/kHeaderActionsKey/kHeroRateKey pasaron de const Key a
    GlobalKeys reales (necesarias para medir el rect del tour); los
    widget tests find.byKey siguen verdes.
  - SDK Flutter 3.47.4 reinstalado en el entorno (se perdió entre
    sesiones): gates locales restaurados ANTES de cada commit.
- Gates: analyze=0 issues · test=140/140 local (Flutter 3.47.4; 14 tests
  nuevos) · build=Actions tras el push (paso 8 del ciclo).
- Bloqueos: ninguno. Falsos positivos resueltos: el overlay del tour
  necesita varios ciclos de bombeo (espera por condición, jamás
  pumpAndSettle — el pulso del foco es animación infinita); !timersPending
  corre antes de los tearDown (dispose en el cuerpo del test).
- Siguiente: decidir si se fusiona a main (SOLO con orden explícita del
  dueño). Pendientes honestos que quedan: migración v1→v12 como cadena
  real, canvas pixel-perfect de la constancia (D5), split de
  ui.dart/home/lista, medición de rendimiento en dispositivo.

---
## [TASK-18] v17.9 · APK para cualquier dispositivo · 2026-09-14 (UTC)
- Agente: Super Z (GLM)
- Hecho:
  - Orden del dueño: «te faltó crear para los V8, o no sé si es error de
    compilación; debes crear para cualquier dispositivo (androids viejos,
    nuevos o emuladores) — añádelo al agent.md».
  - Diagnóstico (no era error de compilación): el Build de rama solo
    producía 2 artefactos (arm64-v8a 16,4 MB · armeabi-v7a 15,5 MB —
    verificado por API en el run 34786657206); el APK x86_64 solo se
    compilaba en tags y NO existía APK universal → emuladores y equipos
    de arquitectura desconocida sin binario.
  - `build.yml`: matriz de 4 APK por push (arm64-v8a · armeabi-v7a ·
    x86_64 · universal sin --split-per-abi) + job release (tags) que
    descarga los APK de la matriz del mismo run, los aplana y los
    adjunta TODOS con `fail_on_unmatched_files: true`.
  - Bug latente corregido en el job release: referenciaba
    app-armeabi-v7a/arm64-release.apk que nunca existieron en su
    workspace (softprops los saltaba en silencio) → un tag futuro habría
    publicado una Release mutilada (solo x86_64 + AAB).
  - AGENT.md: nueva Regla 9 (petición expresa) — cobertura total de
    dispositivos, prohibido retirar un ABI sin orden del dueño.
  - README (descarga local, comando universal, 4 APK en release, tests
    140) y docs/RELEASE.md (checklist de publicación) actualizados.
  - **Este commit**: versión 1.7.1-beta+16 · kAppVersionVisible 17.9 ·
    CHANGELOG v17.9 · esta bitácora.
- Decisiones:
  - x86 (32 bits) NO se añade: Flutter no distribuye motor para ese ABI
    desde 2020 — documentado en AGENT.md Regla 9 y en build.yml para
    que no vuelva a preguntarse.
  - Universal por `flutter build apk --release` SIN split (3 ABI en un
    APK ~45 MB): es la respuesta real a «cualquier dispositivo» para
    quien no sabe qué descargar.
  - `needs: apk` en release: garantiza que los artefactos existan antes
    de publicar; si la matriz muere por infra, release se salta (y el
    rerun-failed-jobs lo revive) — preferible a publicar incompleto.
  - Riesgo aceptado: el job universal es el más largo (3 compilaciones
    AOT); reaper del runner ~16-19 min. Mitigado con fail-fast: false +
    upload if: always() + rerun-failed-jobs (precedente v17.8).
  - Cuota de artefactos: ~77 MB/push (4 APK) con retención 30 — dentro
    del límite blando de 500 MB con cadencia actual; a vigilar.
- Gates: analyze/test SIN SDK local esta sesión (se perdió entre
  sesiones otra vez) → gates en Actions sobre este push, único cambio en
  lib/ es la constante de versión (kAppVersionVisible '17.8'→'17.9') ·
  build=Actions con matriz de 4 APK (paso 8 del ciclo).
- Bloqueos: ninguno. YAML validado localmente (pyyaml: matriz y needs
  correctos) antes del commit.
- Siguiente: esperar el run de Actions (CI + Build) y verificar que los
  4 APK suben; luego decidir con el dueño el merge a main (SOLO con
  orden expresa).

## [TASK-19] v18.0 · recheck + 6 encargos · 2026-09-14 (UTC)
- Agente: Super Z (GLM)
- Hecho:
  - Ronda con orden expresa del dueño: RECHECK primero (verificar y
    arreglar ANTES de lo nuevo), luego 6 ítems, QA obligatorio.
  - NOTA de sesión: el entorno se reinició a mitad de ronda y el trabajo
    local no pusheado se PERDIÓ — la ronda completa se reconstruyó desde
    cero sobre 8624671 (v17.9) con esta bitácora como registro único.
  - RECHECK con hallazgos reales corregidos: (1) la bienvenida seguía
    siendo un PageView de 3 páginas → UNA sola pantalla (sin tutorial
    duplicado); (2) el tour medía anclas sin arrastrarlas a la vista →
    motor por-paso con Scrollable.ensureVisible(400ms)+450ms de respiro,
    ancla no montada se salta, guard _busy anti-doble-tap; (3) la clave
    extinta del test de respaldos se llamaba 'igtf' → renombrada
    'clave_extinta_v14' (grep -ri igtf = 0 en todo el repo). Finanzas
    fuera y offline-first verificados OK sin cambios.
  - Ítem 1 (walkthrough fijo): resuelto por el motor por-paso del
    recheck — un solo overlay a la vez, ancla visible antes de medir.
  - Ítem 2 (conversor XE/Wise): fuente+frescura arriba (línea tocable →
    hoja de fuentes con tasas), monto 30px izquierda + selector derecha,
    swap centrado grande, resultado HÉROE 52px FittedBox + «≈ fmtMoney»,
    4 chips ±10%/±100 al mismo ancho (quickAdjustments reordenado),
    _FechaTasas simplificado (solo presets+calendario+banner).
  - Ítem 3 (modos con su tecnología): Bluetooth RFCOMM/SPP REAL —
    BtSppPlugin.kt nativo a mano (MethodChannel+EventChannel; ningún
    paquete pub soporta rol servidor RFCOMM): server multi-invitado,
    cliente con bonding previo (45s), discovery, write 1:1/broadcast.
    BtHubImpl JSON-lines con watchdogs (60s sin datos → host_lost).
    Permisos SOLO del modo elegido (escáner BT únicamente en modo bt;
    CONNECT/SCAN 31+, legacy BLUETOOTH/ADMIN+ubicación <31). Errores
    bt_timeout/bt_connect/unavailable/off con texto humano.
  - Ítem 4 (Sala Viva propia): ruta /sala-viva distinta de /sala
    (config): código+QR+PIN, miembros normalizados (anfitrión arriba,
    «(tú)»), roles host/editor/viewer con gate de viewer en item_*,
    gobierno del anfitrión (renombrar/cerrar/expulsar/cambiar rol),
    eventos room_renamed/room_closed/role_change/your_role/kicked,
    regreso automático a /lista al desconectar y auto-cierre al guardar
    compra (closeAfterPurchase tolerante). RoomController pasa a
    provider de app; Lista gana strip «En sala» + tile con estado.
  - Ítem 5 (toggle): «Modo offline total» → «No consultar API
    automáticamente» (+ paso del tour actualizado).
  - Ítem 6 (generadores): renderOffstagePng (Overlay left:-4000 PINTADO,
    2 frames, rasterizado 3x, ancho acotado) — causa raíz del «No pude
    generar» era capturar un boundary reciclado por el scroll.
    captureWidget endurecido (null limpio, jamás excepción).
    StatementDoc/StatementRow y TotalsDoc públicos: el MISMO widget es
    preview y fuente del PNG. core/version.dart fuente única de versión
    (kAppVersionVisible '18.0'); pie del PDF con versión real (antes
    '17.2' hardcodeado).
  - CI: APK renombrado a valorave-v{version}-build-{AAAAMMDD
    Caracas}-{abi}.apk (y AAB); job release exige los 5 archivos con
    los patrones nuevos.
  - **Este commit**: versión 1.8.0-beta+17 · CHANGELOG v18.0 · esta
    bitácora.
- Decisiones:
  - Puente Kotlin a mano para BT: verificado en pub.dev que ni
    flutter_bluetooth_serial (congelado 2021) ni _plus ni variantes
    exponen rol SERVIDOR RFCOMM — la alternativa era no tener el modo.
  - Escaneo BT solo en modo 'bt' (permisos solo del elegido): pedir
    BLUETOOTH_SCAN a quien no quiere BT sería intrusivo.
  - Guest BT empareja ANTES de conectar: RFCOMM a un dispositivo sin
    emparejar falla o dispara un diálogo a medias; el hub espera el
    bonding (hasta 45s) y luego conecta (15s).
  - Viewer ve pero no toca: el gate vive en emit() (única salida de
    item_*/list_*) — el relé del anfitrión usa emitTo y no se afecta.
  - closeAfterPurchase tolerante: la compra ya quedó guardada pase lo
    que pase; la sala es_State secundario del cierre.
  - renderOffstagePng usa Overlay PINTADO en left:-4000 y no Offstage:
    Offstage no pinta y RepaintBoundary.toImage sale vacío.
  - Sala Viva escucha al controlador (no al transporte): el regreso
    automático cubre host_lost, room_closed, kicked y leave() propio.
- Gates: analyze 0 issues · 142 tests verdes (140 + 2 nuevos: errores
  BT + roles round-trip) con SDK 3.47.4 local reinstalado · build=push
  a Actions con matriz de 4 APK renombrados (paso 8).
- Bloqueos: ninguno. La pérdida de la ronda original por reinicio del
  entorno se resolvió reconstruyendo (8 commits limpios por pieza).
- Siguiente: push → poll CI+Build hasta verde → verificar los 4 APK
  valorave-v1.8.0-build-{fecha}-{abi}.apk → merge a main SOLO con orden
  expresa del dueño.

---
## [TASK-20] v19.0 · 21 encargos del dueño: onboarding en slides, tour propio, tips con reglas, selector de tasa visual, conversor bidireccional, miles en vivo, 1 consulta/región, hive_ce y pantallas reconstruidas · 2026-09-16
- Agente: Super Z (GLM)
- Hecho:
  - Bienvenida PageView 4 slides (avanzar/retroceder, dots, swipe; país se conserva).
  - coach_mark.dart propio (tutorial_coach_mark retirado): foco del rect real, tarjeta con clamping y botones fijos al pie (no se congela); 13 textos reescritos contra pantallas reales; paso sin ancla = tarjeta centrada.
  - app_tips.dart: tips con reglas (tour manda, 2ª sesión, cooldown 6 h, una vez cada uno); 7 tips + sala.qr; TipsTrigger en 4 pantallas + disparador en Sala Viva.
  - rate_sheet.dart: RateTile [Bandera][Nombre][Precio+símbolo] + grupos USD/EUR + showRateSheet + editor manual inline (MoneyField). Inicio/Conversor/Lista/hoja de divisas usan EL MISMO selector; manual accesible desde cualquier interfaz (Ajustes se conserva).
  - Conversor bidireccional (escribir abajo calcula arriba), divisa del otro lado intercambia lados (jamás X→X; plan(from==to)=null + guard en setConverterPair), swap conserva el número.
  - MoneyField (ui.dart): miles en vivo, canon 2 pasadas (setText programáticos ya no se mutilan), onChanged solo con entrada del usuario.
  - board.dart: CO 1 llamada (/v1/cotizaciones) + TRM; BR 1 (/v1/cotacoes). Smoke real: 10 fuentes vivas, 0 degradadas. Conversor histórico persiste puntos consultados (mergeSeries, fix de cascada).
  - hive → hive_ce (2.20.0/2.3.4), misma API, cero migración.
  - PushScreen (ui.dart) para rutas empujadas: notch/barras + botón atrás + espaciado. Sala, Sala Viva y Tickets migradas; 5 modos intactos (Servidor incluido).
  - Ficha de producto: secciones en Cards con divisores + MoneyField; alta agrupada.
  - Lista: total + ≈ USD al lado; Vuelto/Dividir → modal de checkout (AL PAGAR); presupuesto conserva moneda (bug store) + MoneyField.
  - Ajustes: manuales en fila flexible (ancho fijo desbordaba a 320 px — testeado) + editor compartido.
  - Home: fecha «lun 15 sep · 14:30»; héroe/banner con AnimatedSize (cero saltos); manual activa u offline elegido → sin banner de salud; rateOn(preferLocal) sin red.
  - Banderas auditadas: 6/6 assets reales (test), último selector viejo unificado.
- Decisiones:
  - Motor propio vs tutorial_coach_mark: los bugs del dueño (tarjetas cortadas, focos muertos, congelones) venían del paquete; la casa necesita control total del posicionamiento. Sin dependencia extra.
  - plan(from==to)=null cambia el test «rate 1»: la nueva semántica es orden expresa del dueño (100 Bs son 100 Bs).
  - setBudget conserva la moneda con monto 0: el bug real era el reset a VES.
  - Tips por sesiones+cooldown (no inmediatos): «no de una vez tras el tutorial».
- Verificado: analyze 0 issues · 159 tests verdes (nuevos: MoneyField, bienvenida slides, tour propio, tips, rate sheet, push screens, ajustes 320px, banderas, conversor bidireccional) · smoke de red real (10 fuentes) · 15 commits.
- Falta: merge a main PROHIBIDO sin orden expresa del dueño (pase las pruebas).


---
## [TASK-20] v19.0 · DolarApi blindado + es-VE total + sellos + BiSwap + tour propio + sala P2P desde 0 · 2026-09-15
- Agente: Super Z (GLM, agente principal · SDK Flutter 3.47.4 local)
- Hecho:
  - CHECK previo (orden del dueño): endpoints DolarApi verificados en vivo
    (VE/CO/MX/BR 200 OK · BR con claves en portugués · AwesomeAPI con cuota
    agotada desde datacenter — parsers tolerantes a 429). DolarApi ya vivía
    en board.dart e history_api.dart: lo que faltaba era el respaldo del
    tablero vivo fuera de VE.
  - feat(datos): respaldo por región — TRM datos.gov.co (Superfinanciera,
    oficial) · COP mercado AwesomeAPI · MXN Frankfurter · BRL AwesomeAPI
    (USD/EUR). Parsers puros testeables; providers = orígenes reales.
  - feat(fmt): formato es-VE en TODAS las cifras visibles (campo del
    conversor, share texto/tarjeta, alertas, insights, widgets Android con
    parseVe en Kotlin). fmtPlain retirado.
  - feat(tasas): SourceSeal (icono+palabra OFICIAL/MERCADO/PROMEDIO/MANUAL)
    sustituye al SourceDot/rayita; «Mercado» como etiqueta de la categoría
    paralela; pseudo-fuente «1 USD = 1 USD» eliminada del conversor.
  - feat(conversor): BiSwap — el resultado viaja al monto al intercambiar.
  - feat(tour): motor propio (overlay + recorte real con Path.difference,
    safe-area, re-medición en rotación, Completer por paso);
    tutorial_coach_mark fuera del pubspec; contenido intacto.
  - feat(sala): REESCRITA DESDE 0 — causa raíz del «no puedo crear/unirse»:
    hubs inferían rol por código vacío y el host pasaba código generado
    (arrancaba como descubridor). Seam RoomLink con startHost/dial
    explícitos; protocolo hello→welcome determinista (sin PIN); 3 modos P2P
    sin internet (Cerca/WiFi-Hotspot/Bluetooth); modo Servidor y
    socket_io_client retirados; gobierno v18.0 intacto; lobby y Sala Viva
    reescritos; tests con enlace falso.
- Decisiones:
  - PIN+emoji fuera: el código de 6 letras ES el secreto de una lista de
    compras; el baile de verificación era una fuente de carreras.
  - Modo Servidor fuera (no es P2P, necesita internet — contra la orden
    expresa «todo posible sin conexión a internet»). server/ queda como
    referencia del protocolo.
  - Hotspot se funde con WiFi (misma tecnología UDP+TCP, misma subred):
    3 modos claros en el lobby.
  - CSV/exportes siguen en formato máquina (punto decimal) a propósito.
  - Las cruzadas CO (BRL/MXN a COP) no se añaden: el motor ya resuelve vía
    USD y DolarAPI no aporta valor sobre eso (documentado aquí).
- Gates: analyze 0 issues · 155 tests verdes (142 + 13 netos: board 7,
  sala 15 reescritos menos 4 viejos, BiSwap 1) · build=push a Actions con
  matriz de 4 APK (paso 8 al cierre).
- Bloqueos: ninguno. Dos carreras propias halladas y corregidas por los
  tests (invitado conectado a nivel transporte antes de welcome;
  concurrencia de hello's mutando _members durante _broadcast).
- Siguiente: push → poll CI+Build hasta verde → verificar los 4 APK
  valorave-v1.9.0-build-{fecha}-{abi}.apk → merge a main SOLO con orden
  expresa del dueño.
---
## [TASK-20-B] Integración de la ronda paralela v19.0 (dos sesiones) · 2026-09-16
- Agente: Super Z (GLM)
- Contexto: el push local fue rechazado — el remoto YA tenía una v19.0
  cerrada por otra sesión (transporte de sala desde 0, respaldos
  regionales, sellos, BiSwap, fixes de CI). Esta sesión implementó los 21
  encargos del dueño en 16 commits. Se integran AMBOS sin destruir nada.
- Hecho:
  - Merge con política por área: sala/conexiones → versión remota (seam
    RoomLink determinista + 317 tests); tour/conversor/tasas/lista/home/
    ajustes/bienvenida/tips/productos → versión local (superset de los
    encargos); board → arquitectura de respaldos remota + consolidación
    local de UNA consulta por región encima.
  - MODO SERVIDOR DEVUELTO: el remoto lo eliminó (socket_io_client fuera)
    — el dueño ordenó explícitamente NO eliminarlo. Se re-agrega como un
    RoomLink más (socket.io) con su configuración propia.
  - CI del remoto conservado (toolchain 3.47.4 fijado + pubspec.lock).
- Verificado: analyze 0 · suite completa verde tras la integración.
  - Push fef3046+2b0ce40 → CI verde; Build: arm64/v7a verdes, x86_64 y
    universal murieron 2× por shutdown del runner (exit 143, infra).
---
## [TASK-21] Saneamiento del quota de artefactos de Actions · 2026-09-16
- Agente: Super Z (GLM)
- Contexto: cierre del paso 8 (compilar en Actions hasta verde) de la
  TASK-20-B. Los 4 APK de 2b0ce40 compilaban pero el Upload caía.
- Diagnóstico (3 intentos, 3 causas distintas de infra):
  1. Attempts 1-2: «The runner has received a shutdown signal» (exit
     143) a mitad de Gradle — kill de infra, ya visto en v17.8/v18.0.
  2. Attempt 3: los builds COMPILARON BIEN; el paso Upload falló con
     «Artifact storage quota has been hit» (500 MB del repo privado).
     Causa raíz: 75 artefactos acumulados = 4.335 MB (legacy de Sept
     8-15: 20× «valorave-binarios» ~117 MB, 9× «pwa-original» 23 MB,
     8× 123 MB de v16, sets v17.x y pre-merge df2347c0/fef30468).
- Hecho:
  - Limpieza quirúrgica vía API (scripts/limpiar_artefactos.py fuera del
    repo): 69 artefactos borrados (4.214 MB). Conservados: 4 APK de
    v18.0 (run 34848972529 — el dueño tiene esos enlaces) y arm64+v7a
    del run v19.0 vigente. Bug propio corregido en el script: la regex
    del token capturaba «//usuario:» → 401 Bad credentials.
  - Attempt 4 tras liberar: x86_64 murió por OTRO shutdown del runner
    (10:43 UTC) y el universal volvió a chocar con el quota (10:46 UTC)
    — GitHub recalcula el uso cada 6-12 h, el borrado aún no cuenta.
  - Preventivo (este commit): workflow limpieza-artefactos.yml — diario
    04:23 UTC + manual; conserva los 3 artefactos más recientes por
    NOMBRE (~270 MB peor caso) y borra el resto. jq validado con los
    datos reales de la API (reduce, no group_by: este no garantiza el
    orden relativo). El job de release (tags) usa artefactos de su
    propio run — siempre los más nuevos — jamás se toca.
  - Bump 1.9.1-beta+19 + kAppVersionVisible 19.1 + CHANGELOG.
- Decisiones:
  - Política «3 por nombre» (no «N días»): determinística y acotada —
    la cadencia real de pushes (~2/día) con 3 días daría 540 MB y
    volvería a romper el quota; por nombre nunca supera ~270 MB.
  - Se conserva retention-days: 30 del build.yml — la limpieza diaria
    vence antes y sin cambiar el workflow de build.
  - NO se toca main (777b169) — merge SOLO con orden expresa del dueño.
- Gates: analyze 0 issues · test suite sin cambios (172 verdes, sin
  tocar lib/ salvo la constante de versión) · build=paso 8 en curso.
- Bloqueos: el recálculo del quota (6-12 h desde las 10:27 UTC) es la
  única incógnita — este push arranca un run fresco; si sus Uploads
  caen por storage se re-lanzan failed-jobs hasta verde.
- Siguiente: poll del Build de 1.9.1-beta+19 hasta los 4 APK verdes →
  reportar al dueño con enlaces → merge a main SOLO si él lo dice.
---
## [TASK-22] Licencia propietaria + paquete único ZIP (4 APK + AAB) + fixes de toolchain · 2026-09-16
- Agente: Super Z (GLM)
- Contexto: el dueño pasó el repo a PÚBLICO (fin del quota de
  artefactos) y pidió: (1) licencia de propietario sin uso público,
  (2) que cada build compile los 4 APK + 1 AAB y entregue TODO en un
  ZIP, con compiladores estándar de GitHub Actions.
- Hecho:
  - LICENSE nueva (propietaria, es-VE): copyright 2026 isaac4722, uso
    personal + Lista Autorizada por escrito; prohibidos copia,
    distribución, modificación, derivados, ingeniería inversa,
    publicación y entrenamiento de IA; visibilidad pública ≠
    autorización. Sección «Licencia» en README; nota en AGENT.md Regla 9.
  - build.yml reescrito: job `aab` NUEVO en cada push (antes
    solo-tags); job `paquete` NUEVO (needs apk+aab) que junta los 5
    binarios + LEEME.txt (qué ABI para qué dispositivo + instalación +
    licencia) + checksums.sha256 y entrega UN artefacto
    valorave-v{versión}-build-{fecha}-completo.zip; exige los 5
    binarios antes de comprimir. Release (tags) ya no compila:
    descarga el ZIP del mismo run y adjunta 6 assets con
    fail_on_unmatched_files. Intermedios retention 1 día; ZIP y
    símbolos de ofuscación 30 días.
  - Mini-errores de toolchain: Kotlin 2.2.20 → 2.3.20 (aviso del
    propio Flutter) y ndkVersion = 28.2.13676358 (la que exige
    integration_test; NDKs backward compatibles). Gradle 8.14 y AGP
    8.11.1 compatibles con Kotlin 2.3.x.
  - limpieza-artefactos.yml re-documentado: red de seguridad por si el
    repo vuelve a privado (público = storage gratis).
  - AGENT.md Regla 9 ampliada (ZIP + AAB siempre + licencia);
    docs/RELEASE.md checklist actualizado (6 assets).
  - Watcher del quota detenido (obsoleto: el push nuevo trae run
    fresco y el repo público no tiene quota).
  - Bump 1.9.2-beta+20 · kAppVersionVisible 19.2 · CHANGELOG.
- Decisiones:
  - Símbolos de ofuscación FUERA del ZIP (no son instalables) pero en
    artefacto aparte valorave-simbolos (30 días) para des-ofuscar
    stacktraces si el dueño reporta crashes.
  - La versión para el nombre del ZIP se extrae del nombre del APK
    (el job paquete no hace checkout: más rápido, sin state).
  - El AAB de rama no va a Release — solo en tags (Play Store usa
    tags), pero SÍ está en el ZIP de cada ronda (orden del dueño).
- Gates: analyze/test delegados al workflow CI del mismo push (sin
  SDK Flutter local esta sesión; único cambio en lib/ = constante de
  versión). Build = paso 8 en curso (verificación hasta verde).
- Bloqueos: ninguno.
- Siguiente: poll de CI+Build hasta verde → verificar el ZIP (5
  binarios + LEEME + checksums) → reportar enlaces al dueño → merge a
  main SOLO con orden expresa del dueño.
  - [fix 14:15 UTC] Kotlin 2.3.20 convirtió kotlinOptions en ERROR de
    compilación de script (los 5 jobs de build cayeron en el primer
    push): migrado a compilerOptions con JvmTarget tipado
    (kotl.in/u1r8ln), import org.jetbrains.kotlin.gradle.dsl.JvmTarget.
  - [fix 14:35 UTC] El ZIP salió con nombre roto
    (valorave-vvalorave-v…): la regex de versión fallaba con los guiones
    de «1.9.2-beta». Reescrito sin regex: el prefijo del nombre del APK
    arm64 ES el nombre del ZIP (bash puro, ${APK##*/} y ${BASE%-arm64-…}).
    Simulado LOCALMENTE con archivos falsos antes de push (script
    scripts/test_paquete_local.sh, fuera del repo): nombre, 4 APK, AAB,
    LEEME y checksums verificados en sandbox.

---
## [TASK-23] Auditoría GUI completa · 37 fixes de pantalla + humanizer + LICENSE en todas las ramas · 2026-09-17 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Contexto: encargo del dueño — «escribe y arregla el GUI de la app en
  general, evitando errores», activar skills del repo + instalar
  blader/humanizer, y asegurar que TODAS las ramas tengan su licencia de
  PROPIEDAD. Trabajo en fix/v1.1.0-dp4-paridad (v19.2 → v19.3).
- Hecho:
  - SKILLS: agent-skills/humanizer/ añadido (clonado de github/blader
    porque npx skills add cae por timeout de red en este entorno — mismo
    bloqueo de TASK-13; el README del repo documenta la vía alternativa
    de leer como contexto, que es la usada: flutter-ui-design,
    flutter-responsive-layout, taste-skill + humanizer). README de
    agent-skills actualizado con las 5 familias.
  - LICENCIAS: LICENSE propietaria copiada a main (7e8284d), test
    (e57e458), fix/v1.0.1-router-icono-paridad (9b49324) y
    fix/v1.0.2-paridad-mvp (6afcc0b) — las 5 ramas del repo ya la
    tienen (verificado con git show por rama).
  - SDK LOCAL: flutter-sdk 3.47.4 clonado en /home/z/my-project (fuera
    del repo) → gates analyze/test corren LOCALES otra vez (TASK-21/22
    los delegaban a CI): línea base 0 issues · 172/172 verificada ANTES
    de tocar nada, y en cada commit.
  - AUDITORÍA: 3 agentes en paralelo (shell/home/welcome · insights/
    products/statement · lista/converter/room/history/scanner/widgets)
    + verificación propia línea a línea de cada hallazgo antes de
    corregir. 37 issues reales (los que analyze NO ve).
  - FIXES en 7 commits (62318fa → dbb03a7): (1) desbordes de fila a
    360dp/textScale ×9; (2) texto de usuario sin recorte ×10 +
    clamp de paginación; (3) showDatePicker en INGLÉS → raíz arreglada
    con flutter_localizations (+ intl 0.20.3 + syncfusion 34.2.8, la
    major alineada al Flutter 3.47 del CI) + delegates en ambos
    MaterialApps; (4) dark theme/contraste ×4 (share_menu invisible en
    oscuro, black38, alpha 0.4, piso 9.5px); (5) a11y textScale ×5
    (dots onboarding, slide 1 con scroll, tab bar/header minHeight,
    CANTIDAD, monto ranking); (6) badge «N ítems» muerto (LiveBadge
    live:false jamás se pintaba), copy «Toca el lápiz» solo donde hay
    lápiz, meta con coma es-VE; (7) leaks de TextEditingController ×4
    diálogos, orden de mounted en tips, vesRate del checkout
    (unitsPerUSD(usd) devolvía 1 siempre).
  - Bump 1.9.3-beta+21 · kAppVersionVisible 19.3 · CHANGELOG.
- Decisiones:
  - StatCard.value con FittedBox scaleDown (patrón §8 del propio repo)
    en vez de maxLines: sirve igual para cifras y para nombres libres.
  - main_shell: ConstrainedBox(minHeight) + mainAxisSize.min — el test
    del shell cazó en vivo que con .max la Column llenaba TODO el alto
    del slot bottomNavigationBar (los gates existen por esto).
  - flutter_localizations es paquete OFICIAL del SDK (regla 7); el
    salto syncfusion 27→34 lo exige intl 0.20.3 y lo valida la suite
    completa (172/172) — APIs usadas (SfCartesian/Series/Axes)
    estables entre majors.
  - Los fixes del tab bar/header usan minHeight (no altura fija) para
    que crezcan con textScale de accesibilidad sin romper el layout.
  - vesRate con fallback 0 (no 1): 0 = «sin tasa conocida», el mismo
    convenio de buildPurchase.
- Gates: analyze=0 issues · test=172/172 (locales, en CADA commit) ·
  build=paso 8 en curso (verificación del run de Actions hasta verde).
- Bloqueos: npx skills add cae por timeout de red (2 intentos, luego
  clonado directo con git — documentado arriba y en TASK-13).
- Siguiente: poll de CI+Build de este push hasta verde (4 APK + AAB +
  ZIP) → reportar enlaces al dueño → merge a main SOLO con orden
  expresa del dueño.

## [TASK-24] v19.4 · 5 encargos del dueño: tarjetas TIPs, Generar, widgets de Inicio, Buscar Sala y FlutLab · 2026-09-17 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Contexto: encargos del dueño sobre fix/v1.1.0-dp4-paridad (v19.3 →
  v19.4): arreglar el tamaño de las tarjetas de TIPs/Tutoriales (aire
  en blanco), el error de «Generar» al compartir, widgets de Inicio
  visibles antes de añadir con contenido adaptable al tamaño
  («Widget Resizing»), «Buscar Sala» dentro de Crear Sala, y la
  compatibilidad con flutlab.io (investigando si es cierto). Humanizer
  aplicado a todo el copy nuevo visible.
- Hecho:
  - TIPS/TUTORIALES (31d2bd2): la tarjeta del coach mark ocupaba TODO
    el hueco (height: maxH fijo) con el texto arriba y los botones al
    fondo — vacío gigante. Ahora mide su contenido (Align en su hueco:
    cuelga bajo el foco, se apoya sobre el foco) y el ancho sigue fijo.
    2 tests nuevos de geometría.
  - GENERAR (effe564): doble causa raíz — (1) el GlobalKey sobre un
    KeyedSubtree: findRenderObject devolvía el render descendiente, el
    cast a RenderRepaintBoundary reventaba y el catch lo tragaba →
    «No pude generar la tarjeta» SIEMPRE; (2) Future.delayed×2 ganaba
    la carrera contra el vsync. Key al RepaintBoundary + endOfFrame×2
    (patrón renderOffstagePng) + captureWidget endurecido (sube al
    boundary envolvente). Test end-to-end del PNG (firma + limpieza).
  - WIDGETS DE INICIO (5c7d344): catálogo con PREVIEW REAL (el mismo
    builder pinta hoja e Inicio), tamaños Compacto/Normal/Grande que
    cambian el CONTENIDO (divisas 4/todas · resumen total/stats/ledger
    5-8 · alertas 3/6/8 · tiendas 2/4/6 · registros 2+2/3+3/5+5),
    persistencia valorave.home.widgets/.off/.size.<id> con ocultos
    recordados (sin eso lo quitado volvía tras reiniciar — bug cazado
    por test), tarjeta «Widgets de Inicio» al pie + estado «Inicio
    limpio». Anclas del tour SOLO en Inicio (GlobalKey duplicado
    tumbaría la app: la preview comparte builders). 8 tests.
  - BUSCAR SALA (a3f69ec): campo en la tarjeta CREAR SALA que filtra
    salas públicas avistadas por nombre/anfitrión/código sin tildes ni
    mayúsculas; escribir arranca la escucha UNA vez por búsqueda (cada
    arranque limpia la lista). _RoomAdTile compartido con Salas
    cercanas + seam debugInjectAd (@visibleForTesting). 2 tests.
  - FLUTLAB (c4b6b6f): verificado — FlutLab es IDE online que importa
    de GitHub y compila; requiere estructura Flutter en la raíz. ios/ y
    web/ generados (flutter create --org ve.valorave), .gitignore raíz
    intacto (ios trae el suyo), .metadata con android restaurada,
    docs/FLUTLAB.md con decisiones (pubspec.lock commiteado a propósito
    — recomendación Dart para apps; web/ es andamiaje, la app es
    Android-first).
  - Bump 1.9.4-beta+22 · kAppVersionVisible 19.4 · CHANGELOG.
- Decisiones:
  - Tarjeta del coach: Align dentro del Positioned del hueco en vez de
    medir a mano: si el contenido crece, el Column interno se topa en
    maxH y el scroll existente hace el resto (botones siempre vivos).
  - Tamaños por widget con contenido DISTINTO; cotización/herramientas
    sin selector (contenido fijo) — honesto antes que un control muerto.
  - Lista vacía explícita NO se persiste (inicio pelado tras reiniciar
    sería un susto): el estado vacío vive la sesión y se recupera solo.
  - Preview: IgnorePointer + FittedBox scaleDown a ancho 360 — la hoja
    muestra la pieza real, no un dibujo.
  - Tests del home: SharedPreferences en el árbol (como appProviders)
    y tour ya visto donde el test no es del tour (la barrera del coach
    bloquea taps — lección para futuros tests del shell).
- Gates: analyze=0 issues · test=185/185 (locales, en CADA commit) ·
  build=paso 8 en curso (verificación del run de Actions hasta verde).
- Bloqueos: el test end-to-end del PNG necesitó el patrón híbrido
  pumps+runAsync (el toImage del engine no fluye con solo pumps) —
  resuelto y documentado en el propio test.
- Siguiente: poll de CI+Build hasta verde → reportar → merge a main
  SOLO con orden expresa del dueño (regla TASK-21/22).

---
## [TASK-25] v19.5 · limpieza de la desviación + 3 fixes recuperados + AppWidgets con preview y resize · 2026-09-17/18 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Contexto: un agente anterior (Claude Sonnet 4.6/Zed, autor «ValoraVE
  Agent») se desvió del flujo — creó la rama dp4 y 13 runs de Actions
  sin permiso, con 5 commits fuera de flujo (4 pushes en rojo, workflow
  fantasma format-fix, hardening que rompía la Regla 9). El dueño
  ordenó Fase 0 (inventario) → confirmó qué recuperar (solo lo que
  corrige funcionalidad EXISTENTE y es mejora clave) y qué descartar
  (features no pedidas: precio/kg, filtro por mes, menú share, cambio
  de icono, hardening).
- Hecho:
  - FASE 1 (limpieza): rama dp4 y test-new eliminadas del remoto; 13
    runs huérfanos borrados (API DELETE); el workflow format-fix
    desapareció solo con la rama. Quota intacto: dp4 nunca subió
    artefactos. El repo quedó en 5 ramas legítimas sobre bea1eeb.
  - FASE 2 (recuperación validada, e904676→7e631ee): (1) CSV de
    movimientos exporta la tienda del ÍTEM (i.store ?? p.store — la UI
    agrupa por tienda desde v17.2, la planilla no); (2) mergeRegion-
    Blocks siembra las fuentes de la ronda anterior: región caída no
    borra tasas (degraded la reporta, updatedAt original se conserva,
    changed no inventa cambios) + 3 tests nuevos de la semántica;
    (3) _persist hace flush a disco (fire-and-forget con catchError:
    fallo de disco deja el dato en memoria y reintenta; guard null del
    box — el flush del agente desviado con _boxData! revientaría si la
    caja no está abierta, corregido aquí).
  - FASE 3 (encargo AppWidgets — ec f6e5a): la familia Tasa BCV ·
    Paralelo · Brecha YA existía (v19.0) pero sin preview ni resize
    real. Añadido: previewLayout (Android 12+ renderiza el layout real
    en el selector) + previewImage PNG (5-11, drawable-nodpi, cifras de
    la semilla documentada) + descripciones es-VE en el picker; 4×1 por
    defecto (targetCellWidth/Height + minWidth 250dp), rango 2×1→4×2
    (min/maxResizeWidth/Height), onAppWidgetOptionsChanged re-renderiza
    con buckets COMPACT (solo cifra ≤140dp ancho / ≤80dp alto) · NORMAL
    (completo) · BIG (4×2, 44sp) via setViewVisibility +
    setTextViewTextSize (API 16+, minSdk 21 OK); tocar el widget abre
    la app (PendingIntent inmutable, targetSdk 31+). docs/APPWIDGETS.md
    con flujo y verificación manual. Consulta web del paso 2 hecha
    (docs oficiales «flexible widget layouts» + patrón preview 12+).
  - Bump 1.9.5-beta+23 · kAppVersionVisible 19.5 · CHANGELOG.
- Decisiones:
  - Solo se recuperaron fixes a funcionalidad EXISTENTE (decisión del
    dueño); las 3 features nuevas del agente desviado quedaron fuera.
  - Preservación del board: sources sí, providers no — los proveedores
    reflejan quién respondió ESTA ronda; degraded dice qué región calló.
  - Umbral COMPACT por alto (≤80dp) calculado del contenido real del
    diseño NORMAL (~90dp): una celda baja muestra solo la cifra en vez
    de recortar.
  - home_widget 0.9.4 verificado: su updateWidget emite broadcast
    APPWIDGET_UPDATE → pasa por onUpdate propio → TODAS las vías de
    actualización (Dart, 30 min, resize) convergen en render().
  - El previewImage pre-12 es PNG estático (vector no puede llevar
    texto); mismas cifras de la semilla del store — prohibido inventar.
- Gates: analyze=0 issues · test=188/188 (185 previos + 3 nuevos de
  board; en CADA commit) · build=paso 8 en curso (verificación del run
  de Actions hasta verde — el Kotlin lo compila el build de Actions,
  localmente no hay SDK Android).
- Bloqueos: ninguno.
- Siguiente: Fase 4 — rama test/lowder para probar Lowder (estructura
  + entry secundario + docs) → push de ambas ramas → poll CI/Build
  hasta verde → merge a main SOLO con orden expresa del dueño.

## [TASK-26] v19.6 · orden del dueño: widgets in-app fuera, galería de App Widgets y fix del conversor · 2026-09-19 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Contexto: el dueño pidió (1) explicación de lo descartado del agente
  desviado (precio/kg, filtro por mes, menú share, cambio de icono,
  hardening de workflows — features de un spec externo «Review.txt»,
  ninguna pedida), (2) ELIMINAR los «UI Widgets» configurables DENTRO
  de la app (v19.4), dejar el «+» y escribir bien los App Widgets /
  Home Android Screen Widgets usando sus tarjetas de diseño como base
  (adaptadas), (3) arreglar el conversor: al teclear más de 3 ceros
  salían comas y 40 mil se volvía 4, (4) auditar y corregir.
- Hecho:
  - CONVERSOR (bug real): la heurística del punto en MoneyField._canon
    solo reconocía grupos de miles EXACTOS de 3 dígitos — al teclear el
    5.º dígito sobre «4.000» el texto pasaba por «4.0000», el punto se
    volvía decimal, salía «4,0000» y el valor caía a 4. Regla nueva (y
    espejo en parseLocaleNum): sin coma, punto con 3+ dígitos detrás =
    miles; 1-2 = decimal; parte entera puro cero («0.0001») = decimal
    (las tasas chiquitas no se vuelven 1). Tradeoff documentado en
    código: 3+ decimales tecleados con Punto en monto ≥ 1 se leen como
    miles — en es-VE el teclado da coma.
  - WIDGETS IN-APP RETIRADOS: home_widgets.dart (catálogo,
    HomeWidgetController, tamaños, prefs valorave.home.*) y su test
    ELIMINADOS. home_screen.dart: _HomeSections vuelve a ser la lista
    FIJA de 7 secciones (anclas del tour intactas: cotización y
    divisas), sin estado ni SharedPreferences. Los prefs viejos de
    usuarios quedan huérfanos sin efecto (sin migración: el Inicio
    simplemente vuelve al de siempre).
  - APP WIDGETS (los del launcher, «escritos bien»): nueva galería
    lib/features/home/app_widgets.dart — la tarjeta «+» del pie del
    Inicio («App Widgets · Añade a tu pantalla de inicio de Android»)
    abre la hoja con los TRES nativos (Tasa BCV · Paralelo · Brecha):
    preview FIEL al widget real (mismo fondo #121417, borde #3A4048,
    radios 18, colores y jerarquía del bucket NORMAL, cifras vivas del
    tablero), botón «Añadir» → pin al launcher. Diseño adaptado de las
    tarjetas de referencia del dueño (badge · cifra héroe · secundario
    · hora, 2×1/4×1/4×2). Nota de resizing y cierre «Listo».
  - PIN NATIVO: MainActivity.kt registra el canal «valorave/widgets»
    (pinWidget → requestPinAppWidget, API 26+, mapa explícito de
    proveedor→clase — nada de Class.forName, sobrevive minify);
    launcher sin soporte o Android viejo → PlatformException → guía
    manual de 3 pasos (dialog) desde Dart.
  - TESTS: app_widgets_test.dart (4: secciones fijas + tarjeta, galería
    con previews fieles, pin al canal con provider correcto, guía
    manual); widgets_test.dart +3 casos de regresión del conversor
    (4.0000/40.0000/0.0001); fmt_test.dart +1 grupo parseLocaleNum.
  - AUDITORÍA: grep de residuos del catálogo = 0 referencias vivas;
    SharedPreferences quedó sin usos en home_screen (import retirado);
    tours/tips no referenciaban el catálogo; docs/APPWIDGETS.md
    actualizado (galería in-app + verificación manual renumerada).
  - Bump 1.9.6-beta+24 · kAppVersionVisible 19.6 · CHANGELOG.
- Gates: format/analyze/test locales ANTES del commit (resultado en
  el commit); el Kotlin lo compila el build de Actions (sin SDK
  Android local, como en TASK-25).
- Bloqueos: ninguno.
- Siguiente: push → CI/Build verde → merge a main SOLO con orden
  expresa del dueño. test-lowder sigue disponible para la Fase 4 del
  dueño (editor en 0.0.0.0:8787/editor.html).
