#!/usr/bin/env bats

setup() {
  PROJECT_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  CLI="$PROJECT_ROOT/bin/agentsmd"
  export PROJECT_ROOT CLI
}

@test "--version prints package version" {
  local expected
  expected=$(awk -F'"' '/"version"[[:space:]]*:/ {print $4; exit}' "$PROJECT_ROOT/package.json")

  run "$CLI" --version

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}
