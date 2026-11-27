# ValoraVE · Flutter nativo (v2)

<div align="center">

[![CI](https://github.com/isaac4722/Valora-VE/actions/workflows/ci.yml/badge.svg)](https://github.com/isaac4722/Valora-VE/actions/workflows/ci.yml)
[![Build](https://github.com/isaac4722/Valora-VE/actions/workflows/build.yml/badge.svg)](https://github.com/isaac4722/Valora-VE/actions/workflows/build.yml)

</div>

> 📦 **Descarga actual:** [Última release](https://github.com/isaac4722/Valora-VE/releases/latest) — **4 APK firmados** (armeabi-v7a · arm64-v8a · x86_64 · universal), ofuscados (`--obfuscate --split-debug-info`), más un ZIP con LEEME y checksums. Desde v31 las releases son **solo APK** (el AAB se retiró): androids viejos (v7a), nuevos (arm64-v8a), **emuladores (x86_64)** y un **APK universal todo-en-uno** que instala sin saber la arquitectura.
>
> El historial completo de rondas vive en [CHANGELOG.md](CHANGELOG.md).
> El proceso de desarrollo queda en AGENT.md, MVP-CRUD.md, PROGRESS*.md y
> HALLAZGOS_*.md; este README describe solo la app.

**ValoraVE** es una app Android nativa (Flutter/Dart puro) para saber
cuánto vale tu dinero en Venezuela: tasas BCV y paralelo, conversor
multi-divisa (USD · VES · EUR · COP · BRL · MXN · USDT), lista de compras
compartida en vivo, libro de precios por producto, gastos automáticos
de tus compras y análisis de devaluación — todo **offline-first**, en tu
teléfono.

## Módulos
| Módulo | Qué hace |
|---|---|
| **Inicio** | la tasa del día con su fuente, cuatro acciones rápidas, tu mes y tu actividad reciente; la cotización completa vive en Tasas y los módulos secundarios en Más |
| **Conversor** | teclado propio VeKeypad + redondeo, precisión de 2/3/4 decimales (BCV publica 4), puente USD + EUR visible, fecha histórica honesta, notas, recientes y **Pago Móvil** compartible (cuentas propias con titular y logos reales de 27 bancos) |
| **Lista** | presupuesto, plantillas, vuelto, dividir la cuenta, **Modo Cachea** (simulador de inicial + cuotas), checkout con foto de ticket, **sala en vivo** |
| **Productos** | libro de precios con tiendas, sparklines, metas con aviso, CSV ⇄, escáner |
| **Historial** | asientos por compra, filtros, CSV de compras, constancias |
| **Análisis** | brecha BCV↔paralelo, devaluación, inflación personal, rankings, canasta, **gastos por tienda y por mes (auto, con tus compras)** |
| **Tasas** | cotización completa por divisa, tus tasas con nombre, edición manual y el estado de cada fuente |
| **Más** | Productos, Tickets, Ajustes, Actualizaciones y Privacidad (Análisis, Historial, Sala y Cuentas viven en sus sitios) |
| **Ajustes** | una pantalla por secciones: Cuentas y cobro, Tasas y fuentes, Alertas, Diagnóstico, País y decimales, Datos y conexión, Apariencia, Respaldo y Acerca de |

La sala en vivo tiene **cuatro transportes** con el mismo protocolo
(`lista-sync`): un **servidor socket.io** que tú decides (viene en
`server/lista-sync/`, listo para desplegar con Bun o Node), **Cerca**
(Google Nearby Connections: WiFi-Direct/Bluetooth, sin internet),
**Bluetooth clásico** (RFCOMM/SPP) y **WiFi local** (mismo SSID,
descubrimiento por broadcast). Sin conexión, los cambios quedan en outbox
y salen al reconectar.

## Cómo compilar
```bash
flutter pub get
flutter run                 # debug
flutter test                # unit + widget

# release (requiere android/keystore.properties — ver example):
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols/apk   # 3 APK, uno por ABI
flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols/apk   # universal (todo-en-uno)
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/aab
```

## Cómo hacer una release
Gates locales: `bash scripts/quality_gate.sh` (analyze + tests) e
integration tests en emulador. Un tag `v*` dispara el workflow
`build.yml`, que publica la GitHub Release con 4 APK (armeabi-v7a ·
arm64-v8a · x86_64 · universal) + ZIP (LEEME + checksums), firmados
con el keystore de secrets y ofuscados; sin AAB desde v31.

## Permisos (y por qué)
| Permiso | Uso |
|---|---|
| `INTERNET` + `ACCESS_NETWORK_STATE` | tablero de tasas, sala por servidor, degradación offline |
| `CAMERA` | foto de ticket y escáner de códigos |
| `VIBRATE` | háptica del escáner |
| `POST_NOTIFICATIONS` | alertas locales de picos/metas/brecha (API 33+) |
| `BLUETOOTH_SCAN/ADVERTISE/CONNECT` | sala P2P sin internet (API 31+) |
| `ACCESS_FINE_LOCATION` (API <31) | descubrimiento Nearby en dispositivos Android antiguos |
| `NEARBY_WIFI_DEVICES` | sala por WiFi local (API 33+) |

Nada más. Sin FCM: las notificaciones son locales (canales
`rate_alerts`, `price_targets`, `reminders`, `room_activity`, `default`).

## Documentación
- [CHANGELOG.md](CHANGELOG.md) — historial de versiones

## Privacidad
Sin cuentas, sin telemetría, sin nube: todo vive en tu teléfono. Los
respaldos son JSON tuyos. Fuentes de tasas: dolarapi.com (VE/CO/MX/BR),
dolarvzla.com (respaldo BCV), datos.gov.co, AwesomeAPI — consultas anónimas directas.

## Licencia
Software **PROPIETARIO** — Copyright (c) 2026 isaac4722. Todos los
derechos reservados. Sin uso público, sin distribución, sin
modificación ni reutilización de código sin autorización previa,
expresa y por escrito del titular. Ver el archivo
[LICENSE](LICENSE) completo. La visibilidad pública de este
repositorio NO es una autorización de uso.
