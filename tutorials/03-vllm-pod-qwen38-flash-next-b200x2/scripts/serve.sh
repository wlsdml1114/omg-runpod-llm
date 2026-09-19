#!/usr/bin/env bash
set -euo pipefail

: "${VLLM_API_KEY:?Set VLLM_API_KEY before exposing port 8000}"

export HF_HOME="${HF_HOME:-/workspace/.cache/huggingface}"
export TORCHINDUCTOR_CACHE_DIR="${TORCHINDUCTOR_CACHE_DIR:-/workspace/.cache/torchinductor}"
export VLLM_CACHE_ROOT="${VLLM_CACHE_ROOT:-/workspace/.cache/vllm}"

exec vllm serve Inferact/Qwen3.8-Flash-Next-NVFP4 \
  --revision 103a7608316173ca6edd49929544244de7ffda70 \
  --host 0.0.0.0 \
  --port 8000 \
  --served-model-name qwen3.8-flash-next-nvfp4 \
  --tensor-parallel-size 2 \
  --distributed-executor-backend mp \
  --dtype bfloat16 \
  --quantization modelopt_fp4 \
  --gpu-memory-utilization 0.90 \
  --max-model-len 32768 \
  --max-num-batched-tokens 4096 \
  --max-num-seqs 4 \
  --no-enable-prefix-caching \
  --no-enable-flashinfer-autotune \
  --language-model-only \
  --generation-config vllm \
  --reasoning-parser qwen3 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder
