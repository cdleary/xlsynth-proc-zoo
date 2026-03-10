#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_cmd iverilog
require_cmd vvp

SIM_OUT="${BUILD_DIR}/ram_env_latency_tb.out"

echo "== Icarus compile: RAM latency check"
iverilog -g2012 \
  -o "${SIM_OUT}" \
  "${ROOT_DIR}/tb/ram_fetch_relu/fetch_relu_tb_support.sv" \
  "${ROOT_DIR}/tb/ram_fetch_relu/ram_env_latency_tb.sv"

echo "== Icarus run: RAM latency check"
VVP_ARGS=()
if [[ -n "${RAM_LATENCY:-}" ]]; then
  VVP_ARGS+=("+ram_latency=${RAM_LATENCY}")
fi
vvp "${SIM_OUT}" "${VVP_ARGS[@]}"
