#!/usr/bin/env bash
# tools/rotar_bitacora.sh — rotación de la bitácora de tres niveles (AGENT.md)
#
# Uso:
#   tools/rotar_bitacora.sh            rota los archivos REALES del repo
#   tools/rotar_bitacora.sh --prueba   rota COPIAS en tmp (nunca toca los reales)
#
# Reglas del contrato:
#   PROGRESS.md (hot, ≤10 líneas) → PROGRESS_WARM.md (≤10 entradas)
#     → PROGRESS_COLD.md (por hito; 10 líneas por sección).
#   CHANGELOG.md (hot, 3 versiones) → CHANGELOG_WARM.md (≤10)
#     → CHANGELOG_COLD.md (historial).
#   Prohibido duplicar información entre los tres archivos.
#
# El hot solo conserva las piezas del TURNO ACTIVO (líneas tras la última
# rotación); las líneas «DOING» del turno abierto nunca bajan.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRUEBA="${1:-}"
WORK="$REPO"

if [[ "$PRUEBA" == "--prueba" ]]; then
  WORK="$(mktemp -d /tmp/rotar_prueba.XXXXXX)"
  for f in PROGRESS.md PROGRESS_WARM.md PROGRESS_COLD.md \
           CHANGELOG.md CHANGELOG_WARM.md CHANGELOG_COLD.md; do
    cp "$REPO/$f" "$WORK/$f"
  done
  # Semilla de prueba: simula un turno cerrado con 2 piezas y una versión
  # extra en el CHANGELOG hot — SOLO en las copias, nunca en los reales.
  printf '2026-10-02 · DONE · PRUEBA-A · pieza de pega · gate VERDE · 9_CLOSE\n' >> "$WORK/PROGRESS.md"
  printf '2026-10-02 · DONE · PRUEBA-B · pieza de pega · gate VERDE · 9_CLOSE\n' >> "$WORK/PROGRESS.md"
  printf '\n## 9.9.9-prueba+99 · PRUEBA — bloque de pega\n\n- Entrada de prueba que jamás toca los archivos reales.\n' >> "$WORK/CHANGELOG.md"
  echo "== MODO PRUEBA: se trabaja sobre $WORK (los reales no se tocan) =="
elif [[ -n "$PRUEBA" && "$PRUEBA" != "--forzar" ]]; then
  echo "uso: $0 [--prueba|--forzar]" >&2
  exit 64
fi

fecha() { date +%Y-%m; }

