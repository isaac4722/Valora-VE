# Sistema de diseño «El Instrumento»

Tokens exactos validados contra MVP-CRUD.md §8 y la GUI dp4 (fuente visual
mandatoria). Archivo canónico: `lib/core/theme.dart` + `lib/widgets/ui.dart`.

## Paleta por rol

### Claro (canónico)
| Token | Valor | Uso |
|---|---|---|
| bg | `#F7F8F9` | fondo de app |
| card | `#FFFFFF` | tarjetas |
| fg | `#1A1D21` | texto principal |
| muted | `#F1F2F4` | rellenos suaves |
| muted-fg | `#5F6672` | texto secundario |
| primary | `#22354E` | azul tinta (tocable) |
| accent | `#EEF1F4` | acentos |
| border | `#D3D9DF` | SIEMPRE 100 % (prohibidas opacidades nuevas) |
| destructive | `#CF4437` | destructivo |

### Grafito (oscuro)
| Token | Valor |
|---|---|
| bg | `#121417` |
| card | `#1A1D21` |
| fg | `#ECEEF1` |
| muted | `#202429` |
| muted-fg | `#9AA1AB` |
| primary | `#8FA7C4` (fg sobre primary `#0E1622`) |
| border | `#3A4048` |
| destructive | `#F07A6C` |

## Semánticas de dinero y tasas
- pos `#10755A` / `#3ECF9E` · neg `#CF4437` / `#F07A6C` · warn `#B05E0E` / `#EDA25C`
- Tasa fija: **official** verde · **mixed** ámbar · **parallel** rojo · **manual** violeta `#6E5BB8`
- Divisas: VES azul · USD rojo · EUR violeta · COP oliva `#5D6B13` · BRL `#12873C` · MXN magenta `#B03D90`

## Tipografía
- **Inter 400–700**: cuerpo (empaquetada en `assets/fonts/`, primera ejecución
  sin red tipografí igual).
- **Space Grotesk 500/700**: display + `.display-num` con **cifras tabulares**
  (`FontFeature.tabularFigures()`) para héroes 48–64 px.
- `label-caps`: rótulos técnicos en mayúsculas con tracking 0.12, piso 9.5 px.

## Firmas visuales (componentes en `lib/widgets/ui.dart`)
| Firma | Componente |
|---|---|
| `.read-window` | `ReadWindow` — pozo hundido de la cifra héroe |
| `.stamp` | `Stamp` — sello 8 % con borde 38 % |
| `.ledger-dots::after` | `LedgerRow` + `_LedgerDots` — solo cierre de cuentas |
| `.ticker-mask/track` | `RateTicker` — cinta con loop −50 % y anti-CLS |
| `.skeleton-paper` | `SkeletonPaper` — altura exacta anti-CLS |
| `shadow-card/lift` | tema Material (elevación 0 + bordes) |
| AnimatedNumber | odómetro con curva EASE, sin setState por frame |

## Reglas duras
- Sin `backdrop-filter` en scroll · sin gradientes · sin tricolor (el logo es
  tile `#22354E` + V blanca) · sin `fixed-attachment`.
- El COLOR de datos solo significa (oficial/paralelo, sube/baja); el azul
  tinta señala lo tocable.

## Motion (§8)
- **1 idea por superficie**; solo transform/opacity (+blur 4 px ≤300 ms).
- Curva firma `EASE = [0.16, 1, 0.3, 1]` → `kEaseVe`.
- Duraciones: tap **120** · state **200** · layout **300** · entrance **600 ms**.
- `TAP .96` (`TapScale`) · stagger 45 ms cap 350 · `reducedMotion` del sistema
  respetado por `MediaQuery.disableAnimations`.
- Tickets compartidos: 1024 px JPEG .72 (~150–200 KB) · constancia PNG
  1080×1350 (4:5) con marca tile+V.

## Accesibilidad
- Contraste ≥ 4.5:1 (verificado por pares fg/fondo de la tabla).
- Blancos de toque ≥ 44 px (pestañas 58 px, botones 44+).
- `Semantics` en cifras protagonistas (ReadWindow y cotizaciones del héroe).
