#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

for example in \
  "${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_sequential.x" \
  "${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_dual_token.x" \
  "${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_nonblocking.x" \
  "${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_single_pipelined.x" \
  "${ROOT_DIR}/examples/ram_fetch_relu/fetch_relu_split.x"
do
  echo "== DSLX interpreter test: ${example}"
  "${TOOLS_DIR}/dslx_interpreter_main" \
    "${example}" \
    --dslx_path "${ROOT_DIR}" \
    --dslx_stdlib_path "${DSLX_STDLIB_PATH}" \
    --type_inference_v2=true \
    --compare=none
done
