#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def compare(payload: dict) -> dict:
    cold = payload["cold"]
    cached = payload["cached"]
    rows = {}
    for key, cold_value in cold.items():
        if key not in cached:
            continue
        cached_value = cached[key]
        rows[key] = {
            "cold_seconds": cold_value,
            "cached_seconds": cached_value,
            "change_percent": round((cached_value - cold_value) / cold_value * 100, 2),
        }
    return {"comparison": rows, "sample_scope": payload.get("sample_scope", {})}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = compare(json.loads(args.input.read_text()))
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
