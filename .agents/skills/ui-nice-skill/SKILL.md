---
name: ui-nice-skill
description: Checklist visual para que cada pantalla de ValoraVE se vea "nice" antes y después de tocarla. Se activa en 1_ANALYZE (declarar dirección estética del encargo) y 4_AUDIT (auditar el diff visual pantalla por pantalla, elemento por elemento). No inventa estética nueva: audita contra el sistema de diseño vigente («El Instrumento», §8) y contra la web de referencia. Orden del dueño v19.9: no existía en ningún registro público y se creó como skill propia del repo.
version: 1.0.0
license: Propietaria (ValoraVE)
---

# UI Nice · análisis y auditoría visual en el 9P

> **Filosofía:** una pantalla "nice" no es la que tiene más adornos, es la
> que respira, jerarquiza y no sorprende al dedo. El color de datos solo
> significa algo; el resto es tinta y papel.
> **Ley:** si hay que explicar el arreglo visual con palabras, todavía no
> está arreglado. La captura lo demuestra sola.

Esta skill existe para que NINGÚN cambio de UI llegue a commit sin pasar
por una mirada visual deliberada: primero al analizar (¿hacia dónde va
esta pantalla?), después al auditar (¿quedó como se pidió?).

---

## Cuándo se activa (mapa al 9P)

| Estado del 9P | Qué hace esta skill | Salida esperada |
|---|---|---|
| **1_ANALYZE** | Leer la pantalla actual y el encargo; declarar «Design Read» (dirección estética en 1-2 líneas) ANTES de escribir código | Intención declarada en el turno |
| **4_AUDIT** | Auditar el diff visual: captura de ANTES y DESPUÉS, checklist completa, tabla de hallazgos | Hallazgos con severidad; cero rojos para cerrar |

Si el encargo NO toca UI, esta skill no aplica (decláralo y sigue).

---

## Parte 1 · Design Read (1_ANALYZE)

Antes de tocar un widget, responde en el turno:

1. **¿Qué pantalla es y qué rol cumple?** (héroe, trabajo, consulta, ajuste)
2. **¿Qué elemento manda?** — el ojo debe caer en UN sitio primero: la cifra
   héroe, el total, el dato fresco. Si dos elementos compiten, uno sobra o
   falta jerarquía.
3. **¿Qué dirección estética exige el sistema?** — leer
   `docs/DESIGN-SYSTEM.md` y los tokens de `lib/core/theme.dart` +
   `lib/widgets/ui.dart`. La respuesta ya está escrita: papel-tinta,
   bordes 100 %, tipografía Inter/Space Grotesk, sin gradientes.
4. **Declarar en 1-2 líneas** la intención (ej.: «el panel del día pasa a
   3 columnas con aire; la brecha deja de competir con la gráfica»).

**Prohibido en el Design Read:** inventar una dirección nueva («neón sobre
negro», «glassmorphism») que contradiga §8. Eso no es dirección, es fuga.

---

## Parte 2 · Auditoría visual (4_AUDIT)

### Cómo auditar con la web (modo verificación)

1. Compilar la web: `flutter build web` (el build vive en `build/web`).
2. Servirla en un puerto PRIVADO del agente (nunca en la preview del
   dueño, que permanece caída por orden) y abrir con agent-browser.
3. Navegar a la pantalla tocada; capturar ANTES (si existe build previo)
   y DESPUÉS.
4. Pasar la captura por VLM: «¿qué elemento compite? ¿qué se pega? ¿qué
   se desborda? ¿qué estado vacío parece roto?»
5. Asignar severidad a cada hallazgo y corregir en código; repetir hasta
   cero rojos.

### La checklist «nice» (12 puntos)

Cada punto se marca ✅/❌ contra la captura real, no de memoria:

| # | Punto | Qué mirar |
|---|---|---|
| 1 | **Aire** | Margen entre secciones ≥ entre elementos internos; nada pegado a otro bloque. Renglones de una lista no forman una pila densa |
| 2 | **Jerarquía** | Un solo protagonista por pantalla; secundarios en `muted-fg`; `label-caps` para rótulos técnicos |
| 3 | **Alineación** | Columnas compartidas entre tarjetas; ejes que coinciden; chips y píldoras en la misma línea base |
| 4 | **Contraste** | Texto `fg` sobre `bg`/`card`; jamás gris sobre gris; modo grafito revisado aparte |
| 5 | **Tipografía** | Cifras tabulares (`tabularFigures`) en héroes y tablas; Space Grotesk solo display; sin tamaños nuevos fuera de la escala |
| 6 | **Bordes y color** | Borde `border` al 100 % (sin opacidades nuevas); color de datos SOLO con significado (oficial/paralelo, sube/baja) |
| 7 | **Toque** | Targets ≥48dp; botones separados del borde de pantalla; nada que precise puntería |
| 8 | **Desbordes** | Textos largos con ellipsis/soft-wrap previsto; sin `RenderFlex overflow` ni scrolls horizontales accidentales |
| 9 | **Estados vacíos** | Sin datos ≠ pantalla rota: `InlineHint`/estado vacío con jerarquía y explicación humana |
| 10 | **Carga** | `SkeletonPaper` con altura exacta anti-CLS; nunca spinners sueltos flotando |
| 11 | **Idioma** | es-VE natural; sin «tells» de IA (pasar Humanizer si duda); cifras vía `lib/core/fmt.dart` |
| 12 | **Momento** | Animaciones con la curva/duración del sistema; `reducedMotion` respetado; sin parpadeos |

### Severidades

- 🔴 **Roto** — desborde, ilegible, target <44px, dato mentiroso → bloquea.
- 🟡 **Feo** — pegado, compite, desbalanceado → corregir antes de cerrar.
- 🟢 **Nice** — respira, jerarquiza, se explica solo → pasar.

### Anti-slop (señales de alarma)

- Tarjetas idénticas repetidas hasta el infinito (fila de clones).
- Un emoji por tarjeta «para dar vida».
- Sombras nuevas, radios nuevos, opacidades nuevas «para destacar».
- Padding mágico (7.5, 13, 22) en vez de los espaciados del sistema.
- Texto que repite el título de la tarjeta dentro de la tarjeta.
- Gradiente «sutil». En este sistema no hay: si brilla, está mal.

Si aparecen 2 o más señales, activar también `taste-skill` como filtro
anti-genérico (4_AUDIT opcional).

---

## Reglas duras (heredadas de §8 · docs/DESIGN-SYSTEM.md)

- Sin `backdrop-filter` en scroll · sin gradientes · sin tricolor · sin
  `fixed-attachment`.
- El azul `primary` es tinta de acción, no decoración.
- `border` SIEMPRE 100 % de opacidad.
- El sistema de diseño se EVOLUCIONA, no se reemplaza (AGENT.md · Nunca
  hacer).

## Regla de No Contradicción

Si esta skill sugiere algo que viola el AGENT.md (límites de tres
niveles), **manda el AGENT.md**. Si sugiere inventar cifras para «verse
mejor», manda AGENT.md otra vez: la honestidad de datos no se negocia.
