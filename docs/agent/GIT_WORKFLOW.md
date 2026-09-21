# GIT_WORKFLOW · Flujo de Git y commits (ValoraVE)

Consulta obligatoria en `7_PERSIST`.

## Ramas

- **Rama de trabajo vigente:** `fix/v1.1.0-dp4-paridad` (todo el ciclo
  9P corre aquí).
- **`main`** solo recibe merge con ORDEN EXPRESA del dueño (regla
  vigente desde v17.x; el historial de `progress.md` lo respalda).
- Nada de ramas nuevas por cuenta propia: se trabaja en la rama de
  trabajo del turno, salvo orden del dueño.

## Commits (conventional, en español)

Formato: `tipo(ámbito): descripción en minúscula y español`

| Tipo | Cuándo |
|---|---|
| `feat` | Función nueva o ampliación de módulo |
| `fix` | Bug arreglado (con test de regresión) |
| `polish` | Refinamiento visual/UX sin cambio funcional |
| `refactor` | Misma conducta, mejor estructura |
| `test` | Solo tests |
| `docs` | Solo documentación (AGENT.md, docs/, progress.md) |
| `chore` | Tooling, CI, scripts |
| `perf` | Rendimiento |

- **1 pieza por commit.** Si el turno tocó 3 piezas, son 3 commits.
- El mensaje describe QUÉ cerró, no lo que intentaste («fix(9P):
  conversor 40000→4 + código de sala invertido», no «cambios»).
- El cuerpo del commit (si hace falta) resume verificación: gates,
  decisiones, desviaciones conscientes.

## Gates ANTES de cada commit (AGENT.md · Siempre hacer)

```
flutter analyze   # 0 issues
flutter test      # suite verde
```

O el unificado: `bash scripts/quality_gate.sh`.

## Secretos

- El PAT de GitHub y `android/keystore.properties` NUNCA se commitean
  (`keystore.properties.example` documenta el formato esperado).
- Si un secreto apareciera en el diff: detener el turno, avisar al dueño
  y rotar la credencial antes de seguir.

## Push y CI (paso 8 del 9P)

1. `git push origin fix/v1.1.0-dp4-paridad`.
2. Esperar el run de **CI** (pub get → quality_gate.sh: analyze + test +
   auditoría UI) hasta verde. Si falla: `6_RETRY` — corregir y volver a
   pushar.
3. En tags `v*`, **Build** produce los 4 APK + AAB + ZIP completo y la
   Release los adjunta (regla del dueño v17.9/v19.2: cobertura total de
   dispositivos; prohibido retirar un ABI, el AAB o el ZIP).

## progress.md

- Se LEE completo al empezar el turno (con AGENT.md) y se AÑADE la
  entrada al cerrar (nunca reescribir secciones ajenas).
- La entrada registra: orden del dueño, qué se hizo, decisiones,
  gates reales (analyze/test/build), bloqueos y siguiente paso.
- Sin entrada en `progress.md`, el trabajo no existe (Definición de
  Hecho).

## Hygiene

- El working tree queda LIMPIO al cerrar el turno (nada de WIP colgando).
- `dart format .` antes de commit; archivos generados (`build/`,
  `.dart_tool/`) jamás entran al índice.
