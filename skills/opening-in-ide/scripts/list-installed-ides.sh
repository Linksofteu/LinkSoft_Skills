#!/usr/bin/env bash
set -euo pipefail

if command -v rider >/dev/null 2>&1 || command -v rider.bat >/dev/null 2>&1 || command -v rider64.exe >/dev/null 2>&1; then
  printf 'rider\n'
fi

if command -v code >/dev/null 2>&1; then
  printf 'code\n'
fi
