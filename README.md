# OMG Runpod LLM

OhMyGPU의 Runpod 기반 오픈소스 LLM 배포 실습 자료입니다. 영상에서 사용한 명령어와 설정을 그대로 복사할 수 있도록, 각 영상의 자료를 번호가 붙은 폴더로 관리합니다.

> 이 저장소는 OhMyGPU가 운영하는 커뮤니티 튜토리얼입니다. Runpod의 공식 제품 저장소가 아닙니다.

## 튜토리얼

| 순서 | 주제 | 모델 | GPU | 검증일 | 영상 |
|---|---|---|---|---|---|
| 01 | [Pod에서 vLLM 서빙](tutorials/01-vllm-pod-qwen38-27b/) | Qwen3.8-27B NVFP4 | RTX 5090 × 1 | 2026-08-16 | 영상 준비 중 |
| 02 | [Serverless에서 vLLM 서빙](tutorials/02-vllm-serverless-qwen38-27b/) | Qwen3.8-27B NVFP4 | RTX 5090 × 1 | 2026-08-24 | 영상 준비 중 |

## 바로 시작하기

- [RTX 5090 Pod 템플릿으로 배포](https://console.runpod.io/deploy?template=mrs9dd60cx&ref=wvzldlmr)한 뒤 [Pod 튜토리얼](tutorials/01-vllm-pod-qwen38-27b/)을 순서대로 진행합니다.
- [Runpod Hub의 vLLM Worker 열기](https://console.runpod.io/hub/listing/runpod-workers/worker-vllm)에서 Endpoint를 만든 뒤 [Serverless 튜토리얼](tutorials/02-vllm-serverless-qwen38-27b/)을 진행합니다.

> Pod 템플릿 링크에는 OhMyGPU 추천인 코드가 포함되어 있습니다. 템플릿은 시작점을 빠르게 맞추기 위한 것이므로, 배포 버튼을 누르기 전에 현재 이미지, GPU, 디스크, 포트와 시간당 가격을 다시 확인하세요.

## 무엇이 다른가요?

| 기준 | Pod | Serverless |
|---|---|---|
| 환경 제어 | 이미지, 패키지, vLLM 옵션을 직접 관리 | Worker와 환경변수 범위에서 설정 |
| 실행 방식 | GPU 서버를 직접 시작하고 종료 | 요청에 따라 Worker를 0개에서 확장 가능 |
| 첫 요청 | 서버가 준비된 뒤에는 즉시 처리 가능 | Worker가 0개면 큐 대기와 콜드 스타트 발생 가능 |
| 적합한 경우 | 지속적인 트래픽, 세부 최적화 | 간헐적 트래픽, 자동 확장 |

Serverless가 항상 더 빠르거나 저렴한 것은 아닙니다. GPU 재고, 최소 Worker, idle timeout, 모델 크기와 실제 트래픽을 함께 확인하세요.

## OhMyGPU Runpod 저장소

| 저장소 | 다루는 내용 |
| --- | --- |
| **OMG Runpod LLM** | Pod·Serverless 기반 오픈소스 LLM 배포와 서빙 |
| [OMG Runpod Media](https://github.com/wlsdml1114/omg-runpod-media) | 이미지·영상 생성, ComfyUI 워크플로, 생성 시간·VRAM·출력 검증 |

두 저장소는 같은 방식으로 GPU, 실행 환경, 검증일과 측정 범위를 기록합니다. 이미지·영상 모델을 찾는다면 OMG Runpod Media에서 시작하세요.

## 시작하기 전에

- Runpod 계정과 사용 가능한 크레딧이 필요합니다.
- API 키, Hugging Face 토큰, SSH 키를 저장소에 커밋하지 마세요.
- 가격과 GPU 재고는 변동되므로 Runpod 콘솔의 현재 화면을 확인하세요.
- 예제는 유료 리소스를 자동으로 만들거나 삭제하지 않습니다.
- 테스트가 끝나면 Pod와 Serverless Worker 상태를 직접 확인하세요.

보안 기준은 [docs/security.md](docs/security.md), 자주 발생하는 문제는 [docs/troubleshooting.md](docs/troubleshooting.md)에서 확인할 수 있습니다.

## 라이선스

저장소의 예제 코드는 [Apache License 2.0](LICENSE)으로 배포합니다. 모델 가중치, Runpod, vLLM과 기타 의존성에는 각각의 라이선스와 이용 조건이 적용됩니다.
