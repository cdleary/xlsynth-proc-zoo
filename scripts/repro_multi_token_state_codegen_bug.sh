#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

INPUT="${ROOT_DIR}/repros/multi_token_state_codegen_bug.x"
IR="${BUILD_DIR}/multi_token_state_codegen_bug.ir"

echo "== IR convert"
"${TOOLS_DIR}/ir_converter_main" \
  "${INPUT}" \
  --top=MultiTokenState \
  --dslx_path "${ROOT_DIR}" \
  --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
  --type_inference_v2 \
  --proc_scoped_channels \
  --output_file="${IR}"

echo "== Codegen without reset (expected to fail with current XLS bug)"
if "${TOOLS_DIR}/codegen_main" \
    "${IR}" \
    --top=__multi_token_state_codegen_bug__MultiTokenState_0_next \
    --generator=pipeline \
    --pipeline_stages=1 \
    --clock_period_ps=1000 \
    --delay_model=unit \
    --use_system_verilog \
    --worst_case_throughput=1 \
    --output_verilog_path="${BUILD_DIR}/multi_token_state_codegen_bug.sv"
then
  echo "unexpected success: multi-token-state proc codegen no longer reproduces the bug" >&2
  exit 1
fi

echo "== Codegen with reset (also expected to fail with current XLS bug)"
if "${TOOLS_DIR}/codegen_main" \
    "${IR}" \
    --top=__multi_token_state_codegen_bug__MultiTokenState_0_next \
    --generator=pipeline \
    --pipeline_stages=1 \
    --clock_period_ps=1000 \
    --delay_model=unit \
    --use_system_verilog \
    --worst_case_throughput=1 \
    --reset=rst \
    --output_verilog_path="${BUILD_DIR}/multi_token_state_codegen_bug_reset.sv"
then
  echo "unexpected success: reset-enabled multi-token-state proc codegen no longer reproduces the bug" >&2
  exit 1
fi

echo "Observed expected codegen failure for multi-token proc state."
