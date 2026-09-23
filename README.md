# ValoraVE · Flutter nativo (v2)

<div align="center">

[![CI](https://github.com/isaac4722/Valora-VE/actions/workflows/ci.yml/badge.svg)](https://github.com/isaac4722/Valora-VE/actions/workflows/ci.yml)
[![Build](https://github.com/isaac4722/Valora-VE/actions/workflows/build.yml/badge.svg)](https://github.com/isaac4722/Valora-VE/actions/workflows/build.yml)

</div>

> 📦 **Descarga actual:** [Release v1.0.2-beta](https://github.com/isaac4722/Valora-VE/releases/latest) — APK firmados por ABI (armeabi-v7a · arm64-v8a · x86_64) + AAB, ofuscados (`--obfuscate --split-debug-info`). Desde v17.9 cada build produce **APK para cualquier dispositivo**: androids viejos (v7a), nuevos (arm64-v8a), **emuladores (x86_64, ya en cada push)** y un **APK universal todo-en-uno** (~45 MB) que instala sin saber la arquitectura.
>
> **v1.0.2-beta** cierra la ronda de paridad contra `MVP-CRUD.md` (bug
> crítico de `addPurchase`, histórico real del conversor, flujos §9) y
> **v1.0.1-beta** arregló el bug que dejaba la app clavada en la pantalla
> de bienvenida (router recreado en cada rebuild) y el icono transparente
> del lanzador; añade escáner de códigos, sueldo variable, recordatorio
> diario, StoreSheet, compartir PNG del conversor y barras 6/12.

**ValoraVE** es una app Android nativa (Flutter/Dart puro) para saber
cuánto vale tu dinero en Venezuela: tasas BCV y paralelo, conversor
multi-divisa (USD · VES · EUR · COP · BRL · MXN), lista de compras
compartida en vivo, libro de precios por producto, gastos automáticos
de tus compras y análisis de devaluación — todo **offline-first**, en tu
teléfono.

## Módulos
| Módulo | Qué hace |
|---|---|
| **Inicio** | tablero del país, resumen del mes con tus compras, tiendas, recientes |
| **Conversor** | puente USD + EUR visible, fecha histórica honesta, ruta del cálculo, notas y recientes |
| **Lista** | presupuesto, plantillas, vuelto, dividir la cuenta, checkout con foto de ticket, **sala en vivo** |
| **Productos** | libro de precios con tiendas, sparklines, metas con aviso, CSV ⇄, escáner |
| **Historial** | asientos por compra, filtros, CSV de compras, constancias |
| **Análisis** | brecha BCV↔paralelo, devaluación, inflación personal, rankings, canasta, **gastos por tienda y por mes (auto, con tus compras)** |
| **Ajustes** | país, cinta, fuentes por módulo, alertas, respaldos JSON, tema |

La sala en vivo tiene **tres transportes** con el mismo protocolo
(`lista-sync`): un **servidor socket.io** que tú decides (viene en
`server/lista-sync/`, listo para desplegar con Bun o Node), **Cerca**
(Google Nearby Connections: WiFi-Direct/Bluetooth, sin internet) y
**WiFi local** (mismo SSID, descubrimiento por broadcast). Sin conexión,
los cambios quedan en outbox y salen al reconectar.

## Cómo compilar
```bash
flutter pub get
flutter run                 # debug
flutter test                # unit + widget (140 tests)

# release (requiere android/keystore.properties — ver example):
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols/apk   # 3 APK por ABI
flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols/apk   # universal (todo-en-uno)
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/aab
```

## Cómo hacer una release
Ver **[docs/RELEASE.md](docs/RELEASE.md)**: gates locales, integration
tests en emulador, tag `v*` → el workflow `build.yml` publica la GitHub
Release con 4 APK (armeabi-v7a · arm64-v8a · x86_64 · universal) + AAB
firmados con el keystore de secrets y ofuscados.

## Permisos (y por qué)
| Permiso | Uso |
|---|---|
| `INTERNET` + `ACCESS_NETWORK_STATE` | tablero de tasas, sala por servidor, degradación offline |
| `CAMERA` | foto de ticket y escáner de códigos |
| `VIBRATE` | háptica del escáner |
| `POST_NOTIFICATIONS` | alertas locales de picos/metas/brecha (API 33+) |
| `BLUETOOTH_SCAN/ADVERTISE/CONNECT` | sala P2P sin internet (API 31+) |
| `ACCESS_FINE_LOCATION` (API <31) | descubrimiento Nearby en Android antiguos |
| `NEARBY_WIFI_DEVICES` | sala por WiFi local (API 33+) |

Nada más. Sin FCM: las notificaciones son locales (canales
`rate_alerts`, `price_targets`, `reminders`, `room_activity`, `default`).

## Documentación
- [AGENT.md](AGENT.md) — contrato de trabajo para agentes: método en 9 pasos
- [PROGRESS.md](PROGRESS.md) — bitácora hot (3 niveles: PROGRESS · progress_warm · progress_archive)
- [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md) — tokens «El Instrumento»
- [docs/agent/DEPENDENCIAS.md](docs/agent/DEPENDENCIAS.md) — plugins oficiales y trampas
- [docs/PARIDAD.md](docs/PARIDAD.md) — paridad 1:1 contra el spec §14
- [docs/MIGRACION.md](docs/MIGRACION.md) — decisiones desde 0
- [docs/RELEASE.md](docs/RELEASE.md) — checklist de release
- [CHANGELOG.md](CHANGELOG.md) — historial de versiones

## Privacidad
Sin cuentas, sin telemetría, sin nube: todo vive en tu teléfono. Los
respaldos son JSON tuyos. Fuentes de tasas: dolarapi.com (VE/CO/MX/BR),
pydolarve.org, datos.gov.co, AwesomeAPI — consultas anónimas directas.

## Licencia
Software **PROPIETARIO** — Copyright (c) 2026 isaac4722. Todos los
derechos reservados. Sin uso público, sin distribución, sin
modificación ni reutilización de código sin autorización previa,
expresa y por escrito del titular. Ver el archivo
[LICENSE](LICENSE) completo. La visibilidad pública de este
repositorio NO es una autorización de uso.
