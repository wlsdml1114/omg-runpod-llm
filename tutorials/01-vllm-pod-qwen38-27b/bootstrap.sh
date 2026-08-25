#!/usr/bin/env bash
set -Eeuo pipefail

VENV_DIR="${VENV_DIR:-/opt/vllm-env}"
UV_CACHE_DIR="${UV_CACHE_DIR:-/workspace/.cache/uv}"
EVIDENCE_DIR="${EVIDENCE_DIR:-/workspace/vllm-run/evidence}"

mkdir -p "$UV_CACHE_DIR" "$EVIDENCE_DIR"
export UV_CACHE_DIR

{
  date -Is
  nvidia-smi
  nvidia-smi \
    --query-gpu=name,driver_version,memory.used,memory.total,compute_cap \
    --format=csv
  df -h / /workspace
  python3 - <<'PY'
import torch

print("base torch", torch.__version__)
print("base torch CUDA", torch.version.cuda)
print("CUDA available", torch.cuda.is_available())
if not torch.cuda.is_available():
    raise SystemExit("Stop: base image cannot initialize CUDA")
print("GPU", torch.cuda.get_device_name(0))
print("capability", torch.cuda.get_device_capability(0))
PY
} | tee "$EVIDENCE_DIR/preflight.txt"

if ! command -v uv >/dev/null 2>&1; then
  echo "Stop: this tutorial requires uv from the selected Runpod image." >&2
  exit 1
fi

python3 -m venv "$VENV_DIR"
uv pip install \
  --python "$VENV_DIR/bin/python" \
  'vllm==0.27.1' \
  'flashinfer-python>=0.6.13' \
  'nvidia-cutlass-dsl>=4.5.2'

export PATH="$VENV_DIR/bin:$PATH"

"$VENV_DIR/bin/python" - <<'PY' | tee "$EVIDENCE_DIR/resolved-versions.txt"
from importlib.metadata import version
import torch
import vllm

print("vLLM", vllm.__version__)
print("PyTorch", torch.__version__)
print("CUDA build", torch.version.cuda)
print("CUDA available", torch.cuda.is_available())
if not torch.cuda.is_available():
    raise SystemExit("Stop: installed environment cannot initialize CUDA")
print("GPU", torch.cuda.get_device_name(0))
print("Compute capability", torch.cuda.get_device_capability(0))
for package in ("transformers", "flashinfer-python", "nvidia-cutlass-dsl"):
    print(package, version(package))
PY

command -v ninja | tee "$EVIDENCE_DIR/ninja-path.txt"
ninja --version | tee "$EVIDENCE_DIR/ninja-version.txt"
uv pip freeze --python "$VENV_DIR/bin/python" > "$EVIDENCE_DIR/requirements.freeze.txt"

