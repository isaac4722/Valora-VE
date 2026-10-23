---
name: vlm
description: VLM Skill — verificación visual de la app compilada en web local mediante capturas de pantalla analizadas por un modelo de visión (VLM). Se usa en el estado 3.5 VISUAL GATE del AGENT.md cuando una función pasa de lógica a full stack o GUI. Descarta slop/BASURA visual; NO rediseña.
---

# VLM Skill · Verificación visual (3.5 VISUAL GATE)

## Propósito

Verificar que lo implementado en `lib/` se VE como debe verse — y que no
parece generado por IA genérica (slop) — usando capturas reales de la
app compilada, nunca el recuerdo del código.

## Procedimiento (el usado en este repo)

1. **Compilar web local** (sin tocar la preview del dueño):
   `flutter build web` sobre el árbol del repo.
2. **Servir en puerto privado del agente** — NUNCA en el puerto de la
   preview del usuario. En el entorno del agente: 3099 vía
   `scripts/web_privado.sh start|stop|status` (fuera del repo). El
   servidor estático debe servir MIME correcto (incl. `.wasm`) y fallback
   SPA para los deep links del router.
3. **Capturar pantallas** navegando con el navegador headless del agente
   (agent-browser): cada pantalla tocada por el encargo, incluidos los
   estados que el encargo modifica (vacío, con datos, error, offline).
4. **Analizar cada captura con VLM** (modelo de visión) contra el
   encargo: jerarquía, alineaciones, aire, contraste, textos cortados,
   estados vacíos que parecen pantallas rotas, alineaciones por defecto
   de plantilla. Criterio: ¿esto lo firmaría un diseñador de la casa?
5. **Borrar las capturas al terminar** (son temporales; no se commitean).

## Reglas

- **NO rediseñar** durante el gate: si hay hallazgo, se reporta y se
  corrige en `3_IMPLEMENT` con las skills de diseño, no «de ojo» aquí.
- **No inventar cifras**: las capturas usan los datos vivos que sirva el
  tablero o el estado sembrado por los propios tests.
- Hallazgos → `6_RETRY` → `3_IMPLEMENT` (regla de la máquina de estados).
- Si el gate visual detecta riesgo de AI slop generalizado, activar
  `taste-skill` en `4_AUDIT` (opcional, según contrato).

## Evidencia

El resultado del gate se declara en `PROGRESS.md` (una línea: qué
pantallas se verificaron y el veredicto), sin pegar las capturas.
