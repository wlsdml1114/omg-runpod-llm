# OMG Runpod LLM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a public-ready Korean tutorial repository for serving Qwen3.8-27B NVFP4 with vLLM on Runpod Pod and Serverless.

**Architecture:** Numbered tutorial folders are independently usable by video viewers. Pod scripts own preflight, installation, serving, smoke validation, and optional benchmarking; Serverless files own public environment configuration and two request examples. A dependency-light repository validator enforces file, syntax, safety, and documentation contracts without creating paid resources.

**Tech Stack:** Bash 5, Python 3, jq, curl, uv, vLLM 0.27.1, Bats (optional wrapper), Markdown

**Spec:** `docs/superpowers/specs/2026-08-26-omg-runpod-llm-design.md`

## Global Constraints

- Repository name is `omg-runpod-llm` and default branch is `main`.
- Public copy is Korean-first and identifies the project as an OhMyGPU tutorial, not an official Runpod product repository.
- Pod model is `gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090` with vLLM `0.27.1`, ModelOpt quantization, FP8 KV cache, and 262,144 maximum model length.
- Serverless model is `PassingByPixels/Qwen3.8-27B-NVFP4` pinned to revision `1e5f29f3212294efdef42a873672c9bc399cae3c` and the documented validated worker reference is `runpod-workers/worker-vllm:v2.25.2`.
- No script creates, stops, or deletes paid Runpod resources.
- No live credential, private key, internal Pod ID, internal Endpoint ID, or Network Volume ID may enter tracked files.
- Serverless live verification is limited to cold and warm smoke requests; there is no local Serverless mock or load test.

---

### Task 1: Repository Contract and Validation Harness

**Files:**
- Create: `.gitignore`
- Create: `Makefile`
- Create: `tests/repository.bats`
- Create: `scripts/validate-repository.sh`

**Interfaces:**
- Consumes: repository paths and text files only
- Produces: `make test`, which exits zero only when the complete public repository contract passes

- [ ] **Step 1: Write the failing Bats contract**

Create `tests/repository.bats` with tests that invoke `scripts/validate-repository.sh`, assert all required files exist, and assert the validator rejects a temporary file containing `-----BEGIN OPENSSH PRIVATE KEY-----`.

```bash
#!/usr/bin/env bats

@test "repository contract passes" {
  run bash scripts/validate-repository.sh
  [ "$status" -eq 0 ]
}

@test "validator rejects private keys" {
  fixture="$(mktemp)"
  printf '%s\n' '-----BEGIN OPENSSH PRIVATE KEY-----' > "$fixture"
  run bash scripts/validate-repository.sh "$fixture"
  rm -f "$fixture"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the contract and verify RED**

Run: `bats tests/repository.bats`

Expected: FAIL because `scripts/validate-repository.sh` and required public files do not exist.

- [ ] **Step 3: Implement the dependency-light validator**

Create `scripts/validate-repository.sh` with `set -Eeuo pipefail`. It must:

- resolve the repository root from the script location;
- accept optional extra scan paths for the negative secret test;
- verify every path listed in the design exists;
- run `bash -n` on every tracked `.sh` file;
- parse every tracked `.json` file with `jq -e .`;
- compile every tracked `.py` file into a temporary directory using `PYTHONPYCACHEPREFIX`;
- grep tracked files and optional scan paths for private-key headers, non-placeholder bearer tokens, and these prohibited internal IDs: `g3gzyweeal5v85`, `ijbh4vw5fjz83v`, `p9lmvfryass86k`, `evdck315hn`;
- verify required model IDs, revision, cleanup language, validation dates, and source URLs;
- print one concise success line.

Create a `Makefile` whose default `test` target runs the validator and runs Bats only when `bats` is installed:

```make
.PHONY: test

test:
	bash scripts/validate-repository.sh
	@if command -v bats >/dev/null 2>&1; then bats tests/repository.bats; else echo "bats not installed; shell validator passed"; fi
