#!/usr/bin/env bats

setup() {
  # shellcheck source=/dev/null
  . "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_repo
  touch AGENTS.md
  git add AGENTS.md
}

teardown() {
  teardown_repo
}

get_alias() {
  git config --local --get "$1"
}

src_sha() {
  # Hash of working tree files excluding .git
  find . -path './.git' -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum | shasum | awk '{print $1}'
}

git_state_sha() {
  # Hash of the .git directory
  find .git -type f 2> /dev/null | LC_ALL=C sort | xargs -r shasum | shasum | awk '{print $1}'
}

git_config_sem_sha() {
  # Semantic view of config: key=value lines, sorted
  git config --local --list | LC_ALL=C sort | shasum | awk '{print $1}'
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

@test "agentsmd enable is idempotent" {
  printf 'Base instructions\n' > AGENTS.md
  git add AGENTS.md

  run "$CLI" enable
  [ "$status" -eq 0 ]
  src_after_first=$(src_sha)
  git_after_first=$(git_state_sha)

  run "$CLI" enable
  [ "$status" -eq 0 ]
  src_after_second=$(src_sha)
  git_after_second=$(git_state_sha)

  [ "$src_after_first" = "$src_after_second" ]
  [ "$git_after_first" = "$git_after_second" ]
}

@test "agentsmd disable is idempotent" {
  printf 'Base instructions\n' > AGENTS.md
  git add AGENTS.md
  "$CLI" enable >/dev/null

  run "$CLI" disable
  [ "$status" -eq 0 ]
  src_after_first_disable=$(src_sha)
  git_after_first_disable=$(git_state_sha)

  run "$CLI" disable
  [ "$status" -eq 0 ]
  src_after_second_disable=$(src_sha)
  git_after_second_disable=$(git_state_sha)

  [ "$src_after_first_disable" = "$src_after_second_disable" ]
  [ "$git_after_first_disable" = "$git_after_second_disable" ]
}

@test "enable then disable restores previous hooks and configs" {
  # Seed user-owned pre-commit hook and configs
  mkdir -p .git/hooks
  cat > .git/hooks/pre-commit <<'SH'
#!/usr/bin/env bash
echo original-user-hook
SH
  chmod +x .git/hooks/pre-commit

  git config --local alias.rebuild-agents '!echo from-user'
  git config --local merge.agentsmd.name 'User Provided Name'
  git config --local merge.agentsmd.driver 'echo custom-driver %O %A %B'

  # Track AGENTS.md so enable can mark assume-unchanged reliably
  printf 'Base instructions\n' > AGENTS.md
  git add AGENTS.md
  git commit -m "seed AGENTS" >/dev/null

  src_before=$(src_sha)
  cfg_sem_before=$(git_config_sem_sha)

  run "$CLI" enable
  [ "$status" -eq 0 ]
  cfg_sem_after_enable=$(git_config_sem_sha)

  run "$CLI" disable
  [ "$status" -eq 0 ]

  src_after=$(src_sha)
  cfg_sem_after_disable=$(git_config_sem_sha)

  [ "$src_before" = "$src_after" ]
  [ "$cfg_sem_before" = "$cfg_sem_after_disable" ]
}

@test "disable without prior enable preserves user state" {
  src_before=$(src_sha)
  git_before=$(git_state_sha)

  run "$CLI" disable
  [ "$status" -eq 0 ]

  src_after=$(src_sha)
  git_after=$(git_state_sha)

  [ "$src_before" = "$src_after" ]
  [ "$git_before" = "$git_after" ]
}
