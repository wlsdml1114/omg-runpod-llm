#!/usr/bin/env python3
"""Run timestamped OpenAI-compatible streaming requests from a scenario file."""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import math
import os
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def percentile(values: list[float], quantile: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * quantile
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1 - fraction) + ordered[upper] * fraction


def run_request(
    *,
    base_url: str,
    model: str,
    api_key: str,
    spec: dict[str, Any],
    run_started: float,
) -> dict[str, Any]:
    target = run_started + float(spec.get("start_after_seconds", 0))
    time.sleep(max(0.0, target - time.perf_counter()))
    if spec.get("target_bytes") is not None:
        seed = str(spec.get("prompt_seed", "The quick brown fox jumps over the lazy dog. "))
        seed_bytes = seed.encode("ascii")
        target_bytes = int(spec["target_bytes"])
        prompt = (seed_bytes * (target_bytes // len(seed_bytes) + 1))[:target_bytes].decode(
            "ascii"
        )
    else:
        prompt = str(spec["prompt"])
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
        "max_tokens": int(spec["max_tokens"]),
        "ignore_eos": bool(spec.get("ignore_eos", False)),
        "stream": True,
        "stream_options": {"include_usage": True},
        "chat_template_kwargs": {"enable_thinking": False},
    }
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "User-Agent": "qwen-serving-loadtest/1.0",
        },
        method="POST",
    )
    started = time.perf_counter()
    timestamp_start_utc = dt.datetime.now(dt.timezone.utc).isoformat()
    first_content_at: float | None = None
    content_event_times: list[float] = []
    usage: dict[str, Any] | None = None
    done_received = False
    http_status: int | None = None
    failure_type: str | None = None
    error: str | None = None
    try:
        with urllib.request.urlopen(
            request, timeout=float(spec.get("timeout_seconds", 900))
        ) as response:
            http_status = response.status
            for raw_line in response:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if line == "data: [DONE]":
                    done_received = True
                    continue
                if not line.startswith("data: "):
                    continue
                event = json.loads(line[6:])
                if event.get("usage"):
                    usage = event["usage"]
                for choice in event.get("choices", []):
                    if choice.get("delta", {}).get("content"):
                        content_at = time.perf_counter()
                        content_event_times.append(content_at)
                        if first_content_at is None:
                            first_content_at = content_at
    except urllib.error.HTTPError as exc:
        http_status = exc.code
        failure_type = "server_error"
        error = str(exc)
    except TimeoutError as exc:
        failure_type = "timeout"
        error = str(exc)
    except Exception as exc:  # Preserve unexpected transport failures in evidence.
        failure_type = "client_or_transport_error"
        error = f"{type(exc).__name__}: {exc}"

    finished = time.perf_counter()
    completion_tokens = int((usage or {}).get("completion_tokens", 0))
    requested = int(spec["max_tokens"])
    exact_length_ok = completion_tokens == requested if spec.get("ignore_eos") else completion_tokens > 0
    technical_success = bool(
        http_status == 200
        and first_content_at is not None
        and usage is not None
        and done_received
        and exact_length_ok
        and failure_type is None
    )
    if not technical_success and failure_type is None:
        failure_type = "incomplete_stream"
    inter_chunk_latencies = [
        later - earlier
        for earlier, later in zip(content_event_times, content_event_times[1:])
    ]
    tpot_seconds = None
    if completion_tokens > 1 and len(content_event_times) > 1:
        tpot_seconds = (content_event_times[-1] - content_event_times[0]) / (
            completion_tokens - 1
        )
    return {
        "label": spec["label"],
        "timestamp_start_utc": timestamp_start_utc,
        "scheduled_after_seconds": float(spec.get("start_after_seconds", 0)),
        "started_after_seconds": started - run_started,
        "configured_prompt_bytes": len(prompt.encode("utf-8")),
        "http_status": http_status,
        "technical_success": technical_success,
        "failure_type": failure_type,
        "error": error,
        "done_received": done_received,
        "final_usage_received": usage is not None,
        "prompt_tokens": (usage or {}).get("prompt_tokens"),
        "completion_tokens": completion_tokens,
        "requested_completion_tokens": requested,
        "ttft_seconds": None if first_content_at is None else first_content_at - started,
        "tpot_seconds": tpot_seconds,
        "inter_chunk_latency_seconds": {
            "sample_count": len(inter_chunk_latencies),
            "p50": percentile(inter_chunk_latencies, 0.50),
            "p90": percentile(inter_chunk_latencies, 0.90),
            "p95": percentile(inter_chunk_latencies, 0.95),
            "p99": percentile(inter_chunk_latencies, 0.99),
        },
        "e2e_seconds": finished - started,
    }


def summarize(requests: list[dict[str, Any]], wall_seconds: float) -> dict[str, Any]:
    successes = [item for item in requests if item["technical_success"]]
    ttft = [float(item["ttft_seconds"]) for item in successes]
    e2e = [float(item["e2e_seconds"]) for item in successes]
    tpot = [float(item["tpot_seconds"]) for item in successes if item["tpot_seconds"] is not None]
    completion_tokens = sum(int(item["completion_tokens"]) for item in successes)
    return {
        "request_count": len(requests),
        "technical_success_count": len(successes),
        "success_rate": len(successes) / len(requests) if requests else 0.0,
        "wall_seconds": wall_seconds,
        "aggregate_output_tokens_per_second": (
            completion_tokens / wall_seconds if wall_seconds > 0 else None
        ),
        "ttft_seconds": {
            "p50": percentile(ttft, 0.50),
            "p90": percentile(ttft, 0.90),
            "p95": percentile(ttft, 0.95),
            "p99": percentile(ttft, 0.99),
        },
        "e2e_seconds": {
            "p50": percentile(e2e, 0.50),
            "p90": percentile(e2e, 0.90),
            "p95": percentile(e2e, 0.95),
            "p99": percentile(e2e, 0.99),
        },
        "tpot_seconds": {
            "p50": percentile(tpot, 0.50),
            "p90": percentile(tpot, 0.90),
            "p95": percentile(tpot, 0.95),
            "p99": percentile(tpot, 0.99),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--api-key", default=os.environ.get("VLLM_API_KEY"))
    parser.add_argument("--scenario", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not args.api_key:
        parser.error("provide --api-key or set VLLM_API_KEY")

    scenario = json.loads(args.scenario.read_text())
    specs = scenario["requests"]
    started = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, len(specs))) as pool:
        futures = [
            pool.submit(
                run_request,
                base_url=args.base_url,
                model=args.model,
                api_key=args.api_key,
                spec=spec,
                run_started=started,
            )
            for spec in specs
        ]
        requests = [future.result() for future in futures]
    wall = time.perf_counter() - started
    result = {
        "model": args.model,
        "base_url": args.base_url,
        "credentials_recorded": False,
        "requests": sorted(requests, key=lambda item: item["started_after_seconds"]),
        "summary": summarize(requests, wall),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
