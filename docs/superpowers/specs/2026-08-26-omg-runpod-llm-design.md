# OMG Runpod LLM Repository Design

## Goal

Create a public, Korean-first companion repository for the OhMyGPU Runpod LLM tutorial series. A viewer should be able to open the folder linked from a video, confirm the exact tested environment, copy a small set of commands, validate a nonempty model response, and shut down billable resources safely.

## Scope

The first release contains two tutorials:

1. Serve Qwen3.8-27B NVFP4 with vLLM on one RTX 5090 Pod.
2. Serve Qwen3.8-27B NVFP4 with the Runpod Serverless vLLM worker on one RTX 5090.

The repository is named `omg-runpod-llm` so later tutorials can add SGLang, other quantization formats, benchmarks, caching, and SDK integrations without creating a repository per video.

The first release does not automate paid Runpod resource creation or deletion. It provides reviewed deployment settings, commands, request clients, validation, and cleanup instructions. Users create and stop resources in the Runpod console.

## Repository Layout

```text
omg-runpod-llm/
├── README.md
├── LICENSE
├── .gitignore
├── Makefile
├── docs/
│   ├── security.md
│   ├── troubleshooting.md
│   └── superpowers/
│       ├── specs/
│       └── plans/
├── scripts/
│   └── validate-repository.sh
├── tests/
│   └── repository.bats
└── tutorials/
    ├── 01-vllm-pod-qwen38-27b/
    │   ├── README.md
    │   ├── bootstrap.sh
    │   ├── serve.sh
    │   ├── smoke-test.sh
    │   └── benchmark.sh
    └── 02-vllm-serverless-qwen38-27b/
        ├── README.md
        ├── env.example
        ├── request-native.sh
        ├── request-openai.py
        └── smoke-input.json
```

Each tutorial is self-contained for a beginner. Shared documentation contains policy and troubleshooting material, not required commands that force viewers to jump between folders.

## Tutorial 1: Pod

The Pod tutorial uses the already validated RTX 5090/CUDA 13 baseline:

- Runpod template ID: `mrs9dd60cx`
- GPU: NVIDIA GeForce RTX 5090, one GPU, 32 GB class VRAM
- Image baseline: `runpod/pytorch:1.1.0-cu1300-torch291-ubuntu2404`
- Container Disk: 50 GB
- Volume Disk: 80 GB mounted at `/workspace`
- Ports: `22/tcp` and `8000/http`
- Model: `gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090`
- vLLM: `0.27.1`
- FlashInfer: `>=0.6.13`
- NVIDIA CUTLASS DSL: `>=4.5.2`
- Quantization: `modelopt`
- KV cache dtype: `fp8`
- Maximum model length: `262144`
- GPU memory utilization: `0.97`
- Reasoning parser: `qwen3`
- Tool parser: `qwen3_xml`

`bootstrap.sh` performs the CUDA preflight before installation, installs the pinned inference environment in `/opt/vllm-env`, preserves caches under `/workspace`, and records resolved versions without secrets.

`serve.sh` launches one foreground vLLM process. Model-dependent flags are explicit in an argument array. The script does not hide startup in the background or claim readiness after a fixed sleep.

`smoke-test.sh` polls `/v1/models`, sends first and warm Chat Completions requests with thinking explicitly disabled, and fails unless HTTP is successful and assistant content is nonempty.

`benchmark.sh` is optional. It records the standard concurrency-one, concurrency-four, and long-input evidence separately from the beginner quick start.

## Tutorial 2: Serverless

The Serverless tutorial keeps the same base model family and NVFP4/RTX 5090 story, but uses the configuration already proven with the official worker:

- Worker: `runpod-workers/worker-vllm`
- Validated release reference: `v2.25.2`
- GPU pool: RTX 5090 / `ADA_32_PRO`, one GPU, CUDA 13.0
- Model: `PassingByPixels/Qwen3.8-27B-NVFP4`
- Model revision: `1e5f29f3212294efdef42a873672c9bc399cae3c`
- Minimum workers: 0
- Maximum workers: 1
- Example idle timeout: 5 seconds
- Native request API: `/run` and `/runsync`
- OpenAI-compatible base URL: `https://api.runpod.ai/v2/ENDPOINT_ID/openai/v1`

