#!/usr/bin/env bats

@test "repository contract passes" {
  run bash scripts/validate-repository.sh
  [ "$status" -eq 0 ]
}

@test "validator rejects private keys" {
  fixture="$(mktemp)"
  printf '%s\n' '-----BEGIN OPENSSH PRIVATE KEY-----' > "$fixture"
  run bash scripts/validate-repository.sh "$fixture"
  rm -f "$fixture"
  [ "$status" -ne 0 ]
}
