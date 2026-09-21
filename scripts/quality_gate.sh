#!/usr/bin/env bash
# ============================================================================
# quality_gate.sh · Gate de Calidad de ValoraVE (AGENT.md · Comandos)
# Ejecuta: (1) flutter analyze — 0 issues · (2) flutter test — suite verde
#          (3) auditoría UI — patrones prohibidos en lib/
# Uso: bash scripts/quality_gate.sh   (exit 0 = todo verde)
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

FALLOS=0

paso() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
mal()  { printf '  \033[31m✗ %s\033[0m\n' "$1"; FALLOS=$((FALLOS+1)); }

# ---------------------------------------------------------------------------
paso "[1/3] flutter analyze (esperado: 0 issues)"
# flutter analyze sale !=0 si hay issues → set -e aborta con el listado.
flutter analyze
ok "analyze limpio"

# ---------------------------------------------------------------------------
paso "[2/3] flutter test (esperado: suite verde)"
flutter test
ok "suite de tests verde"

# ---------------------------------------------------------------------------
paso "[3/3] Auditoría UI (patrones prohibidos en lib/)"
# grep es portátil en los runners (ubuntu-latest) y en dev locales.

auditar() { # $1 = patrón ERE · $2 = descripción · $3 = ficheros
  if grep -rEn --include='*.dart' "$1" $3 >/tmp/gate_grep.txt 2>/dev/null; then
    mal "VIOLACIÓN: $2"
    sed 's/^/      /' /tmp/gate_grep.txt | head -20
  else
    ok "$2"
  fi
}

LIB='lib'
# Con límites de AGENT.md: prohibidos en lib/
auditar 'AppStateScope'                                    'sin AppStateScope en lib/'                        "$LIB"
auditar 'localStorage'                                     'sin localStorage (patrón web) en lib/'            "$LIB"
auditar 'ServiceWorker'                                   'sin ServiceWorker en lib/'                        "$LIB"
auditar '(package:mockito|package:mocktail|[Mm]ockito[A-Z]|extends Mock)' 'sin mocks en lib/'             "$LIB"
auditar '(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})' 'sin tokens/secretos hardcodeados' "$LIB"
# Reglas duras de diseño (docs/DESIGN-SYSTEM.md · §8)
auditar 'backdropFilter'                                  'sin backdrop-filter en scroll (§8)'             "$LIB"
auditar 'LinearGradient|RadialGradient|SweepGradient'    'sin gradientes (§8)'                              "$LIB"

# Nota: constant_identifier_names está apagado por diseño (códigos ISO),
# y print( se permite solo en tools/ fuera de lib/ — no se audita aquí
# lo que el analyzer ya caza mejor.

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FALLOS" -gt 0 ]; then
  printf '\033[31mGATE EN ROJO: %s violación(es). Corrige y vuelve a correr.\033[0m\n' "$FALLOS"
  exit 1
fi
printf '\033[32mGATE VERDE: analyze 0 · tests verdes · auditoría UI limpia.\033[0m\n'
