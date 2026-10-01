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
rotar_changelog() {
  local hot="$WORK/CHANGELOG.md" warm="$WORK/CHANGELOG_WARM.md" cold="$WORK/CHANGELOG_COLD.md"
  local bloques=()
  while IFS= read -r l; do bloques+=("${l%%:*}"); done < <(grep -n '^## ' "$hot" || true)
  local n=${#bloques[@]}
  if (( n <= 3 )); then
    echo "CHANGELOG: nada que rotar ($n versión(es) en hot)"
  else
    local desde="${bloques[3]}"   # primera línea del 4º bloque
    # El bloque baja a WARM justo después de su cabecera (orden newest-first).
    local cabecera_warm
    cabecera_warm="$(awk '/^## /{print NR; exit}' "$warm")"
    sed -n "${desde},\$p" "$hot" > "$WORK/.rot_bloque"
    if [[ -n "${cabecera_warm:-}" ]]; then
      sed -i "$((cabecera_warm))r $WORK/.rot_bloque" "$warm"
    else
      cat "$WORK/.rot_bloque" >> "$warm"
    fi
    rm -f "$WORK/.rot_bloque"
    sed -i "$((desde - 1)),\$d" "$hot"   # recorta el hot (con su línea en blanco previa)
    echo "CHANGELOG: $(( n - 3 )) versión(es) bajaron a WARM"
  fi

  # WARM > 10 bloques → los más viejos bajan al COLD (top de su lista).
  local wbloques=()
  while IFS= read -r l; do wbloques+=("${l%%:*}"); done < <(grep -n '^## ' "$warm" || true)
  local wn=${#wbloques[@]}
  if (( wn > 10 )); then
    local quitar=$(( wn - 10 ))
    local primera="${wbloques[0]}"              # bloque más VIEJO (al inicio)
    local ultima="${wbloques[$((quitar-1))]}"   # último bloque a mover
    local hasta=$(( ultima - 1 ))
    local cabecera_cold
    cabecera_cold="$(awk '/^## /{print NR; exit}' "$cold")"
    sed -n "${primera},${hasta}p" "$warm" > "$WORK/.rot_warm"
    if [[ -n "${cabecera_cold:-}" ]]; then
      sed -i "$((cabecera_cold))r $WORK/.rot_warm" "$cold"
    else
      cat "$WORK/.rot_warm" >> "$cold"
    fi
    sed -i "${primera},${hasta}d" "$warm"
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
