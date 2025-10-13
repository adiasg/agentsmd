#!/usr/bin/env bash

# Common helpers for BATS specs

setup_repo() {
  PROJECT_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  CLI="$PROJECT_ROOT/bin/agentsmd"
  REPO_DIR=$(mktemp -d)
  export PROJECT_ROOT CLI REPO_DIR

  git -C "$REPO_DIR" init -q
  git -C "$REPO_DIR" config user.name "Test User"
  git -C "$REPO_DIR" config user.email "test@example.com"

  # Isolate user-level state
  HOME="$REPO_DIR/home"
  mkdir -p "$HOME"
  export HOME

  cd "$REPO_DIR"
}

teardown_repo() {
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$REPO_DIR"
}


