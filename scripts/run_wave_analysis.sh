#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_cmd python3

SPLIT_VCD="${BUILD_DIR}/fetch_relu_split_tb.vcd"
SINGLE_PIPELINED_VCD="${BUILD_DIR}/fetch_relu_single_pipelined_tb.vcd"
SINGLE_COLD_STEADY_DRAIN_VCD="${BUILD_DIR}/fetch_relu_single_cold_steady_drain_tb.vcd"
SINGLE_DUAL_TOKEN_VCD="${BUILD_DIR}/fetch_relu_single_dual_token_tb.vcd"
SINGLE_NONBLOCKING_VCD="${BUILD_DIR}/fetch_relu_single_nonblocking_tb.vcd"
SINGLE_NONBLOCKING_INTERNAL_COUNTER_VCD="${BUILD_DIR}/fetch_relu_single_nonblocking_internal_counter_tb.vcd"

echo "== Generate split waveform dump"
DUMP_VCD=1 VCD_PATH="${SPLIT_VCD}" bash "${ROOT_DIR}/scripts/run_iverilog_split.sh"

echo "== Generate single software-pipelined waveform dump"
DUMP_VCD=1 VCD_PATH="${SINGLE_PIPELINED_VCD}" bash "${ROOT_DIR}/scripts/run_iverilog_single_pipelined.sh"

echo "== Generate single cold/steady/drain waveform dump"
DUMP_VCD=1 VCD_PATH="${SINGLE_COLD_STEADY_DRAIN_VCD}" bash "${ROOT_DIR}/scripts/run_iverilog_single_cold_steady_drain.sh"

echo "== Generate single dual-token waveform dump"
DUMP_VCD=1 VCD_PATH="${SINGLE_DUAL_TOKEN_VCD}" bash "${ROOT_DIR}/scripts/run_iverilog_single_dual_token.sh"

echo "== Generate single non-blocking waveform dump"
DUMP_VCD=1 VCD_PATH="${SINGLE_NONBLOCKING_VCD}" bash "${ROOT_DIR}/scripts/run_iverilog_single_nonblocking.sh"

echo "== Generate single non-blocking waveform dump with internal counter"
DUMP_VCD=1 VCD_PATH="${SINGLE_NONBLOCKING_INTERNAL_COUNTER_VCD}" bash "${ROOT_DIR}/scripts/run_iverilog_single_nonblocking_internal_counter.sh"

echo "== Analyze waveforms"
python3 "${ROOT_DIR}/scripts/analyze_ram_fetch_relu_waves.py" \
  --variant split "${SPLIT_VCD}" \
  --variant single_pipelined "${SINGLE_PIPELINED_VCD}" \
  --variant single_cold_steady_drain "${SINGLE_COLD_STEADY_DRAIN_VCD}" \
  --variant single_dual_token "${SINGLE_DUAL_TOKEN_VCD}" \
  --variant single_nonblocking "${SINGLE_NONBLOCKING_VCD}" \
  --variant single_nonblocking_internal_counter "${SINGLE_NONBLOCKING_INTERNAL_COUNTER_VCD}"
