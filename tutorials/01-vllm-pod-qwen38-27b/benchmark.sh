#!/usr/bin/env bash
set -Eeuo pipefail

MODEL_ID="${MODEL_ID:-gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
VENV_DIR="${VENV_DIR:-/opt/vllm-env}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-262144}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RESULT_DIR="${RESULT_DIR:-/workspace/vllm-run/benchmarks/$RUN_ID}"

if ((MAX_MODEL_LEN < 62000)); then
  echo "The long benchmark requires MAX_MODEL_LEN >= 62000" >&2
  exit 1
fi

export PATH="$VENV_DIR/bin:$PATH"
mkdir -p "$RESULT_DIR"
command -v vllm >/dev/null

if [[ -n "${API_KEY:-}" ]]; then
  export OPENAI_API_KEY="$API_KEY"
else
  unset OPENAI_API_KEY || true
fi

run_case() {
  local name="$1" input_len="$2" output_len="$3" prompts="$4" concurrency="$5"
  vllm bench serve \
    --backend openai-chat \
    --base-url "$BASE_URL" \
    --endpoint /v1/chat/completions \
    --model "$MODEL_ID" \
    --dataset-name random \
    --random-input-len "$input_len" \
    --random-output-len "$output_len" \
    --num-prompts "$prompts" \
    --max-concurrency "$concurrency" \
    --temperature 0 \
    --save-result \
    --result-dir "$RESULT_DIR" \
    --result-filename "$name.json" \
    | tee "$RESULT_DIR/$name.txt"
}

run_case bench-c1 512 128 10 1
run_case bench-c4 512 128 20 4
run_case bench-62k 61775 128 1 1

echo "Benchmarks finished; results: $RESULT_DIR"
