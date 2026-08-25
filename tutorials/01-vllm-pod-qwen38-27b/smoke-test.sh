#!/usr/bin/env bash
set -Eeuo pipefail

MODEL_ID="${MODEL_ID:-gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
READY_TIMEOUT_SECONDS="${READY_TIMEOUT_SECONDS:-1800}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RESULT_DIR="${RESULT_DIR:-/workspace/vllm-run/results/$RUN_ID}"

mkdir -p "$RESULT_DIR"
command -v curl >/dev/null
command -v jq >/dev/null

headers=()
if [[ -n "${API_KEY:-}" ]]; then
  headers=(-H "Authorization: Bearer $API_KEY")
fi

deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
until curl -fsS "${headers[@]}" "$BASE_URL/v1/models" -o "$RESULT_DIR/models.json"; do
  if ((SECONDS >= deadline)); then
    echo "Timed out waiting for $BASE_URL/v1/models" >&2
    exit 1
  fi
  nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used,memory.total \
    --format=csv,noheader || true
  sleep 10
done

jq -e --arg model "$MODEL_ID" '.data | any(.id == $model)' \
  "$RESULT_DIR/models.json" >/dev/null

jq -n --arg model "$MODEL_ID" '{
  model: $model,
  messages: [{role: "user", content: "Reply with exactly: OK"}],
  temperature: 0,
  max_tokens: 16,
  chat_template_kwargs: {enable_thinking: false}
}' > "$RESULT_DIR/request.json"

request() {
  local label="$1"
  local response="$RESULT_DIR/$label-response.json"
  local timing="$RESULT_DIR/$label-timing.txt"

  curl -sS \
    -o "$response" \
    -w 'HTTP=%{http_code} start=%{time_starttransfer}s total=%{time_total}s\n' \
    "${headers[@]}" \
    -H 'Content-Type: application/json' \
    --data-binary @"$RESULT_DIR/request.json" \
    "$BASE_URL/v1/chat/completions" > "$timing"

  grep -q '^HTTP=200 ' "$timing"
  jq -e '
    (.choices[0].message.content // "") as $content
    | ($content | type == "string")
      and (($content | length) > 0)
      and (($content | contains("<think>")) | not)
      and (((.choices[0].message.reasoning // "") | length) == 0)
      and (((.choices[0].message.reasoning_content // "") | length) == 0)
  ' "$response" >/dev/null
}

request first
request warm
echo "Smoke test passed; results: $RESULT_DIR"

