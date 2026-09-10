# Paridad vs `MVP-CRUD.md` — auditoría cerrada v1.0.2-beta

> Auditoría ítem × ítem del port Flutter contra el spec cerrado
> `MVP-CRUD.md` (14 secciones). Veredictos con evidencia `file:line` del
> estado **1.0.1-beta**; la columna «v1.0.2» indica el estado tras la
> ronda de cierre de esta release. Metodología: 4 auditorías paralelas
> (modelo/store · motor/tasas/alertas · 9 pantallas · diseño/nativo).

## 0. Marcador global

| Bloque del spec | 1.0.1-beta | v1.0.2-beta | Nota |
|---|---|---|---|
| Fase A · Modelo + persistencia (§1/§2/§10) | ~88 % | **~97 %** | bug crítico `addPurchase` corregido |
| Fase B · Motor dinero + tasas (§3/§4/§5/§7) | ~75 % | **~85 %** | integración alertas/health/SSE-days |
| Fase C · Pantallas (§9, 202 ítems) | ~65 % | **~78 %** | ver desglose por pantalla |
| §8 Diseño «El Instrumento» (tokens) | 90 % | **~97 %** | 26/29 hex exactos + firma visual |
| Fase D · Nativo Android (§12.2) | ~45 % | **~60 %** | scanner/foto/PNG reales; shortcuts siguen en D4 |
| **Global ponderado** | **≈ 65–70 %** | **≈ 80–84 %** | |

## 1. Desglose por pantalla (§9)

| Pantalla | 1.0.1 | v1.0.2 | Qué se cerró en v1.0.2 |
|---|---|---|---|
| Shell 9.0 | 69 % | **94 %** | LogoMark+flag+LiveBadge+frescura tap-refresca, RateHealthBanner siempre visible, anti-CLS del ticker, transición firma |
| Inicio 9.1 | 62 % | **85 %** | hora en héroe (30 s), /hora=176 LOTTT, copySalary ×3, «Divisas del foco», «Alertas de precios», cierres con dots |
| Conversor 9.2 | 71 % | **92 %** | héroes 56px tabulares, Ayer/7d cargan histórico REAL, notas con debounce, recientes con monto, PNG con marca |
| Lista 9.3 | 68 % | **86 %** | héroe 64px, shareTotals PNG, StoreSuggest pasivo, editar ítem |
| Productos 9.4 | 65 % | **87 %** | Importar CSV (importados/duplicados), editar/eliminar registro, «¡bajo tu meta!» |
| Historial 9.5 | 75 % | **86 %** | ticket real: miniatura + zoom 1-8× + compartir JPEG |
| Finanzas 9.6 | 67 % | **87 %** | orden 01→02→03, confirmar borrado, delta mes previo, paginador topeado |
| Análisis 9.7 | 50 % | **~60 %** | snapshotSeries respeta days (merge remoto+local); heatmap/proyección/rankings extra siguen en backlog |
| Ajustes 9.8 | 76 % | **91 %** | autoRefresh toggle, APP_VERSION «17.1 · build N», «Quitar sueldo» |
| Soporte 9.9 | 63 % | **78 %** | constancia PNG real (RepaintBoundary→share), scanner zoom+beep+haptic, splash de marca |

## 2. Bugs corregidos en v1.0.2 (hallados por la auditoría)

1. **`addPurchase` sin id (CRÍTICO)** — toda compra persistía `id=''`;
   «Eliminar compra» borraba el historial completo y el merge de backups
   descartaba todas las compras. Ahora genera id único
   (`store.dart` + `Purchase.copyWith(id:)`) con test.
2. **`setCountry` no actualizaba el conversor** — ahora fija
   `USD→monedaDelPaís` (§2.1).
3. **`snapshotSeries` ignoraba `days`** — las gráficas pedían N días y
   recibían la serie completa. Recorte por cutoff con test.
4. **AlertEngine no escribía al centro de notificaciones** — ahora cada
   aviso (pico/meta/brecha/daily/recordatorio) entra al ring vía
   `AlertPersist` inyectado, kinds §7 1:1.
5. **`RateHealthBanner` jamás montado + stale instantáneo** — regla §5
   real (>15 min SOLO si se vio antes), banner sobre el body con retry.
6. **`resetAll` conservaba settings** — ahora limpia todo excepto el
   tablero vivo (§2.5), con test.
7. **Dedupe `importProducts`** — barcode primero; nombre solo sin barcode.

## 3. Lo que sigue fuera (honesto)

- **Fase D restante**: 4 shortcuts (`quick_actions`), widgets BCV
  adicionales (hoy 1/13), biometría sin toggle, `price_targets` de
  producto en 2º plano, SSE vivo (el poll 60 s funciona; el cliente SSE
  existe sin instanciar).
- **Análisis 9.7**: heatmap 6 m, proyección punteada DAMP (el motor
  `predictPrice` φ=0.85 existe), rankings de compras/día/moneda,
  historial multi-divisa, exportGapCsv.
- **Motor**: ruta EUR de 4 tramos visible (hoy colapsada a 2 banderas),
  `direct` en ConversionPlan, Decimal exacto (hoy `double` tolerante),
  migración v1→v12 como cadena real (hoy parsing tolerante).
- **§8 micro**: hover-pausa del ticker (no aplica táctil), `accentDark`
  propio, `kInkNeg` de constancia ya unificado a `#CF4437`.

## 4. Cómo se validó

- Balance de llaves/imports y null-safety de `captureWidget` verificados
  localmente en los 18 archivos tocados.
- `flutter analyze` + `flutter test` en GitHub Actions (gate estricto,
  sin SDK local) → merge solo en verde; APK firmado y ofuscado por el
  workflow de `build.yml` y publicado en la Release del tag.
