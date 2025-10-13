#!/usr/bin/env bats

setup() {
  # shellcheck source=/dev/null
  . "$BATS_TEST_DIRNAME/../helpers/common.bash"
  setup_repo
}

teardown() {
  teardown_repo
}

@test "creates AGENTS.md with .agentsmd contents" {
  printf 'prefers tabs\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]
  [ -f AGENTS.md ]

  cat > expected <<'TXT'
prefers tabs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "preserves existing content and appends raw block" {
  printf 'Base instructions\n' > AGENTS.md
  printf 'prefers tabs\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

prefers tabs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "idempotent regeneration" {
  printf 'Base instructions\n' > AGENTS.md
  printf 'prefers spaces\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]
  first_sum=$(shasum AGENTS.md | awk '{print $1}')

  run "$CLI" make
  [ "$status" -eq 0 ]
  second_sum=$(shasum AGENTS.md | awk '{print $1}')

  [ "$first_sum" = "$second_sum" ]
}

@test "regeneration uses HEAD as base" {
  printf 'Base instructions\n' > AGENTS.md
  git add AGENTS.md
  git commit -m "base snapshot" >/dev/null

  printf 'prefers tabs\n' > .agentsmd

  printf 'local change\n' > AGENTS.md

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

prefers tabs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "missing .agentsmd only rewrites base content" {
  printf 'Base instructions\n' > AGENTS.md

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "empty .agentsmd does not append block" {
  printf 'Base instructions\n' > AGENTS.md
  : > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "fails outside a git repository" {
  cd "$BATS_TEST_TMPDIR"
  run "$CLI" make
  [ "$status" -ne 0 ]
}

@test "renders global templates in .agentsmd" {
  mkdir -p "$HOME/.agentsmd/templates"
  printf '{{ nextjs }}\n' > .agentsmd
  printf 'Global guidance\n' > "$HOME/.agentsmd/templates/nextjs.md"

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Global guidance
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "renders global templates in AGENT.md" {
  mkdir -p "$HOME/.agentsmd/templates"
  printf '{{ nextjs }}\n' > AGENTS.md
  printf 'Global guidance\n' > "$HOME/.agentsmd/templates/nextjs.md"

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Global guidance
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "warns and preserves unresolved tokens" {
  printf 'Before\n\n{{ missing }}\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  [[ "$output" == *"WARNING: template 'missing' not found"* ]]

  cat > expected <<'TXT'
Before

{{ missing }}
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "single blank line between base and append when base has 0 trailing newlines" {
  printf 'Base instructions' > AGENTS.md
  printf 'Appended prefs\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

Appended prefs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "single blank line between base and append when base has 1 trailing newline" {
  printf 'Base instructions\n' > AGENTS.md
  printf 'Appended prefs\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

Appended prefs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "single blank line between base and append when base has 2 trailing newlines" {
  printf 'Base instructions\n\n' > AGENTS.md
  printf 'Appended prefs\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

Appended prefs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "appended content ends with single trailing newline when .agentsmd has 0 trailing newlines" {
  printf 'Base instructions\n' > AGENTS.md
  printf 'Appended prefs' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

Appended prefs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "appended content ends with single trailing newline when .agentsmd has 1 trailing newline" {
  printf 'Base instructions\n' > AGENTS.md
  printf 'Appended prefs\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

Appended prefs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}

@test "appended content ends with single trailing newline when .agentsmd has 2 trailing newlines" {
  printf 'Base instructions\n' > AGENTS.md
  printf 'Appended prefs\n\n' > .agentsmd

  run "$CLI" make
  [ "$status" -eq 0 ]

  cat > expected <<'TXT'
Base instructions

Appended prefs
TXT

  cmp -s expected AGENTS.md
  [ "$?" -eq 0 ]
}
