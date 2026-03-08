#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TOOLS_DIR="${XLSYNTH_TOOLS:?set XLSYNTH_TOOLS to your xlsynth tools bundle}"
DSLX_STDLIB_PATH="${TOOLS_DIR}/xls/dslx/stdlib"
BUILD_DIR="${ROOT_DIR}/build"

mkdir -p "${BUILD_DIR}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}
