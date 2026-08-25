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
