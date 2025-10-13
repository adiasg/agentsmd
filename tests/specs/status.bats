#!/usr/bin/env bats

setup() {
  # shellcheck source=/dev/null
  . "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_repo
}

teardown() {
  teardown_repo
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
