# 01. RTX 5090 Pod에서 Qwen3.8-27B NVFP4 서빙

- **상태:** 검증됨
- **검증일:** 2026-08-16
- **YouTube:** 영상 준비 중
- **모델:** `gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090`
- **GPU:** NVIDIA GeForce RTX 5090 × 1
- **vLLM:** 0.27.1

RTX 5090 한 장에서 Qwen3.8-27B NVFP4를 vLLM OpenAI 호환 API로 실행합니다. 이 폴더의 스크립트는 GPU 사전 점검, 설치, 서버 실행, 첫 요청과 warm 요청 검증을 분리합니다.

## 1. Runpod 설정

배포 직전 공유 템플릿의 현재 이미지와 허용 CUDA 버전을 다시 확인하세요.

| 항목 | 설정 |
|---|---|
| Template | `mrs9dd60cx` |
| Cloud | Secure Cloud |
| GPU | RTX 5090 × 1 |
| 검증 이미지 | `runpod/pytorch:1.1.0-cu1300-torch291-ubuntu2404` |
| Container Disk | 50 GB |
| Volume Disk | 80 GB, `/workspace` |
| Ports | `22/tcp`, `8000/http` |

컨테이너 이미지의 CUDA 이름과 실제 호스트 드라이버는 별개의 조건입니다. `bootstrap.sh`는 패키지 설치 전에 PyTorch CUDA 초기화를 확인하고 실패하면 중단합니다.

## 2. 파일 준비

Pod의 SSH 터미널에서 저장소를 `/workspace`에 복제합니다.

```bash
cd /workspace
git clone https://github.com/wlsdml1114/omg-runpod-llm.git
cd omg-runpod-llm/tutorials/01-vllm-pod-qwen38-27b
```

GitHub 공개 전 로컬 파일로 실습한다면 이 폴더의 네 스크립트를 Pod에 업로드해도 됩니다.

## 3. vLLM 설치

```bash
./bootstrap.sh
```

다음 경로를 사용합니다.

- vLLM 환경: `/opt/vllm-env`
- uv 캐시: `/workspace/.cache/uv`
- Hugging Face 캐시: `/workspace/.cache/huggingface`
- 검증 기록: `/workspace/vllm-run/evidence`

## 4. 서버 실행

```bash
./serve.sh
```

기본 설정은 ModelOpt NVFP4, FP8 KV cache, 262,144 최대 모델 길이, GPU memory utilization 0.97입니다. 262,144는 설정값입니다. 실제 로그의 KV cache 토큰 수가 입력·출력·템플릿 오버헤드를 담는지 별도로 확인하세요.

첫 실행은 모델 다운로드, FlashInfer JIT, 메모리 프로파일링과 CUDA graph 생성 때문에 오래 걸릴 수 있습니다. 고정된 시간만 기다린 뒤 재시작하지 말고 두 번째 터미널에서 스모크 테스트를 실행하세요.

## 5. 첫 요청과 warm 요청

```bash
./smoke-test.sh
```

스크립트는 `/v1/models`가 준비될 때까지 최대 30분 동안 폴링한 뒤 같은 요청을 두 번 보냅니다. Qwen3.8의 thinking을 명시적으로 끄고 HTTP 200과 비어 있지 않은 assistant content를 모두 확인합니다.

외부 Proxy도 확인하려면 인증 구성을 먼저 완료한 뒤 다음처럼 실행합니다.

```bash
BASE_URL="https://YOUR_POD_ID-8000.proxy.runpod.net" \
API_KEY="YOUR_VLLM_API_KEY" \
./smoke-test.sh
```

인증 없이 `8000/http`를 공개 상태로 장시간 운영하지 마세요.

## 6. 선택 사항: 벤치마크

```bash
./benchmark.sh
```

512 input / 128 output의 동시성 1과 4, 그리고 61,775 random input / 128 output의 긴 입력을 순서대로 측정합니다. 긴 입력은 설정한 길이가 아니라 결과에 기록된 실제 토큰 수를 사용해 해석하세요.

## 7. 종료

1. 서버 터미널에서 `Ctrl+C`로 vLLM을 종료합니다.
2. Runpod 콘솔에서 Pod를 Stop합니다.
3. 상태가 `EXITED`인지 확인합니다.
4. Volume Disk를 남기면 GPU가 꺼져도 스토리지 비용이 계속 발생할 수 있습니다.

## 확인된 범위

기존 동일 구성 검증에서는 체크포인트 19.18 GiB, 가중치 GPU 메모리 18.77 GiB, FP8 KV cache 8.51 GiB, GPU KV cache 271,342토큰이 기록됐습니다. 촬영이나 새 배포에서는 모델 revision, 패키지, 호스트와 GPU 상태가 달라질 수 있으므로 새 로그를 우선합니다.

## 참고 자료

- [Qwen3.8-27B 공식 모델 카드](https://huggingface.co/Qwen/Qwen3.8-27B)
- [RTX 5090 NVFP4 체크포인트](https://huggingface.co/gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090)
- [vLLM OpenAI 호환 서버](https://docs.vllm.ai/en/latest/serving/openai_compatible_server/)
- [Runpod 포트 노출](https://docs.runpod.io/pods/configuration/expose-ports)
- [Runpod 스토리지 유형](https://docs.runpod.io/pods/storage/types)