# ── PROGRESS: líneas de entrada = las que empiezan por «20» (fecha) ─────────
rotar_progress() {
  local hot="$WORK/PROGRESS.md" warm="$WORK/PROGRESS_WARM.md" cold="$WORK/PROGRESS_COLD.md"
  # Entradas cerradas del hot: todas menos la línea del turno abierto (DOING).
  local entradas
  entradas="$(grep -n '^20' "$hot" | grep -v '· DOING ·' || true)"
  [[ -z "$entradas" ]] && { echo "PROGRESS: nada que rotar (turno abierto o vacío)"; return 0; }

  local lineas=()
  while IFS= read -r l; do lineas+=("${l%%:*}"); done <<< "$entradas"

  # Mover cada entrada cerrada al final del warm.
  for n in "${lineas[@]}"; do
    sed -n "${n}p" "$hot" >> "$warm"
  done
  # Quitar del hot las líneas movidas (de abajo hacia arriba para no mover índices).
  for ((i=${#lineas[@]}-1; i>=0; i--)); do
    sed -i "${lineas[i]}d" "$hot"
  done
  echo "PROGRESS: ${#lineas[@]} entrada(s) bajaron a WARM"

  # WARM > 10 entradas → las más viejas bajan al COLD (sección del mes).
  local n_warm
  n_warm="$(grep -c '^20' "$warm" || true)"
  if (( n_warm > 10 )); then
    local excedente=$(( n_warm - 10 ))
    local seccion="## Hito $(fecha) · rotación automática"
    grep -qF "$seccion" "$cold" || printf '\n%s\n\n' "$seccion" >> "$cold"
    local movidas=()
    while IFS= read -r l; do movidas+=("${l%%:*}"); done < <(grep -n '^20' "$warm" | head -n "$excedente")
    for n in "${movidas[@]}"; do
      sed -n "${n}p" "$warm" >> "$cold"
    done
    for ((i=${#movidas[@]}-1; i>=0; i--)); do
      sed -i "${movidas[i]}d" "$warm"
    done
    echo "PROGRESS: $excedente entrada(s) de WARM bajaron a COLD ($seccion)"
  fi
}

# ── CHANGELOG: bloques «^## versión», hot conserva los 3 más recientes ──────
# Orden de los tres archivos: newest-first (el más nuevo ARRIBA).
# v33: arreglo del script — antes insertaba los bloques entrantes DESPUÉS
# del primer encabezado de WARM (partía la entrada) y al superar 10 movía
# los primeros bloques (los MÁS NUEVOS) a COLD. Ahora: los entrantes van
# ARRIBA del todo (tras el título) y a COLD bajan los ÚLTIMOS (los más
# viejos, al final del archivo), también por arriba de la lista de COLD.
rotar_changelog() {
  local hot="$WORK/CHANGELOG.md" warm="$WORK/CHANGELOG_WARM.md" cold="$WORK/CHANGELOG_COLD.md"
  local bloques=()
  while IFS= read -r l; do bloques+=("${l%%:*}"); done < <(grep -n '^## ' "$hot" || true)
  local n=${#bloques[@]}
  if (( n <= 3 )); then
    echo "CHANGELOG: nada que rotar ($n versión(es) en hot)"
  else
    local desde="${bloques[3]}"   # primera línea del 4º bloque
    sed -n "${desde},\$p" "$hot" > "$WORK/.rot_bloque"
    # exactamente una línea en blanco al final del bloque movido
    printf '%s\n\n' "$(cat "$WORK/.rot_bloque")" > "$WORK/.rot_bloque"
    # Insertar los bloques entrantes ANTES del primer encabezado de WARM
    # (nuevos encima: newest-first); si no hay encabezados, al final.
    local cabecera_warm
    cabecera_warm="$(awk '/^## /{print NR; exit}' "$warm")"
    if [[ -n "${cabecera_warm:-}" ]]; then
      head -n "$((cabecera_warm - 1))" "$warm" > "$WORK/.rot_warm_new"
      cat "$WORK/.rot_bloque" >> "$WORK/.rot_warm_new"
      tail -n "+${cabecera_warm}" "$warm" >> "$WORK/.rot_warm_new"
      mv "$WORK/.rot_warm_new" "$warm"
    else
      cat "$WORK/.rot_bloque" >> "$warm"
    fi
    rm -f "$WORK/.rot_bloque"
    sed -i "$((desde - 1)),\$d" "$hot"   # recorta el hot (con su línea en blanco previa)
    echo "CHANGELOG: $(( n - 3 )) versión(es) bajaron a WARM"
  fi

  # WARM > 10 bloques → los más VIEJOS (al FINAL del archivo) bajan al
  # COLD, insertados por ARRIBA de su lista (newest-first).
  local wbloques=()
  while IFS= read -r l; do wbloques+=("${l%%:*}"); done < <(grep -n '^## ' "$warm" || true)
  local wn=${#wbloques[@]}
  if (( wn > 10 )); then
    local quitar=$(( wn - 10 ))
    local primera="${wbloques[$((wn - quitar))]}"   # primer bloque a mover (de los viejos, el más nuevo)
    sed -n "${primera},\$p" "$warm" > "$WORK/.rot_warm"
    # exactamente una línea en blanco al final del bloque movido
    printf '%s\n\n' "$(cat "$WORK/.rot_warm")" > "$WORK/.rot_warm"
    local cabecera_cold
    cabecera_cold="$(awk '/^## /{print NR; exit}' "$cold")"
    if [[ -n "${cabecera_cold:-}" ]]; then
      head -n "$((cabecera_cold - 1))" "$cold" > "$WORK/.rot_cold_new"
      cat "$WORK/.rot_warm" >> "$WORK/.rot_cold_new"
      tail -n "+${cabecera_cold}" "$cold" >> "$WORK/.rot_cold_new"
      mv "$WORK/.rot_cold_new" "$cold"
    else
      cat "$WORK/.rot_warm" >> "$cold"
    fi
    sed -i "$((primera - 1)),\$d" "$warm"   # recorta (con su línea en blanco previa)
    rm -f "$WORK/.rot_warm"
    echo "CHANGELOG: $quitar versión(es) de WARM bajaron a COLD"
  fi
}

rotar_progress
rotar_changelog

if [[ "$PRUEBA" == "--prueba" ]]; then
  echo "== RESULTADO DE LA PRUEBA (conteos) =="
  for f in PROGRESS.md PROGRESS_WARM.md PROGRESS_COLD.md; do
    echo "  $f: $(grep -c '^20' "$WORK/$f" || true) entradas"
  done
  for f in CHANGELOG.md CHANGELOG_WARM.md CHANGELOG_COLD.md; do
    echo "  $f: $(grep -c '^## ' "$WORK/$f" || true) versiones"
  done
  echo "== fin de la prueba (descarta $WORK) =="
fi
