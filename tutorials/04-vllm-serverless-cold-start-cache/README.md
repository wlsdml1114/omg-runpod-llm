# 04. Network Volume으로 vLLM 콜드스타트 캐시하기

- **상태:** 실측 완료, 독립 cached boot 표본 1회
- **검증일:** 2026-08-24
- **모델:** `Qwen/Qwen3.8-27B-FP8`
- **고정 revision:** `017b9c7af6b5689d5dd426a76e0bc077eb5ca20a`
- **Worker:** `runpod-workers/worker-vllm:v2.25.2`
- **GPU:** NVIDIA H100 NVL 94GB × 1
- **스토리지:** 80GB Standard Network Volume, `/runpod-volume`

Hugging Face 가중치만이 아니라 vLLM AOT, Triton, TorchInductor, CUDA, FlashInfer 캐시까지 Network Volume에 놓아 새 Worker가 받아 쓰게 합니다. 이 방식은 모델 다운로드와 대규모 재컴파일을 줄이지만, 새 호스트가 28.75GiB 체크포인트를 읽는 시간까지 없애지는 않습니다.

## 1. Endpoint 환경변수

Network Volume을 `/runpod-volume`에 마운트한 뒤 `env.example`의 공개 설정을 Worker 환경변수로 옮깁니다. `RUNPOD_API_KEY`와 Endpoint ID는 Worker에 넣지 말고 로컬 호출 클라이언트에서만 사용하세요.

캐시 경로와 모델 revision을 바꾸면 cold·cached 비교가 무효해집니다. 첫 캐시 생성 시에는 볼륨 용량을 모니터링하세요.

## 2. cold 와 cached boot를 나누어 측정

1. 빈 캐시에서 Minimum Workers 0 → 1을 트리거하는 요청을 보냅니다.
2. Worker가 healthy가 된 뒤 정확히 `OK`를 반환하는지 확인합니다.
3. Worker를 0으로 내리고 모델·컴파일 캐시가 Network Volume에 남았는지 확인합니다.
4. 새 Worker를 다시 띄워 동일한 요청을 보냅니다.
5. wrapper 시작→healthy, 모델 로딩, `torch.compile`, profiling/warmup을 각각 기록합니다.

`smoke-input.json`은 Runpod Serverless Requests 탭에 붙여넣을 수 있는 최소 요청입니다.

## 3. 측정값 비교

```bash
python scripts/compare_startup.py \
  --input evidence/observed-comparison.json
```

기존 독립 Worker 실측은 다음과 같았습니다.

| 구간 | 빈 캐시 | 캐시 재사용 | 변화 |
| --- | ---: | ---: | ---: |
| wrapper 시작 → healthy | 792.362초 | 272.145초 | -65.65% |
| 모델 로딩 | 112.619초 | 93.673초 | -16.82% |
| `torch.compile` | 213.28초 | 8.51초 | -96.01% |
| 초기 profiling·warmup | 29.73초 | 16.08초 | -45.91% |

캐시 Worker에서도 28.75GiB 체크포인트를 콜드 페이지 캐시로 읽는 데 83.82초가 걸렸습니다. 직후 재시도의 140.070초는 호스트 페이지 캐시 효과가 섞였을 가능성이 있어 대표값에서 제외했습니다.

## 해석 범위

- “모델 다운로드와 대규모 재컴파일을 피했다”는 관찰됨.
- “콜드스타트가 항상 272초다”는 아직 관찰되지 않음. 독립 cached boot는 1회.
- “Network Volume이 모델 로딩을 10초대로 만든다”는 근거 없음.
- 비용 절감률은 중복 Worker 기록과 실제 청구 내역을 대조하지 않아 계산하지 않음.

게시용 결론을 만들려면 동일 설정의 독립 0→1 부팅을 최소 3회, 가능하면 5회 반복하고 중앙값·최솟값·최댓값을 함께 기록하세요. 테스트가 끝나면 Minimum Workers 0과 실제 활성 Worker 0을 모두 확인하고, Network Volume 스토리지 비용은 별도로 계산합니다.

## 정적 검사

```bash
python -m unittest discover -s tests -v
```
