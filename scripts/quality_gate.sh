#!/usr/bin/env bash
# ─── Gate de calidad local (espejo del CI) ──────────────────────────────────
# Contrato AGENT.md: analyze + test + auditoría de prohibiciones, TODO verde
# antes de persistir (7_PERSIST). El CI (.github/workflows/ci.yml) re-verifica
# los dos primeros en ubuntu-latest + Flutter 3.47.4 + Temurin 17.
set -euo pipefail
cd "$(dirname "$0")/.."

paso() { printf '\n== %s ==\n' "$1"; }

paso "1/3 · flutter pub get"
flutter pub get

paso "2/3 · flutter analyze (0 issues)"
flutter analyze

paso "3/3 · flutter test (suite completa)"
flutter test

paso "Auditoría de prohibiciones del contrato en lib/"
# R5 del AGENT.md: nada de AppStateScope, patrones web prohibidos ni mocks
# en lib/ (los fakes viven en test/, detrás de seams — ver docs/agent/TESTING.md).
if grep -rnE 'AppStateScope|ServiceWorker|localStorage' lib/; then
  echo "VIOLACIÓN: patrones web prohibidos en lib/"; exit 1
fi
if grep -rnE 'class +[A-Za-z_]*Mock[A-Za-z_]*' lib/; then
  echo "VIOLACIÓN: mocks en lib/ (los dobles van en test/)"; exit 1
fi
echo "OK: lib/ limpia de patrones prohibidos"

printf '\nGate de calidad: VERDE (analyze 0 · suite verde · lib/ limpia)\n'
