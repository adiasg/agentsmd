#!/usr/bin/env bats

setup() {
  PROJECT_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  CLI="$PROJECT_ROOT/bin/agentsmd"
  REPO_DIR=$(mktemp -d)
  export PROJECT_ROOT CLI REPO_DIR
  git -C "$REPO_DIR" init -q
  cd "$REPO_DIR"
  touch AGENTS.md
  git add AGENTS.md
}

teardown() {
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$REPO_DIR"
}

get_alias() {
  git config --local --get "$1"
}

@test "agentsmd enable installs hooks and aliases" {
  run "$CLI" enable
  [ "$status" -eq 0 ]

  [ -f .git/hooks/pre-commit ]
  grep -q 'AGENTS_MD_MANAGEMENT' .git/hooks/pre-commit

  alias_value=$(get_alias alias.rebuild-agents)
  [ "$alias_value" = "!$CLI make" ]

  grep -q '^AGENTS.md merge=agentsmd$' .git/info/attributes
}

@test "agentsmd disable removes automation" {
  "$CLI" enable >/dev/null

  run "$CLI" disable
  [ "$status" -eq 0 ]

  [ ! -f .git/hooks/pre-commit ]
  run git config --local --get alias.rebuild-agents
  [ "$status" -ne 0 ]
  if [ -f .git/info/attributes ]; then
    run grep -q '^AGENTS.md merge=agentsmd$' .git/info/attributes
    [ "$status" -ne 0 ]
  fi
}
