# 03. Qwen3.8 Flash Next NVFP4를 B200 두 장에서 서빙하기

- **상태:** 고정 스택에서 검증됨
- **검증일:** 2026-08-30
- **모델:** `Inferact/Qwen3.8-Flash-Next-NVFP4`
- **고정 revision:** `103a7608316173ca6edd49929544244de7ffda70`
- **GPU:** NVIDIA B200 × 2, Tensor Parallel 2
- **최대 컨텍스트:** 32,768 tokens

B200 두 장에 native NVFP4 경로를 올리고, 짧은 요청·4K·16K·32K 입력·버스트·취소·10분 지속 부하까지 확인한 Pod 레시피입니다. 성능 최대화 템플릿이 아니라, 다시 측정할 수 있는 출발점입니다.

## Runpod Pod 설정

`template-spec.json`은 비밀값을 제외한 고정 사양입니다. 유료 리소스를 자동으로 생성하지 않습니다. Runpod 콘솔에서 다음을 직접 확인한 뒤 배포하세요.

| 항목 | 설정 |
| --- | --- |
| Cloud | Secure Cloud |
| GPU | NVIDIA B200 × 2, NVLink |
| Image | `vllm/vllm-openai@sha256:0aea30240f3e3d9ffae8526643950e170eb5fa07fc427016a9dd90892afa2aa3` |
| Container Disk | 250 GB |
| HTTP Port | `8000` |
| Persistent Volume | 사용하지 않음 |

`VLLM_API_KEY`는 배포 시 일회성 비밀값으로 주입하고 저장소에 기록하지 마세요. GPU 재고와 가격은 변하므로 배포 직전 다시 확인합니다.

## Pod 내부 실행

Runpod 시작 명령 대신 SSH에서 재현하려면 다음을 실행합니다.

```bash
./scripts/preflight.sh
./scripts/serve.sh
```

`serve.sh`는 다음을 고정합니다.

- ModelOpt FP4, `FLASHINFER_TRTLLM` backend 기대
- Tensor Parallel 2, multiprocessing backend
- BF16 activation
- `max-model-len=32768`
- `max-num-batched-tokens=4096`
- `max-num-seqs=4`
- Prefix cache·FlashInfer autotune 비활성

모델 다운로드를 포함한 최초 기동은 길 수 있습니다. 검증 실험에서는 Pod 생성부터 API 준비까지 약 21분 23초가 걸렸습니다.

## 스모크와 부하 시나리오

로컬 PC에서 프록시 URL과 같은 API 키를 환경변수로 설정합니다.

```bash
export BASE_URL='https://YOUR_POD_ID-8000.proxy.runpod.net'
read -s VLLM_API_KEY
export VLLM_API_KEY

python scripts/scenario_load.py \
  --base-url "$BASE_URL" \
  --model qwen3.8-flash-next-nvfp4 \
  --scenario scenarios/smoke.json \
  --output benchmark-output/smoke.json
```

SSE의 HTTP 200만 보지 않고, 첫 토큰, 마지막 usage, `[DONE]`, 요청 출력 길이까지 확인합니다. API 키는 결과 JSON에 기록되지 않습니다.

## 기존 실측에서 잡은 시작값

| 요청 | 권장 시작점 | 근거 |
| --- | ---: | --- |
| 512 input → 128 output | 2 RPS | p95 TTFT 212ms; 3 RPS는 1.50초 |
| 4K input → 512 output | 동시성 4 | 479 output tok/s, p95 TTFT 1.33초 |
| 16K input → 1K output | 동시성 4 | 513 output tok/s, p95 TTFT 1.87초 |
| 30K 안팎 | 동시성 1 | 동시성 4는 성공했지만 tail latency 증가 |

512→128 10분 지속 부하는 1,200/1,200 성공, 실제 1.996 RPS, 255.44 output tok/s였습니다. 이 결과는 위 이미지 digest·vLLM build·모델 revision·스케줄러 설정에 묶입니다. 응답 품질, 수 시간 장기 안정성, 멀티테넌트 혼합 트래픽은 확인하지 않았습니다.

## 정적 검사

```bash
python -m unittest discover -s tests -v
```

테스트가 끝나면 Pod를 중지하고 `EXITED`를 확인하세요. Container Disk를 남겨두면 GPU 중지 후에도 스토리지 비용이 발생할 수 있습니다.
