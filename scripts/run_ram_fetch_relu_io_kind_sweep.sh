#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_cmd python3

SWEEP_DIR="${BUILD_DIR}/ram_fetch_relu_io_kind_sweep"
mkdir -p "${SWEEP_DIR}"

OUTPUT_KINDS=(flop skid zerolatency)
CASES=(
  "l1_nominal 1 0 0 0 0 80"
  "l1_outstall_1of4 1 0 0 4 1 80"
)
VARIANTS=(
  "split scripts/run_iverilog_split.sh"
  "single_nonblocking scripts/run_iverilog_single_nonblocking.sh"
  "single_pipelined scripts/run_iverilog_single_pipelined.sh"
)

ANALYZE_ARGS=()

for output_kind in "${OUTPUT_KINDS[@]}"; do
  for case_spec in "${CASES[@]}"; do
    read -r case_name ram_latency req_period req_cycles out_period out_cycles timeout_cycles <<<"${case_spec}"
    labeled_case="${case_name}_outkind_${output_kind}"

    for variant_spec in "${VARIANTS[@]}"; do
      read -r variant_name script_path <<<"${variant_spec}"
      vcd_path="${SWEEP_DIR}/${labeled_case}_${variant_name}.vcd"

      echo "== I/O-kind case: ${labeled_case} (${variant_name})"
      TIMEOUT_CYCLES="${timeout_cycles}" \
      RAM_LATENCY="${ram_latency}" \
      RAM_REQ_STALL_PERIOD="${req_period}" \
      RAM_REQ_STALL_CYCLES="${req_cycles}" \
      OUT_CH_STALL_PERIOD="${out_period}" \
      OUT_CH_STALL_CYCLES="${out_cycles}" \
      FLOP_OUTPUTS_KIND="${output_kind}" \
      DUMP_VCD=1 \
      VCD_PATH="${vcd_path}" \
      bash "${ROOT_DIR}/${script_path}"

      ANALYZE_ARGS+=(--case "${labeled_case}" "${variant_name}" "${vcd_path}")
    done
  done
done

echo "== Analyze I/O-kind sweep"
python3 "${ROOT_DIR}/scripts/analyze_ram_fetch_relu_sweep.py" "${ANALYZE_ARGS[@]}"
