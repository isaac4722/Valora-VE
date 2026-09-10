# AGENT.md · Contrato de trabajo para agentes (ValoraVE)

## Propósito
Este archivo define CÓMO se trabaja en este repo. Cualquier agente (IA o
humano en modo automatizado) DEBE cumplirlo antes de tocar código.

## Reglas inquebrantables
1. Lee `AGENT.md` y `progress.md` COMPLETOS antes de empezar tu turno.
2. Al terminar tu turno, AÑADE (nunca reescribas) tu sección en
   `progress.md` con la plantilla del §Plantilla. Sin sección, tu trabajo
   no existe.
3. Los gates `flutter analyze` (0 issues) y `flutter test` (suite verde)
   deben pasar ANTES de cada commit. Prohibido debilitar tests o reglas
   para «ponerse verde».
4. `MVP-CRUD.md` es la única fuente de verdad funcional. Si el código y
   el MD discrepan, manda el MD; anota la desviación en progress.md.
5. Prohibido: mocks en lib/, `AppStateScope`, patrones web
   (localStorage/ServiceWorker), cifras de mercado inventadas, tokens/keys
   en el código, renumerar la versión fuera de `1.x.y-beta+z`.
6. Idioma: español (es-VE) en UI, docs y commits (conventional commits).
7. Plugins: solo oficiales (pub.dev verificado); versiones compatibles
   entre sí (ver docs/DEPENDENCIAS.md).
8. Si te bloqueas >2 intentos en algo: déjalo registrado en progress.md
   §Bloqueos y continúa con otra pieza; no inventes soluciones mudas.

## Definición de hecho (por pieza)
- Código + test que lo cubre + `analyze`/`test` verdes + entrada en
  progress.md + actualización de docs si cambia comportamiento visible.

## Plantilla de entrada en progress.md
    ---
    ## [TASK-ID] <título> · <fecha UTC>
    - Agente: <nombre/versión>
    - Hecho: <lista concreta>
    - Decisiones: <qué decidiste y por qué>
    - Gates: analyze=N issues · test=N/N · build=OK/FAIL
    - Bloqueos: <ninguno | descripción>
    - Siguiente: <qué toca ahora al flujo principal>