The two tutorials intentionally use different NVFP4 checkpoint repositories because those are the exact checkpoints validated in their respective environments. Both serve Qwen3.8-27B NVFP4. The README states this boundary plainly instead of implying byte-identical weights.

`env.example` contains public configuration only. It never contains a Runpod API key or Hugging Face token. `request-native.sh` requires `RUNPOD_API_KEY` and `ENDPOINT_ID` at runtime and uses `/runsync`. `request-openai.py` reads the same variables from the process environment and prints only assistant content.

The Serverless README records the observed cold-start boundary: the validated first job completed, but queue delay and worker initialization were substantial, and a later attempt could not allocate an RTX 5090 in the volume's data center. The tutorial does not claim Serverless is always fast, available, or cheaper.

## Root README Experience

The root README opens with a Korean description, then a compact tutorial index containing:

- sequence number and title;
- linked YouTube video or `영상 준비 중`;
- direct tutorial folder link;
- model, GPU, framework, and validation date;
- status: validated, recording, or draft.

It then explains prerequisites, repository safety rules, and the difference between Pod and Serverless in one comparison table. Detailed commands remain in tutorial READMEs.

## Safety and Secrets

- No script creates, stops, or deletes a paid resource automatically in the first release.
- No API key, Hugging Face token, SSH key, Pod ID, Endpoint ID, signed URL, or identifying SSH key comment is committed.
- Examples use `YOUR_*` placeholders or required environment variables.
- Shell tracing is never enabled around credentials.
- Pod documentation requires checking the final `EXITED` state.
- Serverless documentation requires checking endpoint worker state after testing.
- Volume and Network Volume storage charges are disclosed separately from GPU compute charges.
- The repository identifies the material as an OhMyGPU tutorial, not an official Runpod product repository.
- Any referral link is labelled as a referral link.

## Validation Strategy

Repository validation is deterministic and runs without a GPU or Runpod credentials.

The test suite first defines the expected public contract, then implementation is added until it passes. These are offline repository checks, not an attempt to emulate Runpod Serverless. It checks:

1. Required files and tutorial directories exist.
2. Shell scripts pass `bash -n`.
3. Python examples compile with `python3 -m py_compile` without executing network requests.
4. Pod scripts contain the pinned model, vLLM version, NVFP4 quantization, FP8 KV cache, thinking-off smoke request, and readiness polling.
5. Serverless examples require credentials from environment variables, contain the pinned model revision, and use valid JSON/Python syntax.
6. No tracked file contains private-key blocks, bearer-token values, or known live resource IDs from internal evidence.
7. READMEs contain validation dates, cleanup instructions, storage-cost warnings, and source links.

`make test` runs the complete repository contract. If Bats is unavailable, `scripts/validate-repository.sh` remains the dependency-light validation entry point and is also invoked by the Bats suite.

Live Serverless verification stays intentionally small: submit one cold request, submit one warm request when capacity permits, confirm `COMPLETED` plus nonempty assistant output, and record `delayTime` and `executionTime`. The tutorial does not add load testing, autoscaling tests, or a local mock of Runpod's control plane.

## Versioning and Publishing

Videos map to numbered folders, not separate repositories. Published tutorial folders remain stable; corrections receive a dated changelog note in that folder's README.

The repository starts on `main`. After the Pod and Serverless videos and their scripts are verified, create one annotated tag named `v1.0-video-series`. Future major runtime refreshes may use new tags, but viewers follow direct folder links in video descriptions.

GitHub repository creation and the first push occur only after local tests pass and the user confirms the target GitHub owner and public visibility. No existing remote repository is overwritten.

## Success Criteria

- A beginner can complete either tutorial from its folder without reading internal experiment files.
- Every executable example fails safely when required inputs are missing.
- The Pod flow validates CUDA before paid time is spent downloading packages and models.
- Both flows validate a real, nonempty assistant response rather than only an HTTP status.
- Public documentation separates tested facts, configurable choices, and unverified expectations.
- Local validation passes with no secrets or internal resource identifiers in tracked files.
