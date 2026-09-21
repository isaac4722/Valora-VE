# TESTING · Estrategia de testing (ValoraVE)

Consulta obligatoria en `4_AUDIT`. El gate que aplica esto:
`bash scripts/quality_gate.sh` (analyze + test + auditoría UI).

## Mapa de la suite

- `test/` refleja la estructura de `lib/`: un archivo de test por módulo
  (`store_test.dart`, `room_test.dart`, `insights_utils_test.dart`,
  `fmt_test.dart`, `currencies_test.dart`, `board_test.dart`, …).
- Suite vigente: **196 tests verdes** (v19.8: 185 previos + 11 de PIN de
  emojis y deep link). El número exacto vive en `progress.md`; este
  documento describe la estrategia, no el conteo.
- `integration_test/app_test.dart` existe para humo de integración (no
  corre en CI; el CI corre unit + widget).

## Reglas de oro

1. **Toda pieza nueva llega con su test** (Definición de Hecho, AGENT.md).
   Si tocas lógica en `lib/`, el test que la cubre se actualiza en el
   mismo commit — jamás después.
2. **Determinismo primero:** nada de `Future.delayed` mágicos ni
   `pumpAndSettle` con tickers infinitos (el ticker de la cinta y los
   odómetros nunca se asientan: usar `pump(duración explícita)`).
3. **Sin red real:** los tests no llaman APIs. Los datos de tasas se
   inyectan como `RateBoard`/`RateEntry` ya construidos.
4. **Round-trip como patrón:** persistencia y respaldo se prueban
   ida/vuelta (`store_test.dart` es el ejemplo canónico: escribir →
   leer → comparar; respaldo viejo → cargar → tolerar).
5. **Los tests NO se debilitan.** Si un test falla y tras 2 intentos no
   entiendes la causa raíz: PREGUNTAR (AGENT.md · Preguntar primero).
   Prohibido borrar/saltar el test para ponerte verde.

## Capas

| Capa | Qué cubre | Ejemplos |
|---|---|---|
| **Unit pura** | Motor de tasas, formato, utilidades de análisis, protocolo de sala | `currencies_test.dart`, `fmt_test.dart`, `insights_utils_test.dart`, `room_test.dart` |
| **Unit con estado** | Store Hive, respaldo/migración, modelos, alertas | `store_test.dart`, `models_backup_test.dart`, `tips_test.dart` |
| **Widget** | Pantallas y componentes: render, interacción, accesibilidad | `widgets_test.dart`, `rate_sheet_test.dart`, `sharing_test.dart`, `push_screen_test.dart` |
| **Plataforma** | Puentes nativos (AppWidgets, conectividad) | `app_widgets_test.dart`, `connectivity_test.dart` |

## Cómo ejecutar

```bash
flutter test                                    # suite completa (gate)
flutter test test/store_test.dart               # una pieza
flutter test test/store_test.dart --name "tag"  # un caso
flutter analyze                                 # ANTES de testear (0 issues)
```

## Cuándo un bug entra a la suite

Todo bug arreglado deja un test que lo reprime (regresión). Ejemplo
canónico: el conversor 40000→4 (v19.8) — el caso quedó clavado en
`fmt_test.dart`/`currencies_test.dart` para que no vuelva a ocurrir.
