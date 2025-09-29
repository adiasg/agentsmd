#!/usr/bin/env bats

setup() {
  PROJECT_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  CLI="$PROJECT_ROOT/bin/agentsmd"
  REPO_DIR=$(mktemp -d)
  export PROJECT_ROOT CLI REPO_DIR
  git -C "$REPO_DIR" init -q
  git -C "$REPO_DIR" config user.name "Test User"
  git -C "$REPO_DIR" config user.email "test@example.com"
  cd "$REPO_DIR"
}

teardown() {
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$REPO_DIR"
}

@test "status reports disabled by default" {
  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status: DISABLED"* ]]
}

@test "status reports enabled after install" {
  printf 'prefers tabs\n' > .agentsmd
  printf 'Base instructions\n' > AGENTS.md
  git add AGENTS.md
  git commit -m "seed AGENTS" >/dev/null
  "$CLI" enable >/dev/null

  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status: ENABLED"* ]]
  local prefs_path
  prefs_path="$PWD/.agentsmd"
  [[ "$output" == *"Developer preferences: ${prefs_path}"* ]]
}

@test "status reports disabled after disable" {
  "$CLI" enable >/dev/null
  "$CLI" disable >/dev/null

  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status: DISABLED"* ]]
}
