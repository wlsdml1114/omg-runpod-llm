# 문제 해결

## `torch.cuda.is_available()`이 False이거나 Error 804가 발생합니다

컨테이너 패키지를 다시 설치하기 전에 Pod의 호스트 CUDA와 드라이버, 이미지가 요구하는 CUDA를 확인합니다. 이미지 이름에 CUDA 13이 적혀 있어도 호스트 배치가 호환된다는 뜻은 아닙니다.

## `nvcc`가 없습니다

Runtime 이미지는 CUDA toolkit 컴파일러를 포함하지 않을 수 있습니다. 먼저 `torch.version.cuda`, `torch.cuda.is_available()`과 간단한 GPU tensor 연산으로 런타임을 확인하세요.

## `FileNotFoundError: ninja`가 발생합니다

`/opt/vllm-env/bin/ninja`가 있는데도 오류가 나면 vLLM 실행 전에 PATH를 확인합니다.

```bash
export PATH=/opt/vllm-env/bin:$PATH
command -v ninja
ninja --version
```

## 첫 요청이 멈춘 것처럼 보입니다

Blackwell용 커널 JIT일 수 있습니다. 즉시 재시작하지 말고 서버 로그와 프로세스를 확인합니다.

```bash
pgrep -af 'ninja|nvcc|c\+\+|triton'
nvidia-smi
```

첫 요청 시간과 warm 요청 시간은 별도로 기록합니다.

## HTTP 200인데 assistant content가 비어 있습니다

Qwen3.8은 thinking이 기본입니다. 짧은 `max_tokens`를 reasoning이 모두 사용하면 최종 content가 비어 있을 수 있습니다. 요청에 다음 값을 명시하고 다시 확인합니다.

```json
"chat_template_kwargs": {"enable_thinking": false}
```

## 262K를 설정했는데 긴 요청이 실패합니다

`--max-model-len`은 설정값입니다. 서버 시작 로그의 실제 GPU KV cache 토큰 수와 현재 동시성, 입력·출력·템플릿 오버헤드를 함께 확인합니다.

## Serverless 요청이 오래 대기합니다

`delayTime`과 `executionTime`을 구분합니다. GPU 재고, 선택 데이터 센터, Network Volume 연결, Minimum Workers 0에 따른 콜드 스타트가 큐 대기에 영향을 줄 수 있습니다. Worker가 할당되지 않았다면 모델 추론 성능 문제가 아닙니다.

## Network Volume을 연결했는데 콜드 스타트가 줄지 않습니다

볼륨 연결만으로 캐시 경로가 바뀌지 않습니다. `VLLM_CACHE_ROOT`가 `/runpod-volume` 아래를 가리키는지 확인하고, warm Worker 로그에서 실제 캐시 로드와 컴파일 시간 변화를 확인합니다. 모델 파일이 모두 준비되기 전에 `HF_HUB_OFFLINE=1`을 켜지 마세요.

