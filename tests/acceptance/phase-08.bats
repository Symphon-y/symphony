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

@test "packages: a machine's own list (packages/local/) is gitignored and outside every install-time glob" {
  # scripts/pkg-audit reads packages/local/<hostname>.txt as declared-on-purpose;
  # nothing that installs or builds an ISO may see it.
  run git -C "$REPO_ROOT" check-ignore -q packages/local/anything.txt
  assert_success
  run grep -rn 'packages/local' "$REPO_ROOT/install" "$REPO_ROOT/iso" "$REPO_ROOT/scripts/build-iso"
  assert_failure
}
