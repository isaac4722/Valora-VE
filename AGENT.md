# AGENT.md · Contrato de trabajo para agentes (ValoraVE)

## Propósito
Este archivo define CÓMO se trabaja en este repo. Cualquier agente (IA o
humano en modo automatizado) DEBE cumplirlo antes de tocar código.

## Método de trabajo — ciclo obligatorio en 9 pasos
Todo encargo se ejecuta SIEMPRE en este orden. Si la auditoría (paso 5)
falla, se repite el ciclo (1, 2 opcional, 3, 4, 5) hasta pasarla.
Prohibido saltar pasos o declarar «terminado» antes del 9.

1. **Analiza lo que se pide** (mínimo 1 minuto): identifica el objetivo
   real, los módulos tocados y las reglas de este contrato que aplican.
   Si algo es ambiguo, preguntar antes de escribir código — nunca
   inventar requisitos.
2. **Consulta la web** cómo se aplica lo pedido: busca soluciones
   existentes y mejores prácticas vigentes, selecciona las mejores y
   combínalas con el conocimiento de base del repo (docs/, progress.md).
   En reintentos del ciclo este paso es opcional.
3. **Aplica o crea lo indicado**: una pantalla/pieza por commit; sin
   features no pedidas; sin cambiar framework, arquitectura ni sistema
   visual (solo evolucionarlos).
4. **Audita y verifica** que se aplicó exactamente lo pedido: diff del
   commit contra el encargo punto por punto + `flutter analyze`
   (0 issues) + `flutter test` (suite verde).
5. **Punto de control**: si la auditoría pasa → continúa al paso 6;
   si falla → VUELVE al paso 1 (paso 2 opcional) y repite 3→4→5 hasta
   pasarla. Prohibido avanzar con auditoría roja o «casi listo».
6. **Documenta, declara y detalla**: entrada en progress.md (plantilla
   abajo), docs actualizados si cambió comportamiento visible, y reporte
   honesto de qué se hizo, skills usados, qué se verificó y qué falta.
7. **Guarda en el repo**: commits limpios (conventional commits) y push
   a la rama de trabajo.
8. **Compila en Actions y verifica hasta que se logre**: sigue el run de
   GitHub Actions del push; si el build o los gates fallan, corrige y
   repite hasta verde antes de dar el encargo por cerrado.
9. **Termina el trabajo pedido**: repo sincronizado, estado real
   registrado y encargo cerrado. «Terminado» significa los 9 pasos
   completos — nunca «casi».

## Reglas inquebrantables
1. Lee `AGENT.md` y `progress.md` COMPLETOS antes de empezar tu turno,
   y ejecuta cada encargo con el §Método de trabajo (ciclo de 9 pasos).
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
9. Los builds de release cubren CUALQUIER dispositivo Android (orden
   explícita del dueño · v17.9): la matriz de APK de
   `.github/workflows/build.yml` produce SIEMPRE `armeabi-v7a`
   (androids viejos), `arm64-v8a` (nuevos), `x86_64` (emuladores e
   Intel) y `universal` (todo-en-uno, instala sin saber la arquitectura),
   más el AAB en tags. Prohibido retirar un ABI de la matriz o dejar de
   publicar sus artefactos sin orden expresa del dueño. Nota técnica:
   Flutter no distribuye motor para x86 de 32 bits — ese ABI no es
   construible y no cuenta como cobertura faltante.

## Definición de hecho (por pieza)
- Código + test que lo cubre + `analyze`/`test` verdes + entrada en
  progress.md + actualización de docs si cambia comportamiento visible
  + run de Actions verde (paso 8 del método).

## Plantilla de entrada en progress.md
    ---
    ## [TASK-ID] <título> · <fecha UTC>
    - Agente: <nombre/versión>
    - Hecho: <lista concreta>
    - Decisiones: <qué decidiste y por qué>
    - Gates: analyze=N issues · test=N/N · build=OK/FAIL
    - Bloqueos: <ninguno | descripción>
    - Siguiente: <qué toca ahora al flujo principal>
