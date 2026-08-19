#!/bin/bash
set -euo pipefail

# Compile infra/main.bicep to build/main.json (compiled ARM template).
# Usage: ./scripts/bicep-build.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
MAIN_TEMPLATE="$ROOT_DIR/infra/main.bicep"

if [ ! -f "$MAIN_TEMPLATE" ]; then
  echo "Error: $MAIN_TEMPLATE not found" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

az bicep build --file "$MAIN_TEMPLATE" --outfile "$BUILD_DIR/main.json"

# Some environments ship a broken `az bicep build` wrapper that exits 0 without
# writing the outfile. Fall back to the standalone Bicep binary when that happens.
if [ ! -f "$BUILD_DIR/main.json" ]; then
  BICEP_BIN="${BICEP_BIN:-/root/.azure/bin/bicep}"
  if [ -x "$BICEP_BIN" ]; then
    echo "Warning: az bicep build produced no output; retrying with $BICEP_BIN"
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 "$BICEP_BIN" build "$MAIN_TEMPLATE" --outfile "$BUILD_DIR/main.json"
  fi
fi

if [ ! -f "$BUILD_DIR/main.json" ]; then
  echo "Error: bicep build did not produce $BUILD_DIR/main.json" >&2
  exit 1
fi

echo "OK: compiled ARM template -> build/main.json"