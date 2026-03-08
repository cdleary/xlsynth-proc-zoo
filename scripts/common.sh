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

append_codegen_io_flags() {
  local -n args_ref="$1"

  if [[ -n "${FLOP_INPUTS:-}" ]]; then
    args_ref+=("--flop_inputs=${FLOP_INPUTS}")
  fi
  if [[ -n "${FLOP_OUTPUTS:-}" ]]; then
    args_ref+=("--flop_outputs=${FLOP_OUTPUTS}")
  fi
  if [[ -n "${FLOP_INPUTS_KIND:-}" ]]; then
    args_ref+=("--flop_inputs_kind=${FLOP_INPUTS_KIND}")
  fi
  if [[ -n "${FLOP_OUTPUTS_KIND:-}" ]]; then
    args_ref+=("--flop_outputs_kind=${FLOP_OUTPUTS_KIND}")
  fi
}
