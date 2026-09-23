- # Contrato de Trabajo para TODOS (ValoraVE)
  
  Aplica para TODO agente (IA o humano). Lee este archivo y `docs/agent/` antes de empezar.  
- ## Comandos Ejecutables (Ejecutar en este orden)
  
  | Tarea | Comando |
  |---|---|
  | Dependencias | `flutter pub get` |
  | Análisis estático | `flutter analyze` |
  | Suite de tests | `flutter test` |
  | Test de una pieza | `flutter test test/ruta/archivo_test.dart` |
  | Build debug | `flutter build apk --debug` |
  | **Gate de Calidad** | `bash scripts/quality_gate.sh` (ejecuta analyze + test + auditoría UI) |
- ## Stack y Versión
- **Framework:** Flutter (Dart). Gestor `pub`.
- **Versión:** `1.x.y-beta+z` (ver `pubspec.yaml`). Prohibido cambiarla fuera de este esquema.
- ## Estructura del Proyecto (Mapa)
- `lib/`: Código fuente. Prohibido mocks, `AppStateScope`, patrones web (localStorage), cifras inventadas o tokens.
- `lib/core/theme/`: Sistema de diseño y tokens de UI.
- `lib/features/`: Módulos funcionales (cada uno con su UI, lógica y tests).
- `test/`: Tests unitarios y de widget. Refleja la estructura de `lib/`.
- `docs/agent/`: **Documentación con alcance para el agente** (ver abajo).
- `.agents/skills/`: **Ubicación estándar de skills del agente** (ver abajo).
- ## Límites de Tres Niveles
  
  **Siempre hacer:**  
- Ejecutar `flutter analyze` y `flutter test` antes de cada commit.
- Añadir (nunca reescribir) tu entrada en `PROGRESS.md`.
- Usar español (es-VE) en UI, docs y commits (conventional commits).
- Consultar `MVP-CRUD.md` como única fuente de verdad funcional (En fases básicas o de repasos).
  
  **Preguntar primero:**  
- Si un test falla y no entiendes la causa raíz tras 2 intentos.
- Antes de añadir una nueva dependencia a `pubspec.yaml`.
- Si necesitas modificar `lib/core/` (afecta a toda la app).
- Si el encargo es ambiguo o contradice `MVP-CRUD.md`.
  
  **Nunca hacer:**  
- Debilitar tests o relajar reglas de `analyze` para "ponerse verde".
- Introducir mocks, `AppStateScope`, `localStorage` o `ServiceWorker` en `lib/`.
- Inventar cifras de mercado, tasas de cambio o datos de usuario.
- Reemplazar el sistema de diseño o arquitectura; solo evolucionar lo existente.
- Commitear tokens, API keys o secretos.
- ## Flujo de Trabajo: Máquina de Estados (9.5 Pasos)
  
  El ciclo se ejecuta como una máquina de estados. Cada paso emite un "route" que decide el siguiente.  
  
  | Estado | Acción Principal | Route si OK | Route si FALLA |
  |---|---|---|---|
  | **1. ANALYZE** | Analiza encargo (think ≥1 min).<br>Identifica módulos, reglas y **dirección estética** si toca UI. | `2_PLAN` | `9_BLOCKED` |
  | **2. PLAN** | Define el plan de implementación.<br>**Paso obligatorio solo en el primer intento.**<br>En reintentos, se salta a `3_IMPLEMENT`.<br>(Investiga en la web mejores prácticas para implementar la fixture; adapta soluciones que funcionen.) | `3_IMPLEMENT` | `1_ANALYZE` |
  | **3. IMPLEMENT** | Aplica lo pedido: 1 pieza por commit.<br>Usa skills de diseño o instrucciones oficiales si aplica. | `3.5_VISUAL_GATE` | `9_BLOCKED` |
  | **3.5 VISUAL GATE** | *(Solo si una función pasa de lógica a full stack o GUI.)*<br>Precompila la app Flutter/Android en web local, captura pantallas y verifícalas contra slop/BASURA con VLM Skill.<br>Borra las capturas al terminar (temp). | `4_AUDIT` | `6_RETRY` |
  | **4. AUDIT** | Audita el diff vs encargo.<br>Ejecuta `quality_gate.sh` (analyze + test + UI audit). | `5_CONTROL` | `6_RETRY` |
  | **5. CONTROL** | **Gate principal.**<br>Verifica que `quality_gate.sh` pasó y que `progress.md` está actualizado. | `7_PERSIST` | `6_RETRY` |
  | **6. RETRY** | **Sub-rama de recuperación.**<br>Diagnostica el fallo de `4` o `5` y decide a qué estado volver. | `1_ANALYZE` o `3_IMPLEMENT` | `9_BLOCKED` |
  | **7. PERSIST** | Commit (conventional) y push a rama de trabajo. | `8_CI` | `6_RETRY` |
  | **8. CI** | Espera a que GitHub Actions esté verde. | `9_CLOSE` | `6_RETRY` (si es de código) o `9_BLOCKED` (si es de entorno) |
  | **9. CLOSE / BLOCKED** | Cierra el turno.<br>Registra estado real en `progress.md`. | FIN | FIN |
- ### Sub-rama de Recuperación (RETRY)
  
  Cuando el flujo llega a `6_RETRY`, el agente **no vuelve ciegamente al paso 1**. Diagnostica:  
