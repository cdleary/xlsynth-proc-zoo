#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

SINGLE_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single.x"
SINGLE_IR="${BUILD_DIR}/fetch_relu_single.ir"
SINGLE_WCT1_STDOUT="${BUILD_DIR}/fetch_relu_single_wct1.stdout"
SINGLE_WCT1_STDERR="${BUILD_DIR}/fetch_relu_single_wct1.stderr"

SINGLE_PIPELINED_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_pipelined.x"
SINGLE_PIPELINED_IR="${BUILD_DIR}/fetch_relu_single_pipelined.ir"
SINGLE_PIPELINED_SV="${BUILD_DIR}/fetch_relu_single_pipelined.sv"

SINGLE_DUAL_TOKEN_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_dual_token.x"
SINGLE_DUAL_TOKEN_IR="${BUILD_DIR}/fetch_relu_single_dual_token.ir"
SINGLE_DUAL_TOKEN_SV="${BUILD_DIR}/fetch_relu_single_dual_token.sv"

SINGLE_NONBLOCKING_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_nonblocking.x"
SINGLE_NONBLOCKING_IR="${BUILD_DIR}/fetch_relu_single_nonblocking.ir"
SINGLE_NONBLOCKING_SV="${BUILD_DIR}/fetch_relu_single_nonblocking.sv"

SPLIT_DSLX="${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_split.x"
SEND_IR="${BUILD_DIR}/fetch_relu_split_send_addr.ir"
RECV_IR="${BUILD_DIR}/fetch_relu_split_recv_relu.ir"
SEND_SV="${BUILD_DIR}/fetch_relu_split_send_addr.sv"
RECV_SV="${BUILD_DIR}/fetch_relu_split_recv_relu.sv"

echo "== IR convert: single proc"
"${TOOLS_DIR}/ir_converter_main" \
  "${SINGLE_DSLX}" \
  --top=FetchReluSingle \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${SINGLE_IR}"

echo "== Codegen check: single proc at worst_case_throughput=1 (expected to fail)"
if "${TOOLS_DIR}/codegen_main" \
    "${SINGLE_IR}" \
    --top=__fetch_relu_single__FetchReluSingle_0_next \
    --generator=pipeline \
    --pipeline_stages=1 \
    --clock_period_ps=1000 \
    --delay_model=unit \
    --use_system_verilog \
    --worst_case_throughput=1 \
    --output_verilog_path="${BUILD_DIR}/fetch_relu_single_wct1_should_fail.sv" \
    >"${SINGLE_WCT1_STDOUT}" 2>"${SINGLE_WCT1_STDERR}"
then
  echo "single-proc codegen unexpectedly succeeded at worst_case_throughput=1" >&2
  exit 1
fi

echo "== IR convert: single software-pipelined proc"
"${TOOLS_DIR}/ir_converter_main" \
  "${SINGLE_PIPELINED_DSLX}" \
  --top=FetchReluSinglePipelined \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${SINGLE_PIPELINED_IR}"

echo "== Codegen check: single software-pipelined proc at worst_case_throughput=1 (expected to pass with 2 pipeline stages)"
"${TOOLS_DIR}/codegen_main" \
  "${SINGLE_PIPELINED_IR}" \
  --top=__fetch_relu_single_pipelined__FetchReluSinglePipelined_0_next \
  --generator=pipeline \
  --pipeline_stages=2 \
  --clock_period_ps=1000 \
  --delay_model=unit \
  --use_system_verilog \
  --worst_case_throughput=1 \
  --reset=rst \
  --output_verilog_path="${SINGLE_PIPELINED_SV}"

echo "== IR convert: single dual-token proc"
"${TOOLS_DIR}/ir_converter_main" \
  "${SINGLE_DUAL_TOKEN_DSLX}" \
  --top=FetchReluSingleDualToken \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${SINGLE_DUAL_TOKEN_IR}"

echo "== Codegen check: single dual-token proc at worst_case_throughput=1 (expected to pass with reset)"
"${TOOLS_DIR}/codegen_main" \
  "${SINGLE_DUAL_TOKEN_IR}" \
  --top=__fetch_relu_single_dual_token__FetchReluSingleDualToken_0_next \
  --generator=pipeline \
  --pipeline_stages=1 \
  --clock_period_ps=1000 \
  --delay_model=unit \
  --use_system_verilog \
  --worst_case_throughput=1 \
  --reset=rst \
  --output_verilog_path="${SINGLE_DUAL_TOKEN_SV}"

echo "== IR convert: single non-blocking proc"
"${TOOLS_DIR}/ir_converter_main" \
  "${SINGLE_NONBLOCKING_DSLX}" \
  --top=FetchReluSingleNonBlocking \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${SINGLE_NONBLOCKING_IR}"

echo "== Codegen check: single non-blocking proc at worst_case_throughput=1 (expected to pass with 1 pipeline stage)"
"${TOOLS_DIR}/codegen_main" \
  "${SINGLE_NONBLOCKING_IR}" \
  --top=__fetch_relu_single_nonblocking__FetchReluSingleNonBlocking_0_next \
  --generator=pipeline \
  --pipeline_stages=1 \
  --clock_period_ps=1000 \
  --delay_model=unit \
  --use_system_verilog \
  --worst_case_throughput=1 \
  --reset=rst \
  --output_verilog_path="${SINGLE_NONBLOCKING_SV}"

echo "== IR convert: split-stage procs"
"${TOOLS_DIR}/ir_converter_main" \
  "${SPLIT_DSLX}" \
  --top=SendAddr \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${SEND_IR}"

"${TOOLS_DIR}/ir_converter_main" \
  "${SPLIT_DSLX}" \
  --top=RecvRelu \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${RECV_IR}"

echo "== Codegen check: split-stage procs at worst_case_throughput=1 (expected to pass)"
"${TOOLS_DIR}/codegen_main" \
  "${SEND_IR}" \
  --top=__fetch_relu_split__SendAddr_0_next \
  --generator=pipeline \
  --pipeline_stages=1 \
  --clock_period_ps=1000 \
  --delay_model=unit \
  --use_system_verilog \
  --worst_case_throughput=1 \
  --output_verilog_path="${SEND_SV}"

"${TOOLS_DIR}/codegen_main" \
  "${RECV_IR}" \
  --top=__fetch_relu_split__RecvRelu_0_next \
  --generator=pipeline \
  --pipeline_stages=1 \
  --clock_period_ps=1000 \
  --delay_model=unit \
  --use_system_verilog \
  --worst_case_throughput=1 \
  --output_verilog_path="${RECV_SV}"

echo "single-token single proc rejects WCT=1, single software-pipelined proc is schedulable at WCT=1 with 2 stages, single dual-token proc is schedulable at WCT=1 with reset, single non-blocking proc reaches WCT=1 with 1 stage, and split-stage procs also reach WCT=1"
