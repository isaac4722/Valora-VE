# Paridad vs `MVP-CRUD.md` — auditoría cerrada v1.0.2-beta

> Auditoría ítem × ítem del port Flutter contra el spec cerrado
> `MVP-CRUD.md` (14 secciones). Veredictos con evidencia `file:line` del
> estado **1.0.1-beta**; la columna «v1.0.2» indica el estado tras la
> ronda de cierre de esta release. Metodología: 4 auditorías paralelas
> (modelo/store · motor/tasas/alertas · 9 pantallas · diseño/nativo).

## 0. Marcador global

| Bloque del spec | 1.0.1-beta | v1.0.2-beta | v1.7-beta · Nota |
|---|---|---|---|---|
| Fase A · Modelo + persistencia (§1/§2/§10) | ~88 % | **~97 %** | **~97 %** | sin cambios (ya casi cerrado) |
| Fase B · Motor dinero + tasas (§3/§4/§5/§7) | ~75 % | **~85 %** | **~93 %** | ConversionPlan.direct + ruta EUR 4 tramos + SSE vivo + price_targets 2º plano |
| Fase C · Pantallas (§9, 202 ítems) | ~65 % | **~78 %** | **~90 %** | Análisis 9.7 casi cerrado + Ola 1 + biometría |
| §8 Diseño «El Instrumento» (tokens) | 90 % | **~97 %** | **~98 %** | accentDark documentado en DESIGN-SYSTEM |
| Fase D · Nativo Android (§12.2) | ~45 % | **~60 %** | **~85 %** | familia de widgets 3/3 funcionales + shortcuts ya 4/4 |
| **Global ponderado** | **≈ 65–70 %** | **≈ 80–84 %** | **≈ 92–94 %** | |

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
| Análisis 9.7 | 50 % | **~60 %** | v17.7: heatmap 6 m + proyección DAMP punteada + rankings día/moneda + exportGapCsv + histórico multi-divisa → **~95 %** |
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

> Ronda **1.1.0-dp4** (rama `fix/v1.1.0-dp4-paridad`) cerró: shortcuts
> `quick_actions` (4/4), Decimal exacto en `cartTotals`/`computeChange`,
> notificaciones testeables desde Ajustes y la identidad visual dp4.
> Ronda **v17.7** (1.6.0-beta+14, misma rama) cerró ADEMÁS: ruta EUR de
> 4 tramos visible + `ConversionPlan.direct`, heatmap 6 m (D2), proyección
> punteada DAMP, rankings compras/día/moneda, exportGapCsv, histórico
> multi-divisa, biometría con toggle, SSE vivo, `price_targets` de producto
> en 2º plano, familia de widgets BCV (3/3 por subclassing), país en la
> bienvenida y coach-marks por feature (D3). Queda:

- **Fase D restante**: familia de widgets ampliable (más tamaños/celdas si
  el dueño los pide), hotspots de rendimiento de lista (hoy todo va suave;
  sin medición en dispositivo no se declara «optimizado»).
- **Motor**: migración v1→v12 como cadena real (hoy parsing tolerante —
  funciona, pero no es la cadena documentada del §10).
- **§8 micro**: hover-pausa del ticker (no aplica táctil). `accentDark`
  propio: ya definido (#242A32) y ahora documentado en DESIGN-SYSTEM.md.
- **Pulido de reestructura**: `ui.dart` (1871 líneas, kit compartido) y
  `home_screen.dart`/`lista_screen.dart` (~1000) siguen enteros — el corte
  se aplicó a los dos peores (converter 1515→845, settings 1102→211).

## 4. Cómo se validó

- Balance de llaves/imports y null-safety de `captureWidget` verificados
  localmente en los 18 archivos tocados.
- `flutter analyze` + `flutter test` en GitHub Actions (gate estricto,
  sin SDK local) → merge solo en verde; APK firmado y ofuscado por el
  workflow de `build.yml` y publicado en la Release del tag.
