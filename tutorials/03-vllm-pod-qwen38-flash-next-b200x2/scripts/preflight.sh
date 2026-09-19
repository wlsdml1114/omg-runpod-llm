#!/usr/bin/env bash
set -euo pipefail

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi is required" >&2
  exit 1
fi

b200_count="$(nvidia-smi --query-gpu=name --format=csv,noheader | grep -c 'B200' || true)"
if [[ "$b200_count" != "2" ]]; then
  echo "Expected exactly two NVIDIA B200 GPUs; found $b200_count" >&2
  exit 1
fi

if [[ -z "${VLLM_API_KEY:-}" ]]; then
  echo "Set VLLM_API_KEY to a fresh secret before starting the public HTTP API" >&2
  exit 1
fi

python3 - <<'PY'
import torch
assert torch.cuda.is_available(), "CUDA is not available"
assert torch.cuda.device_count() == 2, torch.cuda.device_count()
print({
    "torch": torch.__version__,
    "cuda": torch.version.cuda,
    "gpus": [torch.cuda.get_device_name(i) for i in range(2)],
})
PY
