#!/usr/bin/env bats
# Unit tests for the Phase 18 migration that removes the per-user release marker
# scripts/update used to keep (~/.local/state/symphony/current-release); the
# payload's VERSION is the one source now (D-0079). HOME is a temp dir.

setup() {
  load '../helpers/common'
  SCRIPT=$(ls "$REPO_ROOT"/migrations/*-remove-per-user-release-marker.sh)
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.local/state/symphony"
}

@test "removes the marker when it exists" {
  echo "2026.09.16" >"$HOME/.local/state/symphony/current-release"
  run "$SCRIPT"
  assert_success
  assert [ ! -e "$HOME/.local/state/symphony/current-release" ]
}

@test "is a no-op when it is already gone" {
  run "$SCRIPT"
  assert_success
}

@test "touches nothing else in the state dir" {
  touch "$HOME/.local/state/symphony/first-login-done"
  echo "x" >"$HOME/.local/state/symphony/current-release"
  run "$SCRIPT"
  assert_success
  assert [ -e "$HOME/.local/state/symphony/first-login-done" ]
}
