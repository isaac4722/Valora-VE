---
name: rtk
description: RTK (Rust Token Killer) — proxy de CLI que comprime el output de comandos ruidosos (analyze, test, git, grep) para reducir tokens de INPUT del agente. Instalación brew install rtk o GitHub releases (github.com/rtk-ai/rtk); inicialización rtk init --global. Transversal a todo estado del flujo que ejecute shell.
---

# RTK · Rust Token Killer

## Qué es

Un binario Rust único, sin dependencias, que actúa como proxy de línea de
comandos: intercepta comandos ruidosos (`flutter analyze`, `flutter test`,
`git status`, `git diff`) y comprime su output para que el agente consuma
menos tokens de entrada con la misma información útil. Documentación y
releases: https://github.com/rtk-ai/rtk · web: https://www.rtk-ai.app

## Cuándo usarla (contrato AGENT.md)

Transversal: en TODO estado que ejecute shell. Los comandos del contrato
se prefieren prefijados con `rtk`:

```bash
rtk flutter analyze     # en vez de flutter analyze
rtk flutter test        # en vez de flutter test
rtk git status
rtk git diff --stat
rtk grep
```

## Instalación

```bash
# macOS (Homebrew)
brew install rtk

# Linux/macOS (releases de GitHub)
# ver https://github.com/rtk-ai/rtk/releases

# Inicialización (hook global del agente)
rtk init --global
```

En entornos sin Homebrew ni acceso a releases, este skill se usa como
referencia de la herramienta y se trabaja con los comandos directos; el
estado real se registra en `PROGRESS.md`.

## Regla RTK vs Caveman (contrato)

- RTK optimiza **input** (lo que el agente lee).
- Caveman optimiza **output** (lo que el agente dice).
- Se usan en capas; no se excluyen.

## Notas

- TODO: verificar flag exacto del instalador curl (`curl -fsSL ... | sh`)
  contra el README upstream antes de documentarlo aquí.
- Los builds de GitHub Actions NO usan rtk: el CI corre los comandos
  directos (`flutter analyze`, `flutter test`) sobre ubuntu-latest.
