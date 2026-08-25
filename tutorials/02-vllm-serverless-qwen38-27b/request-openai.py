#!/usr/bin/env python3
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Set {name} in your shell")
    return value


endpoint_id = required_env("ENDPOINT_ID")
api_key = required_env("RUNPOD_API_KEY")
model = os.environ.get(
    "MODEL_NAME", "PassingByPixels/Qwen3.8-27B-NVFP4"
)

payload = {
    "model": model,
    "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
    "max_tokens": 16,
    "temperature": 0,
    "chat_template_kwargs": {"enable_thinking": False},
}

request = Request(
    f"https://api.runpod.ai/v2/{endpoint_id}/openai/v1/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
    method="POST",
)

try:
    with urlopen(request, timeout=900) as response:
        body = json.load(response)
except HTTPError as error:
    print(f"HTTP error: {error.code}", file=sys.stderr)
    raise SystemExit(1) from error
except URLError as error:
    print(f"Request failed: {error.reason}", file=sys.stderr)
    raise SystemExit(1) from error

content = body.get("choices", [{}])[0].get("message", {}).get("content")
if not isinstance(content, str) or not content.strip():
    raise SystemExit("Server returned empty assistant content")

print(content)
