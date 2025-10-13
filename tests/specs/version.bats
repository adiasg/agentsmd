#!/usr/bin/env bats

setup() {
  # shellcheck source=/dev/null
  . "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_repo
}

teardown() {
  teardown_repo
}

@test "--version prints package version" {
  local expected
  expected=$(awk -F'"' '/"version"[[:space:]]*:/ {print $4; exit}' "$PROJECT_ROOT/package.json")

  run "$CLI" --version

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}
