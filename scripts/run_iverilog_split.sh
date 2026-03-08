#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_cmd iverilog
require_cmd vvp

SPLIT_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_split.x"
SEND_IR="${BUILD_DIR}/fetch_relu_split_send_addr.ir"
RECV_IR="${BUILD_DIR}/fetch_relu_split_recv_relu.ir"
SEND_SV="${BUILD_DIR}/fetch_relu_split_send_addr.sv"
RECV_SV="${BUILD_DIR}/fetch_relu_split_recv_relu.sv"
SIM_OUT="${BUILD_DIR}/fetch_relu_split_tb.out"
VCD_PATH="${VCD_PATH:-${BUILD_DIR}/fetch_relu_split_tb.vcd}"

SEND_CODEGEN_ARGS=(
  --top=__fetch_relu_split__SendAddr_0_next
  --generator=pipeline
  --pipeline_stages=1
  --clock_period_ps=1000
  --delay_model=unit
  --use_system_verilog
  --worst_case_throughput=1
  --reset=rst
)
RECV_CODEGEN_ARGS=(
  --top=__fetch_relu_split__RecvRelu_0_next
  --generator=pipeline
  --pipeline_stages=1
  --clock_period_ps=1000
  --delay_model=unit
  --use_system_verilog
  --worst_case_throughput=1
  --reset=rst
)
append_codegen_io_flags SEND_CODEGEN_ARGS
append_codegen_io_flags RECV_CODEGEN_ARGS

echo "== IR convert: split-stage procs"
"${TOOLS_DIR}/ir_converter_main" \
  "${SPLIT_DSLX}" \
  --top=SendAddr \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --output_file="${SEND_IR}"

"${TOOLS_DIR}/ir_converter_main" \
  "${SPLIT_DSLX}" \
  --top=RecvRelu \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --output_file="${RECV_IR}"

echo "== Codegen: SendAddr"
"${TOOLS_DIR}/codegen_main" \
  "${SEND_IR}" \
  "${SEND_CODEGEN_ARGS[@]}" \
  --output_verilog_path="${SEND_SV}"

echo "== Codegen: RecvRelu"
"${TOOLS_DIR}/codegen_main" \
  "${RECV_IR}" \
  "${RECV_CODEGEN_ARGS[@]}" \
  --output_verilog_path="${RECV_SV}"

echo "== Icarus compile"
iverilog -g2012 \
  -o "${SIM_OUT}" \
  "${ROOT_DIR}/tb/ram_fetch_relu/fetch_relu_tb_support.sv" \
  "${ROOT_DIR}/tb/ram_fetch_relu/fetch_relu_split_tb.sv" \
  "${SEND_SV}" \
  "${RECV_SV}"

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
