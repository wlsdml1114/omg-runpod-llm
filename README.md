# OMG Runpod LLM

OhMyGPU의 Runpod 기반 오픈소스 LLM 배포 실습 자료입니다. 영상에서 사용한 명령어와 설정을 그대로 복사할 수 있도록, 각 영상의 자료를 번호가 붙은 폴더로 관리합니다.

> 이 저장소는 OhMyGPU가 운영하는 커뮤니티 튜토리얼입니다. Runpod의 공식 제품 저장소가 아닙니다.

## 튜토리얼

| 순서 | 주제 | 모델 | GPU | 검증일 | 영상 |
|---|---|---|---|---|---|
| 01 | [Pod에서 vLLM 서빙](tutorials/01-vllm-pod-qwen38-27b/) | Qwen3.8-27B NVFP4 | RTX 5090 × 1 | 2026-08-16 | 영상 준비 중 |
| 02 | [Serverless에서 vLLM 서빙](tutorials/02-vllm-serverless-qwen38-27b/) | Qwen3.8-27B NVFP4 | RTX 5090 × 1 | 2026-08-24 | 영상 준비 중 |

## 무엇이 다른가요?

| 기준 | Pod | Serverless |
|---|---|---|
| 환경 제어 | 이미지, 패키지, vLLM 옵션을 직접 관리 | Worker와 환경변수 범위에서 설정 |
| 실행 방식 | GPU 서버를 직접 시작하고 종료 | 요청에 따라 Worker를 0개에서 확장 가능 |
| 첫 요청 | 서버가 준비된 뒤에는 즉시 처리 가능 | Worker가 0개면 큐 대기와 콜드 스타트 발생 가능 |
| 적합한 경우 | 지속적인 트래픽, 세부 최적화 | 간헐적 트래픽, 자동 확장 |

Serverless가 항상 더 빠르거나 저렴한 것은 아닙니다. GPU 재고, 최소 Worker, idle timeout, 모델 크기와 실제 트래픽을 함께 확인하세요.

## 시작하기 전에

- Runpod 계정과 사용 가능한 크레딧이 필요합니다.
- API 키, Hugging Face 토큰, SSH 키를 저장소에 커밋하지 마세요.
- 가격과 GPU 재고는 변동되므로 Runpod 콘솔의 현재 화면을 확인하세요.
- 예제는 유료 리소스를 자동으로 만들거나 삭제하지 않습니다.
- 테스트가 끝나면 Pod와 Serverless Worker 상태를 직접 확인하세요.

보안 기준은 [docs/security.md](docs/security.md), 자주 발생하는 문제는 [docs/troubleshooting.md](docs/troubleshooting.md)에서 확인할 수 있습니다.

## 라이선스

저장소의 예제 코드는 [Apache License 2.0](LICENSE)으로 배포합니다. 모델 가중치, Runpod, vLLM과 기타 의존성에는 각각의 라이선스와 이용 조건이 적용됩니다.
