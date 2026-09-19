from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


CLIENT = Path(__file__).resolve().parents[1] / "scripts" / "scenario_load.py"


class FakeOpenAIHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self) -> None:  # noqa: N802
        if self.headers.get("User-Agent", "").startswith("Python-urllib/"):
            self.send_response(403)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        size = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(size))
        prompt = payload["messages"][0]["content"]
        requested = int(payload["max_tokens"])
        events = [
            {"choices": [{"delta": {"content": token}}]}
            for token in ("A", "B", "C")[:requested]
        ]
        if prompt != "incomplete":
            events.append(
                {
                    "choices": [],
                    "usage": {
                        "prompt_tokens": 5,
                        "completion_tokens": requested,
                        "total_tokens": 5 + requested,
                    },
                }
            )

        body = "".join(f"data: {json.dumps(event)}\n\n" for event in events)
        if prompt != "incomplete":
            body += "data: [DONE]\n\n"
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: object) -> None:
        return


class ScenarioLoadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), FakeOpenAIHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def run_scenario(
        self,
        prompt: str | None = None,
        spec_override: dict | None = None,
        api_key_via_env: bool = False,
    ) -> tuple[subprocess.CompletedProcess[str], dict]:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scenario = root / "scenario.json"
            output = root / "result.json"
            scenario.write_text(
                json.dumps(
                    {
                        "requests": [
                            {
                                "label": "probe",
                                "start_after_seconds": 0,
                                "prompt": prompt,
                                "max_tokens": 3,
                                "ignore_eos": True,
                                **(spec_override or {}),
                            }
                        ]
                    }
                )
            )
            command = [
                    sys.executable,
                    str(CLIENT),
                    "--base-url",
                    self.base_url,
                    "--model",
                    "test-model",
                    "--scenario",
                    str(scenario),
                    "--output",
                    str(output),
                ]
            env = os.environ.copy()
            if api_key_via_env:
                env["VLLM_API_KEY"] = "test-key"
            else:
                command.extend(["--api-key", "test-key"])
            completed = subprocess.run(
                command,
                text=True,
                capture_output=True,
                timeout=10,
                env=env,
            )
            data = json.loads(output.read_text()) if output.exists() else {}
            return completed, data

    def test_complete_stream_with_usage_is_a_technical_success(self) -> None:
        """Catches accepting HTTP 200 without a completed SSE stream and final usage."""
        completed, data = self.run_scenario("complete")

        self.assertEqual(completed.returncode, 0, completed.stderr)
        request = data["requests"][0]
        self.assertTrue(request["technical_success"])
        self.assertEqual(request["completion_tokens"], 3)
        self.assertTrue(request["done_received"])
        self.assertIsNotNone(request["ttft_seconds"])
        self.assertIn("tpot_seconds", request)
        self.assertIn("inter_chunk_latency_seconds", request)
        self.assertEqual(request["inter_chunk_latency_seconds"]["sample_count"], 2)
        self.assertIsNotNone(request["inter_chunk_latency_seconds"]["p95"])
        self.assertIn("timestamp_start_utc", request)
        self.assertIn("p90", data["summary"]["ttft_seconds"])
        self.assertIn("p90", data["summary"]["tpot_seconds"])
        self.assertEqual(data["summary"]["success_rate"], 1.0)

    def test_stream_without_usage_or_done_is_classified_incomplete(self) -> None:
        """Catches treating a closed partial stream as a successful generation."""
        completed, data = self.run_scenario("incomplete")

        self.assertEqual(completed.returncode, 0, completed.stderr)
        request = data["requests"][0]
        self.assertFalse(request["technical_success"])
        self.assertEqual(request["failure_type"], "incomplete_stream")
        self.assertEqual(data["summary"]["success_rate"], 0.0)

    def test_target_bytes_builds_prompt_without_archiving_prompt_text(self) -> None:
        """Catches measuring a requested byte profile with the wrong generated prompt size."""
        completed, data = self.run_scenario(
            spec_override={"prompt_seed": "abcd", "target_bytes": 12, "prompt": None}
        )

        self.assertEqual(completed.returncode, 0, completed.stderr)
        request = data["requests"][0]
        self.assertIn("configured_prompt_bytes", request)
        self.assertEqual(request["configured_prompt_bytes"], 12)
        self.assertNotIn("prompt", request)

    def test_api_key_can_be_read_from_environment(self) -> None:
        """Keeps the bearer token out of the process argument list during live runs."""
        completed, data = self.run_scenario("complete", api_key_via_env=True)

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertTrue(data["requests"][0]["technical_success"])


if __name__ == "__main__":
    unittest.main()
