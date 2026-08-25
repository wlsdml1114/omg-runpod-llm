#!/usr/bin/env bash
set -Eeuo pipefail

: "${ENDPOINT_ID:?Set ENDPOINT_ID in your shell}"
: "${RUNPOD_API_KEY:?Set RUNPOD_API_KEY in your shell}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

curl -fsS \
  -X POST "https://api.runpod.ai/v2/${ENDPOINT_ID}/runsync" \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -H 'Content-Type: application/json' \
  --data-binary @"$script_dir/smoke-input.json" \
  -o "$response_file"

jq -e '.status == "COMPLETED"' "$response_file" >/dev/null
jq -e '.output != null and .output != "" and .output != []' \
  "$response_file" >/dev/null

jq '{status, delayTime, executionTime, output}' "$response_file"

