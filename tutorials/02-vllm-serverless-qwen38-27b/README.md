# 02. Runpod Serverless에서 Qwen3.8-27B NVFP4 서빙

- **상태:** 검증됨
- **검증일:** 2026-08-24
- **YouTube:** 영상 준비 중
- **모델:** `PassingByPixels/Qwen3.8-27B-NVFP4`
- **고정 revision:** `1e5f29f3212294efdef42a873672c9bc399cae3c`
- **검증 Worker:** `runpod-workers/worker-vllm:v2.25.2`
- **GPU pool:** RTX 5090 / `ADA_32_PRO`, CUDA 13.0

Runpod Hub의 vLLM Worker로 Qwen3.8-27B NVFP4 Serverless Endpoint를 만들고 Native API와 OpenAI 호환 API로 호출합니다.

Pod 편과 같은 Qwen3.8-27B NVFP4 기반이지만 체크포인트 저장소는 다릅니다. 각 환경에서 실제 검증한 체크포인트를 사용했으며, 두 저장소의 가중치가 바이트 단위로 동일하다고 전제하지 않습니다.

## 1. vLLM Worker 배포

1. Runpod Hub에서 `runpod-workers/worker-vllm`을 엽니다.
2. 촬영 또는 배포 당일 release가 Qwen3.8, ModelOpt NVFP4, CUDA 13과 RTX 5090을 지원하는지 확인합니다.
3. GPU pool에서 RTX 5090 한 장을 선택합니다.
4. `env.example`의 공개 Worker 환경변수를 Runpod 설정에 옮깁니다.
5. Minimum Workers 0, Maximum Workers 1로 시작합니다.
6. 데모용 idle timeout은 5초를 사용할 수 있지만 실제 서비스에서는 콜드 스타트 허용 범위에 맞게 조정합니다.

`ENDPOINT_ID`와 `RUNPOD_API_KEY`는 Worker 환경변수로 올리지 않습니다. 두 값은 로컬 요청 클라이언트에서만 사용합니다.

Network Volume을 쓰지 않는다면 `/runpod-volume` 캐시 설정을 그대로 복사하지 마세요. 볼륨을 연결하면 해당 데이터 센터의 GPU 재고에 배치가 제한될 수 있습니다.

## 2. UI에서 첫 요청

Requests 탭에 `smoke-input.json` 내용을 붙여넣고 실행합니다. 응답에서 다음을 확인합니다.

- 상태가 `COMPLETED`인가
- output이 비어 있지 않은가
- `delayTime`과 `executionTime`은 각각 얼마인가

Minimum Workers가 0이면 첫 요청의 `delayTime`에 큐 대기와 Worker 콜드 스타트가 포함될 수 있습니다.

## 3. Native API 호출

API 키를 파일에 저장하지 말고 현재 셸에만 설정합니다.

```bash
export ENDPOINT_ID='YOUR_ENDPOINT_ID'
read -s RUNPOD_API_KEY
export RUNPOD_API_KEY
./request-native.sh
```

스크립트는 `/runsync`를 호출하고 `COMPLETED`와 비어 있지 않은 output을 확인한 뒤 상태·지연시간·결과만 출력합니다.

## 4. OpenAI 호환 API 호출

같은 환경변수를 유지한 상태에서 실행합니다.

```bash
./request-openai.py
```

요청 주소는 다음 형식입니다.

```text
https://api.runpod.ai/v2/ENDPOINT_ID/openai/v1/chat/completions
```

예제는 Python 표준 라이브러리만 사용하며 assistant content가 비어 있으면 실패합니다.

## 5. cold와 warm 요청 확인

이 튜토리얼은 부하 테스트를 하지 않습니다.

1. Worker가 0인 상태에서 첫 요청을 한 번 보냅니다.
2. Worker가 살아 있는 동안 같은 요청을 한 번 더 보냅니다.
3. 두 요청의 `delayTime`, `executionTime`, 결과를 기록합니다.

검증 실험에서는 첫 작업이 완료됐지만 GPU 큐 대기와 Worker 초기화 시간이 길었습니다. 두 번째 실험은 연결된 Network Volume의 데이터 센터에서 RTX 5090을 할당하지 못해 취소했습니다. Serverless가 항상 즉시 시작되거나 더 저렴하다고 해석하지 마세요.

## 6. 종료

1. 테스트 후 Endpoint의 활성 Worker 수를 확인합니다.
2. Minimum Workers가 0인지 확인합니다.
3. 더 이상 사용하지 않을 Endpoint와 Network Volume은 Runpod 콘솔에서 소유권과 보존 필요성을 확인한 뒤 정리합니다.
4. Worker가 0이어도 Network Volume에는 별도 스토리지 비용이 발생할 수 있습니다.
5. 로컬 셸에서 `unset RUNPOD_API_KEY ENDPOINT_ID`를 실행합니다.

## 참고 자료

- [Runpod Serverless vLLM 개요](https://docs.runpod.io/serverless/vllm/overview)
- [vLLM Worker 배포](https://docs.runpod.io/serverless/vllm/get-started)
- [vLLM 환경변수](https://docs.runpod.io/serverless/vllm/environment-variables)
- [OpenAI 호환 API](https://docs.runpod.io/serverless/vllm/openai-compatibility)
- [Qwen3.8-27B 공식 모델 카드](https://huggingface.co/Qwen/Qwen3.8-27B)

