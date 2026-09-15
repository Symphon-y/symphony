#!/usr/bin/env bats
# Phase 8 acceptance tests: packages, reproducibility, recovery. Static only --
# nothing in this phase needs a live Hyprland session.
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01..07:
#   bats tests/acceptance
# Red run: before this phase's implementation, where they must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

@test "packages: pkg-audit finds zero drift" {
  run "$REPO_ROOT/scripts/pkg-audit"
  assert_success
}

@test "migrations: nothing pending" {
  run "$REPO_ROOT/scripts/migrate" check
  assert_success
  assert_output --partial "nothing pending"
}

@test "services: every declared user service is enabled and active" {
  run "$REPO_ROOT/install/enable-user-services" check
  assert_success
}

@test "rebuild runbook exists and references the real scripts it documents" {
  run cat "$REPO_ROOT/docs/runbooks/rebuild.md"
  assert_success
  assert_output --partial "scripts/pkg-audit"
  assert_output --partial "scripts/migrate"
  assert_output --partial "install/enable-user-services"
  assert_output --partial "install/link-home"
  assert_output --partial "install/sync-system"
}
