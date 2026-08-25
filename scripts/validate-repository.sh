#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required_files=(
  README.md
  LICENSE
  docs/security.md
  docs/troubleshooting.md
  tutorials/01-vllm-pod-qwen38-27b/README.md
  tutorials/01-vllm-pod-qwen38-27b/bootstrap.sh
  tutorials/01-vllm-pod-qwen38-27b/serve.sh
  tutorials/01-vllm-pod-qwen38-27b/smoke-test.sh
  tutorials/01-vllm-pod-qwen38-27b/benchmark.sh
  tutorials/02-vllm-serverless-qwen38-27b/README.md
  tutorials/02-vllm-serverless-qwen38-27b/env.example
  tutorials/02-vllm-serverless-qwen38-27b/request-native.sh
  tutorials/02-vllm-serverless-qwen38-27b/request-openai.py
  tutorials/02-vllm-serverless-qwen38-27b/smoke-input.json
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
done

require_text() {
  local path="$1" pattern="$2" label="$3"
  if ! grep -qE -- "$pattern" "$path"; then
    echo "Missing $label in $path" >&2
    exit 1
  fi
}

pod_dir='tutorials/01-vllm-pod-qwen38-27b'
if [[ -f "$pod_dir/bootstrap.sh" ]]; then
  require_text "$pod_dir/bootstrap.sh" 'vllm==0\.27\.1' 'pinned vLLM version'
  require_text "$pod_dir/bootstrap.sh" 'flashinfer-python>=0\.6\.13' 'FlashInfer dependency'
  require_text "$pod_dir/bootstrap.sh" 'nvidia-cutlass-dsl>=4\.5\.2' 'CUTLASS DSL dependency'
fi
if [[ -f "$pod_dir/serve.sh" ]]; then
  require_text "$pod_dir/serve.sh" 'gittensor-model-hub/Qwen3\.8-27B-NVFP4-RTX5090' 'Pod model ID'
  require_text "$pod_dir/serve.sh" '--quantization modelopt' 'ModelOpt quantization'
  require_text "$pod_dir/serve.sh" '--kv-cache-dtype fp8' 'FP8 KV cache'
  require_text "$pod_dir/serve.sh" '--max-model-len 262144' '262K model length'
  require_text "$pod_dir/serve.sh" '--reasoning-parser qwen3' 'Qwen reasoning parser'
  require_text "$pod_dir/serve.sh" '--tool-call-parser qwen3_xml' 'Qwen tool parser'
fi
if [[ -f "$pod_dir/smoke-test.sh" ]]; then
  require_text "$pod_dir/smoke-test.sh" '/v1/models' 'readiness endpoint'
  require_text "$pod_dir/smoke-test.sh" 'enable_thinking: false' 'thinking-off request'
  require_text "$pod_dir/smoke-test.sh" 'request first' 'first request'
  require_text "$pod_dir/smoke-test.sh" 'request warm' 'warm request'
fi
if [[ -f "$pod_dir/benchmark.sh" ]]; then
  require_text "$pod_dir/benchmark.sh" 'bench-c1 512 128 10 1' 'concurrency-one benchmark'
  require_text "$pod_dir/benchmark.sh" 'bench-c4 512 128 20 4' 'concurrency-four benchmark'
  require_text "$pod_dir/benchmark.sh" 'bench-62k 61775 128 1 1' 'long-input benchmark'
fi

while IFS= read -r path; do
  bash -n "$path"
done < <(find . -type f -name '*.sh' -not -path './.git/*' | sort)

while IFS= read -r path; do
  jq -e . "$path" >/dev/null
done < <(find . -type f -name '*.json' -not -path './.git/*' | sort)

pycache_root="$(mktemp -d)"
trap 'rm -rf "$pycache_root"' EXIT
while IFS= read -r path; do
  PYTHONPYCACHEPREFIX="$pycache_root" python3 -m py_compile "$path"
done < <(find . -type f -name '*.py' -not -path './.git/*' | sort)

scan_paths=(.)
if (($#)); then
  scan_paths+=("$@")
fi

secret_pattern='BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9_./+=-]{12,}|g3gzyweeal5v85|ijbh4vw5fjz83v|p9lmvfryass86k|evdck315hn'
if grep -RInE \
  --exclude-dir=.git \
  --exclude='*.md' \
  -- "$secret_pattern" "${scan_paths[@]}"; then
  echo "Potential secret or internal resource ID detected" >&2
  exit 1
fi

echo "Repository validation passed"
