# 보안 기준

## 비밀정보

다음 값은 Git, 영상 화면, 로그와 이슈에 올리지 않습니다.

- Runpod API key
- Hugging Face token
- SSH private key
- 실제 Authorization header
- 서명된 다운로드 URL
- 공개할 필요가 없는 Pod, Endpoint, Network Volume ID

`.env`는 `.gitignore` 대상입니다. 예제에는 빈 값 또는 `YOUR_*` 표기만 둡니다. API 키는 `read -s` 또는 비밀 관리 도구로 현재 프로세스에 전달하고 사용 후 `unset`합니다.

## Pod HTTP Proxy

`8000/http`를 열고 vLLM에 인증을 설정하지 않으면 외부에서 호출될 수 있습니다. 짧은 폐기형 데모가 아니라면 vLLM API 키 또는 인증 리버스 프록시를 사용하세요. 응답에 개인정보나 민감한 입력을 포함하지 마세요.

## 종료와 비용

- Pod 테스트 후 상태가 `EXITED`인지 확인합니다.
- Serverless 테스트 후 Minimum Workers와 활성 Worker 수를 확인합니다.
- Volume Disk와 Network Volume은 GPU가 정지해도 스토리지 비용이 계속될 수 있습니다.
- 예제는 유료 리소스를 자동 생성하거나 삭제하지 않습니다.

## 공개 전 확인

커밋 전에 `git diff`와 `git status`를 확인하고 GitHub의 secret scanning을 함께 사용하세요. 문법 검사가 Runpod 계정 설정이나 외부 보안을 보증하지는 않습니다.
