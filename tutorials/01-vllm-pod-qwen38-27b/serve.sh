#!/usr/bin/env bash
set -Eeuo pipefail

MODEL_ID="${MODEL_ID:-gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090}"
MODEL_REVISION="${MODEL_REVISION:-main}"
VENV_DIR="${VENV_DIR:-/opt/vllm-env}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"

export PATH="$VENV_DIR/bin:$PATH"
export HF_HOME="${HF_HOME:-/workspace/.cache/huggingface}"
export MAX_JOBS="${MAX_JOBS:-2}"

command -v vllm >/dev/null

args=(
  "$MODEL_ID"
  --revision "$MODEL_REVISION"
  --served-model-name "$MODEL_ID"
  --quantization modelopt
  --kv-cache-dtype fp8
  --trust-remote-code
  --max-model-len 262144
  --max-num-seqs 16
  --gpu-memory-utilization 0.97
  --reasoning-parser qwen3
  --enable-auto-tool-choice
  --tool-call-parser qwen3_xml
  --host "$HOST"
  --port "$PORT"
)

exec vllm serve "${args[@]}"

