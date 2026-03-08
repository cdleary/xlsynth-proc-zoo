#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_cmd iverilog
require_cmd vvp

SINGLE_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_pipelined.x"
SINGLE_IR="${BUILD_DIR}/fetch_relu_single_pipelined.ir"
SINGLE_SV="${BUILD_DIR}/fetch_relu_single_pipelined.sv"
SIM_OUT="${BUILD_DIR}/fetch_relu_single_pipelined_tb.out"
VCD_PATH="${VCD_PATH:-${BUILD_DIR}/fetch_relu_single_pipelined_tb.vcd}"

echo "== IR convert: single software-pipelined proc"
"${TOOLS_DIR}/ir_converter_main" \
  "${SINGLE_DSLX}" \
  --top=FetchReluSinglePipelined \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${SINGLE_IR}"

echo "== Codegen: single software-pipelined proc"
"${TOOLS_DIR}/codegen_main" \
  "${SINGLE_IR}" \
  --top=__fetch_relu_single_pipelined__FetchReluSinglePipelined_0_next \
  --generator=pipeline \
  --pipeline_stages=2 \
  --clock_period_ps=1000 \
  --delay_model=unit \
  --use_system_verilog \
  --worst_case_throughput=1 \
  --reset=rst \
  --output_verilog_path="${SINGLE_SV}"

echo "== Icarus compile"
iverilog -g2012 \
  -o "${SIM_OUT}" \
  "${ROOT_DIR}/tb/ram_fetch_relu/fetch_relu_single_pipelined_tb.sv" \
  "${SINGLE_SV}"

echo "== Icarus run"
VVP_ARGS=()
if [[ "${DUMP_VCD:-0}" == "1" ]]; then
  echo "== VCD dump: ${VCD_PATH}"
  VVP_ARGS+=("+dump_vcd")
  VVP_ARGS+=("+dump_path=${VCD_PATH}")
fi
vvp "${SIM_OUT}" "${VVP_ARGS[@]}"
