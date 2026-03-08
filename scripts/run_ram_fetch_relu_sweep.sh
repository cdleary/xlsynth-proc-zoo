#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_cmd python3

SWEEP_DIR="${BUILD_DIR}/ram_fetch_relu_sweep"
mkdir -p "${SWEEP_DIR}"

CASES=(
  "l1_nominal 1 0 0 0 0 80"
  "l2_nominal 2 0 0 0 0 80"
  "l3_nominal 3 0 0 0 0 80"
  "l1_reqstall_1of4 1 4 1 0 0 80"
  "l1_outstall_1of4 1 0 0 4 1 80"
  "l1_bothstall_1of4 1 4 1 4 1 100"
  "l2_outstall_1of4 2 0 0 4 1 100"
)

ANALYZE_ARGS=()

for case_spec in "${CASES[@]}"; do
  read -r case_name ram_latency req_period req_cycles out_period out_cycles timeout_cycles <<<"${case_spec}"

  split_vcd="${SWEEP_DIR}/${case_name}_split.vcd"
  nonblocking_vcd="${SWEEP_DIR}/${case_name}_single_nonblocking.vcd"

  echo "== Sweep case: ${case_name} (split)"
  TIMEOUT_CYCLES="${timeout_cycles}" \
  RAM_LATENCY="${ram_latency}" \
  RAM_REQ_STALL_PERIOD="${req_period}" \
  RAM_REQ_STALL_CYCLES="${req_cycles}" \
  OUT_CH_STALL_PERIOD="${out_period}" \
  OUT_CH_STALL_CYCLES="${out_cycles}" \
  DUMP_VCD=1 \
  VCD_PATH="${split_vcd}" \
  bash "${ROOT_DIR}/scripts/run_iverilog_split.sh"

  echo "== Sweep case: ${case_name} (single_nonblocking)"
  TIMEOUT_CYCLES="${timeout_cycles}" \
  RAM_LATENCY="${ram_latency}" \
  RAM_REQ_STALL_PERIOD="${req_period}" \
  RAM_REQ_STALL_CYCLES="${req_cycles}" \
  OUT_CH_STALL_PERIOD="${out_period}" \
  OUT_CH_STALL_CYCLES="${out_cycles}" \
  DUMP_VCD=1 \
  VCD_PATH="${nonblocking_vcd}" \
  bash "${ROOT_DIR}/scripts/run_iverilog_single_nonblocking.sh"

  ANALYZE_ARGS+=(--case "${case_name}" split "${split_vcd}")
  ANALYZE_ARGS+=(--case "${case_name}" single_nonblocking "${nonblocking_vcd}")
done

echo "== Analyze sweep"
python3 "${ROOT_DIR}/scripts/analyze_ram_fetch_relu_sweep.py" "${ANALYZE_ARGS[@]}"
