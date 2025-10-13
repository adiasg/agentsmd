#!/usr/bin/env bats

setup() {
  # shellcheck source=/dev/null
  . "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_repo
}

teardown() {
  teardown_repo
}

@test "disable restores AGENTS.md to canonical tracked state" {
  printf 'Base instructions\n' > AGENTS.md
  git add AGENTS.md
  git commit -m "base snapshot" >/dev/null

  # Diverge working tree and create preferences
  printf 'preferences content\n' > .agentsmd

  run "$CLI" enable
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

preferences content
TXT

  run "$CLI" disable
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}


