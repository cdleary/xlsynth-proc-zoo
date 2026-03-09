#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

PATTERN_DSLX="${ROOT_DIR}/examples/send_recv_patterns/send_recv_patterns.x"
SUMMARY_MANIFEST="${BUILD_DIR}/send_recv_patterns_manifest.tsv"
SUMMARY_MD="${BUILD_DIR}/send_recv_patterns_summary.md"

cat /dev/null > "${SUMMARY_MANIFEST}"

while IFS='|' read -r proc_name pipeline_stages; do
  ir_path="${BUILD_DIR}/send_recv_patterns_${proc_name}.ir"
  schedule_path="${BUILD_DIR}/send_recv_patterns_${proc_name}.schedule"
  sv_path="${BUILD_DIR}/send_recv_patterns_${proc_name}.sv"

  echo "== IR convert: ${proc_name}"
  "${TOOLS_DIR}/ir_converter_main" \
    "${PATTERN_DSLX}" \
    --top="${proc_name}" \
    --dslx_path "${ROOT_DIR}" \
    --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
    --type_inference_v2 \
    --output_file="${ir_path}"

  echo "== Codegen schedule: ${proc_name}"
  "${TOOLS_DIR}/codegen_main" \
    "${ir_path}" \
    --top="__send_recv_patterns__${proc_name}_0_next" \
    --generator=pipeline \
    --pipeline_stages="${pipeline_stages}" \
    --clock_period_ps=1000 \
    --delay_model=unit \
    --use_system_verilog \
    --worst_case_throughput=1 \
    --reset=rst \
    --output_verilog_path="${sv_path}" \
    --output_schedule_path="${schedule_path}"

  printf "%s\t%s\t%s\t%s\n" \
    "${proc_name}" \
    "${pipeline_stages}" \
    "${ir_path}" \
    "${schedule_path}" \
    >> "${SUMMARY_MANIFEST}"
done <<'EOF'
RecvThenSend|2
SendThenRecv|2
SerialTwoRecvsThenSend|2
ParallelTwoRecvsThenSend|2
SerialTwoSends|2
ParallelTwoSends|2
BlockingRoundTrip|2
ParallelSendRecvThenSend|2
NonBlockingRoundTrip|2
EOF

python3 "${ROOT_DIR}/scripts/summarize_send_recv_patterns.py" \
  "${SUMMARY_MANIFEST}" \
  > "${SUMMARY_MD}"

cat "${SUMMARY_MD}"