- **Fallo de Análisis/Plan (viene de 1 o 2):** Vuelve a `1_ANALYZE`.
- **Fallo de Implementación (analyze/test fallan):** Vuelve a `3_IMPLEMENT`.
- **Fallo de Auditoría/Control (el diff no coincide, falta doc):** Vuelve a `3_IMPLEMENT` o `4_AUDIT` según corresponda.
- **Regla de Oro:** En reintentos, el estado `2_PLAN` se salta por defecto. Solo se re-ejecuta si el fallo fue explícitamente por un plan incorrecto.
- ## Integración de Skills (Capacidades del Agente)
  
  Las skills se invocan **dentro** de los estados del flujo. El agente debe leer su `SKILL.md` antes de usarlas.  
- ### Ubicación y Organización Estándar
- **Ubicación canónica:** `.agents/skills/<skill-name>/SKILL.md` (estándar de facto, compatible con múltiples agentes).
- **Verificación:** Si el repo ya contiene skills, el agente debe verificar que estén en `.agents/skills/` y no dispersas en `.claude/skills/`, `.cursor/rules/` u otras ubicaciones no estándar. Si hay duplicados, consolidar en la ubicación canónica.
- **Instalación:** Si una skill no está instalada, el agente la instala vía `npx skills add <repo> -a <agent>` o mediante el instalador nativo del agente, y lo registra en `PROGRESS.md`.
- ### Skills de Token-Efficiency (RTK + Caveman)
  
  | Skill | Estado donde se usa | Cuándo Activarla |
  |---|---|---|
  | **`RTK`** (Rust Token Killer) | **Transversal** (todos los estados que ejecuten comandos shell) | Siempre que se ejecuten comandos que generen salida ruidosa: `rtk flutter analyze`, `rtk flutter test`, `rtk git status`, `rtk git diff --stat`, `rtk grep`, etc. **Reduce tokens de entrada (input).** Instalar vía `brew install rtk` o `curl -fsSL ... \ | sh`, luego `rtk init -g` para wire con el agente. |
  | **`Caveman`** | **3_IMPLEMENT, 4_AUDIT, 7_PERSIST** (solo output al usuario) | Activar en modo **lite** o **full** para comprimir prosa del agente. **NUNCA para `docs/`, `PROGRESS.md`, commits ni documentación.** Solo para respuestas conversacionales. Instalar vía `npx skills add JuliusBrussee/caveman -a <agent>`. |
  
  **Regla de Contradicción RTK vs Caveman:**  
- RTK optimiza **input** (lo que el agente lee).
- Caveman optimiza **output** (lo que el agente dice).
- No son excluyentes; se usan **en capas**: RTK filtra comandos, Caveman comprime respuestas.
- Si una skill de diseño sugiere verbosidad y Caveman sugiere brevedad, **prevalece Caveman para output conversacional**, pero los `docs/` y commits se escriben en español normal.
- ### Skills de Diseño y Calidad
  
  | Skill | Estado donde se usa | Cuándo Activarla |
  |---|---|---|
  | **`ui-nice-skill`** | 1_ANALYZE, 4_AUDIT | Siempre que el encargo implique crear/modificar pantallas o flujos de UI. |
  | **`flutter-frontend-design`** | 3_IMPLEMENT | Siempre que se implemente UI nueva en `lib/`. |
  | **`mobile-design`** | 2_PLAN (consulta) | Para verificar convenciones de plataforma (touch targets ≥48dp, breakpoints). **Solo consulta, no dicta estética.** |
  | **`Humanizer`** | 3_IMPLEMENT (post-UI) | Antes de cerrar `3_IMPLEMENT`, para pulir TODO texto visible al usuario. |
  | **`VLM Skill`** | 3.5_VISUAL_GATE | Capturas Flutter web local; descartar slop/BASURA. **No rediseñar.** |
  | **`Taste Skill`** | 4_AUDIT | Opcional. Si la auditoría visual detecta riesgo de "AI slop". |
  | **`flutter-a11y`** (o equivalente) | 4_AUDIT | Verificar semántica, contraste, `Semantics()` y navegación por teclado si hay UI nueva. |
  | **`flutter-testing`** (o equivalente) | 4_AUDIT | Widget/golden tests si el encargo tocó widgets o layouts. Complementa `quality_gate.sh`. |
  
  **Regla de No Contradicción:** Si una skill sugiere algo que viola los Límites de Tres Niveles, **prevalece el `AGENT.md`**. Si una skill no está instalada (Debe instalarse y hacer carga previa), el agente lo registra en `PROGRESS.md` y continúa manualmente aplicando sus principios.  
- ## Definición de Hecho (Por Pieza)
  
  Código + Test que lo cubre + `quality_gate.sh` verde + Entrada en `progress.md` + `docs/` actualizado (si cambió comportamiento) + Run de Actions verde.  
- ## Documentación con Alcance (Progressive Disclosure)
  
  Para mantener este archivo delgado, el detalle vive en `docs/agent/`. El agente **debe consultar** el archivo correspondiente cuando el estado del flujo lo requiera.  
  
  | Necesidad | Archivo de Referencia | Cuándo Consultarlo |
  |---|---|---|
  | Verdad funcional | `MVP-CRUD.md` | Estado `1_ANALYZE` (siempre) |
  | Dependencias y plugins | `docs/DEPENDENCIAS.md` | Estado `2_PLAN` o `3_IMPLEMENT` (si se toca `pubspec`) |
  | Estilo de código y convenciones | `docs/agent/CODE_STYLE.md` | Estado `3_IMPLEMENT` (siempre) |
  | Estrategia de Testing | `docs/agent/TESTING.md` | Estado `4_AUDIT` (siempre) |
  | Flujo de Git y Commits | `docs/agent/GIT_WORKFLOW.md` | Estado `7_PERSIST` (siempre) |
  | Arquitectura y Patrones | `docs/agent/ARCHITECTURE.md` | Estado `2_PLAN` (siempre) |
  | Bitácora de turnos | `progress.md` | Al inicio y fin de cada turno |
