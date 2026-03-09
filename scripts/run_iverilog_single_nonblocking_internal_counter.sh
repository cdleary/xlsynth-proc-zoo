#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_cmd iverilog
require_cmd vvp

SINGLE_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_nonblocking_internal_counter.x"
SINGLE_IR="${BUILD_DIR}/fetch_relu_single_nonblocking_internal_counter.ir"
SINGLE_SV="${BUILD_DIR}/fetch_relu_single_nonblocking_internal_counter.sv"
SIM_OUT="${BUILD_DIR}/fetch_relu_single_nonblocking_internal_counter_tb.out"
VCD_PATH="${VCD_PATH:-${BUILD_DIR}/fetch_relu_single_nonblocking_internal_counter_tb.vcd}"

CODEGEN_ARGS=(
  --top=__fetch_relu_single_nonblocking_internal_counter__FetchReluSingleNonBlockingInternalCounter_0_next
  --generator=pipeline
  --pipeline_stages=1
  --clock_period_ps=1000
  --delay_model=unit
  --use_system_verilog
  --worst_case_throughput=1
  --reset=rst
)
append_codegen_io_flags CODEGEN_ARGS

echo "== IR convert: single non-blocking proc with internal counter"
"${TOOLS_DIR}/ir_converter_main" \
  "${SINGLE_DSLX}" \
  --top=FetchReluSingleNonBlockingInternalCounter \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --output_file="${SINGLE_IR}"

echo "== Codegen: single non-blocking proc with internal counter"
"${TOOLS_DIR}/codegen_main" \
  "${SINGLE_IR}" \
  "${CODEGEN_ARGS[@]}" \
  --output_verilog_path="${SINGLE_SV}"

echo "== Icarus compile"
iverilog -g2012 \
  -o "${SIM_OUT}" \
  "${ROOT_DIR}/tb/ram_fetch_relu/fetch_relu_tb_support.sv" \
  "${ROOT_DIR}/tb/ram_fetch_relu/fetch_relu_single_nonblocking_internal_counter_tb.sv" \
  "${SINGLE_SV}"

echo "== Icarus run"
VVP_ARGS=()
if [[ -n "${TIMEOUT_CYCLES:-}" ]]; then
  VVP_ARGS+=("+timeout_cycles=${TIMEOUT_CYCLES}")
fi
if [[ -n "${RAM_LATENCY:-}" ]]; then
  VVP_ARGS+=("+ram_latency=${RAM_LATENCY}")
fi
if [[ -n "${RAM_REQ_STALL_PERIOD:-}" ]]; then
  VVP_ARGS+=("+ram_req_stall_period=${RAM_REQ_STALL_PERIOD}")
fi
if [[ -n "${RAM_REQ_STALL_CYCLES:-}" ]]; then
  VVP_ARGS+=("+ram_req_stall_cycles=${RAM_REQ_STALL_CYCLES}")
fi
if [[ -n "${OUT_CH_STALL_PERIOD:-}" ]]; then
  VVP_ARGS+=("+out_ch_stall_period=${OUT_CH_STALL_PERIOD}")
fi
if [[ -n "${OUT_CH_STALL_CYCLES:-}" ]]; then
  VVP_ARGS+=("+out_ch_stall_cycles=${OUT_CH_STALL_CYCLES}")
fi
if [[ "${DUMP_VCD:-0}" == "1" ]]; then
  echo "== VCD dump: ${VCD_PATH}"
  VVP_ARGS+=("+dump_vcd")
  VVP_ARGS+=("+dump_path=${VCD_PATH}")
fi
vvp "${SIM_OUT}" "${VVP_ARGS[@]}"
