.PHONY: test

test:
	bash scripts/validate-repository.sh
	@if command -v bats >/dev/null 2>&1; then bats tests/repository.bats; else echo "bats not installed; shell validator passed"; fi