```

Create `.gitignore` covering `.env`, `.env.*` except `env.example`, Python bytecode, macOS metadata, editor directories, results, evidence, and downloaded model/cache directories.

- [ ] **Step 4: Run focused validation and verify expected failure**

Run: `bash scripts/validate-repository.sh`

Expected: FAIL with a required-file message for the first tutorial artifact that has not been created yet. This proves the harness now runs and the remaining failure is the missing implementation.

- [ ] **Step 5: Commit the contract**

```bash
git add .gitignore Makefile tests/repository.bats scripts/validate-repository.sh
git commit -m "test: define public tutorial repository contract"
```

### Task 2: Pod Tutorial Scripts

**Files:**
- Create: `tutorials/01-vllm-pod-qwen38-27b/bootstrap.sh`
- Create: `tutorials/01-vllm-pod-qwen38-27b/serve.sh`
- Create: `tutorials/01-vllm-pod-qwen38-27b/smoke-test.sh`
- Create: `tutorials/01-vllm-pod-qwen38-27b/benchmark.sh`

**Interfaces:**
- Consumes: Runpod RTX 5090 Pod with `/workspace`, `uv`, CUDA-capable base PyTorch, `curl`, and `jq`
- Produces: `/opt/vllm-env`, a foreground vLLM server on port 8000, and timestamped evidence under `/workspace/vllm-run`

- [ ] **Step 1: Add focused failing assertions to the validator**

Add assertions requiring:

- `bootstrap.sh` to pin `vllm==0.27.1`, FlashInfer `>=0.6.13`, and CUTLASS DSL `>=4.5.2`;
- `serve.sh` to contain the Pod model, `--quantization modelopt`, `--kv-cache-dtype fp8`, `--max-model-len 262144`, `--reasoning-parser qwen3`, and `--tool-call-parser qwen3_xml`;
- `smoke-test.sh` to poll `/v1/models`, send two requests, set `enable_thinking` to false, and reject empty content;
- `benchmark.sh` to contain the 512/128 concurrency-one, 512/128 concurrency-four, and 61,775/128 long-input cases.

- [ ] **Step 2: Run the validator and verify RED**

Run: `bash scripts/validate-repository.sh`

Expected: FAIL because the Pod scripts are absent.

- [ ] **Step 3: Implement `bootstrap.sh` and `serve.sh`**

Adapt the reviewed scripts from `/Users/engui/.codex/skills/deploying-runpod-llms/scripts/`. Preserve strict shell mode, CUDA preflight, evidence capture, venv PATH export, argument arrays, and foreground server ownership. Set tutorial-specific defaults explicitly while allowing only safe path and bind overrides through environment variables.

- [ ] **Step 4: Implement smoke and benchmark scripts**

`smoke-test.sh` must create its JSON body with `jq -n`, archive the exact request, record curl timing separately for first and warm calls, and require nonempty `choices[0].message.content` with empty reasoning fields. Optional external proxy validation uses `EXTERNAL_BASE_URL` and never archives API keys.

`benchmark.sh` preserves the three standard cases and writes results to a timestamped directory. It refuses the long case unless the configured model length is at least 62,000 tokens.

- [ ] **Step 5: Run syntax and contract tests**

Run: `bash -n tutorials/01-vllm-pod-qwen38-27b/*.sh && bash scripts/validate-repository.sh`

Expected: validator advances past Pod script assertions and fails only on documentation or Serverless files not created yet.

- [ ] **Step 6: Commit Pod scripts**

```bash
git add tutorials/01-vllm-pod-qwen38-27b scripts/validate-repository.sh
git commit -m "feat: add qwen38 nvfp4 pod scripts"
```

### Task 3: Serverless Tutorial Examples

**Files:**
- Create: `tutorials/02-vllm-serverless-qwen38-27b/env.example`
- Create: `tutorials/02-vllm-serverless-qwen38-27b/smoke-input.json`
- Create: `tutorials/02-vllm-serverless-qwen38-27b/request-native.sh`
- Create: `tutorials/02-vllm-serverless-qwen38-27b/request-openai.py`
- Modify: `scripts/validate-repository.sh`

**Interfaces:**
- Consumes: `ENDPOINT_ID` and `RUNPOD_API_KEY` from the process environment
- Produces: one synchronous native response or one OpenAI-compatible assistant message; no credentials are persisted

- [ ] **Step 1: Add failing Serverless assertions**

Require the exact Serverless model and revision in `env.example`, valid JSON in `smoke-input.json`, required-variable guards in the shell client, environment reads in the Python client, `/runsync` in the native client, and `/openai/v1` in the Python client.

- [ ] **Step 2: Run the validator and verify RED**

Run: `bash scripts/validate-repository.sh`

Expected: FAIL because Serverless example files do not exist.

- [ ] **Step 3: Implement public Serverless configuration**

Create `env.example` with non-secret values for the pinned model, revision, one RTX 5090, CUDA 13 constraint, min/max workers, idle timeout, cache root, loader, and CUDA graph capture sizes. Use `RUNPOD_API_KEY=` and `ENDPOINT_ID=` as empty placeholders only.

Create `smoke-input.json` with a chat message asking for exactly `OK`, deterministic sampling, and an explicit thinking-off control supported by the selected worker contract.

- [ ] **Step 4: Implement the two clients**

`request-native.sh` uses strict shell mode, requires both variables, posts `smoke-input.json` to `/runsync`, saves response to a temporary file, requires status `COMPLETED`, and requires nonempty output before printing a redacted summary.

`request-openai.py` uses only the Python standard library so repository validation does not require installing the OpenAI SDK. It reads environment variables, sends JSON to `/openai/v1/chat/completions`, enforces a timeout, verifies nonempty assistant content, and never prints headers or secrets.

- [ ] **Step 5: Run offline validation**

Run: `bash -n tutorials/02-vllm-serverless-qwen38-27b/request-native.sh && PYTHONPYCACHEPREFIX="$(mktemp -d)" python3 -m py_compile tutorials/02-vllm-serverless-qwen38-27b/request-openai.py && jq -e . tutorials/02-vllm-serverless-qwen38-27b/smoke-input.json && bash scripts/validate-repository.sh`

Expected: syntax checks pass; repository validation fails only on README/documentation requirements.

- [ ] **Step 6: Commit Serverless examples**

```bash
git add tutorials/02-vllm-serverless-qwen38-27b scripts/validate-repository.sh
git commit -m "feat: add qwen38 nvfp4 serverless examples"
```

### Task 4: Korean Tutorial Documentation

**Files:**
- Create: `README.md`
- Create: `tutorials/01-vllm-pod-qwen38-27b/README.md`
- Create: `tutorials/02-vllm-serverless-qwen38-27b/README.md`
- Create: `docs/security.md`
- Create: `docs/troubleshooting.md`
- Create: `LICENSE`
- Modify: `scripts/validate-repository.sh`

**Interfaces:**
- Consumes: scripts and exact validated facts from the design spec
- Produces: beginner-facing navigation, commands, boundaries, cleanup guidance, and sources

- [ ] **Step 1: Add failing documentation assertions**

Require every tutorial README to include `검증일`, `YouTube`, `종료`, `스토리지 비용`, the model ID, and authoritative source links. Require the root README to link both tutorial folders and display statuses. Require `docs/security.md` to cover API keys, HF tokens, SSH keys, public proxy exposure, and secret cleanup. Require troubleshooting to cover CUDA Error 804, missing `ninja`, first-request JIT, empty content from thinking, and Serverless capacity/queue delay.

- [ ] **Step 2: Run the validator and verify RED**

Run: `bash scripts/validate-repository.sh`

Expected: FAIL on the first missing documentation requirement.

- [ ] **Step 3: Write root and tutorial READMEs**

The root README contains the series index and concise Pod-versus-Serverless table. Both video links use `영상 준비 중` until real individual URLs exist.

The Pod README follows the exact order: prerequisites, Runpod settings, clone/copy instructions, bootstrap, serve, readiness, smoke test, optional benchmark, evidence interpretation, cleanup, sources.

The Serverless README follows: validated worker/model boundary, Hub configuration, environment variables, endpoint creation, UI smoke input, native request, OpenAI-compatible request, cold/warm interpretation, worker cleanup, sources. It explicitly states that the two tutorials use different validated NVFP4 checkpoints of the same Qwen3.8-27B base model.

- [ ] **Step 4: Write policy and troubleshooting docs**

Use concise Korean practitioner language. Keep confirmed facts, configuration choices, and unconfirmed conditions distinct. Do not advertise guaranteed cost, availability, latency, or context capacity.

Use the Apache License 2.0 text in `LICENSE`, matching the base model's permissive public distribution context without claiming rights over upstream model weights.

- [ ] **Step 5: Run the complete repository contract**

Run: `make test`

Expected: PASS with zero validator errors and zero Bats failures when Bats is installed.

- [ ] **Step 6: Commit documentation**

```bash
git add README.md LICENSE docs tutorials scripts/validate-repository.sh
git commit -m "docs: add korean pod and serverless tutorials"
```

### Task 5: Final Public-Repository Audit

**Files:**
- Modify only files found defective by the checks below

**Interfaces:**
- Consumes: complete repository
- Produces: verified local `main` branch ready for an optional GitHub remote

- [ ] **Step 1: Run all automated checks fresh**

Run:

```bash
make test
git diff --check
git status --short
```

Expected: tests pass, no whitespace errors, and no uncommitted implementation files.

- [ ] **Step 2: Audit tracked files and secrets**

Run:

```bash
git ls-files
git grep -nE 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|Authorization: Bearer [A-Za-z0-9_-]{12,}|g3gzyweeal5v85|ijbh4vw5fjz83v|p9lmvfryass86k|evdck315hn' -- . ':!docs/superpowers/plans/*' ':!docs/superpowers/specs/*'
```

Expected: only intended public files are tracked and the secret/resource-ID grep returns no matches.

- [ ] **Step 3: Review every public file**

Read the root README, both tutorial READMEs, every executable script, `env.example`, and both policy docs. Confirm commands match the pinned settings, no internal evidence paths are exposed, and all placeholders are explicitly user-supplied values rather than unfinished prose.

- [ ] **Step 4: Commit audit corrections if needed**

If Step 1–3 required corrections, run the full verification again and commit only those corrections:

```bash
git add <corrected-public-files>
git commit -m "fix: address public repository audit"
```

If no correction was required, do not create an empty commit.

- [ ] **Step 5: Prepare but do not create the remote**

Run `git log --oneline --decorate -5` and report the local path, commits, and test evidence. Ask the user which GitHub owner should hold `omg-runpod-llm` and whether it should be public. Only after that explicit answer may a remote repository be created and pushed.
