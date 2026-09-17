#!/usr/bin/env bats
# Phase 13 acceptance tests: the offline-capable release ISO. Static,
# VM-checkable properties only -- the real "does the build actually fit in
# CI and produce a working ISO" claim can only be proven by a real tag push
# (see the tracking doc), and "installs with zero network" only by Phase 12
# resuming on real hardware.

setup() {
  load '../helpers/common'
}

@test "iso: a live-environment pacman.conf exists, separate from the build-time one" {
  assert [ -f "$REPO_ROOT/iso/profile/airootfs/etc/pacman.conf" ]
  # profiledef.sh's pacman_conf (iso/profile/pacman.conf) is build-time-only
  # and must stay untouched by this phase -- the live/install-time repo
  # only takes effect via the separate airootfs copy.
  run grep -q '\[localrepo\]' "$REPO_ROOT/iso/profile/pacman.conf"
  assert_failure
}

@test "iso: the live-environment pacman.conf ranks the local repo above core/extra" {
  local conf="$REPO_ROOT/iso/profile/airootfs/etc/pacman.conf"
  local local_line core_line
  local_line=$(grep -n '^\[localrepo\]' "$conf" | cut -d: -f1)
  core_line=$(grep -n '^\[core\]' "$conf" | cut -d: -f1)
  assert [ -n "$local_line" ]
  assert [ -n "$core_line" ]
  assert [ "$local_line" -lt "$core_line" ]
}

@test "iso: the local repo trusts unsigned locally-built packages, and points at a real baked-in path" {
  local conf="$REPO_ROOT/iso/profile/airootfs/etc/pacman.conf"
  run awk '/^\[localrepo\]/,/^\[core\]/' "$conf"
  assert_success
  assert_output --partial "SigLevel = Optional TrustAll"
  assert_output --regexp 'Server = file://'
}

@test "iso: core and extra stay enabled as a network fallback" {
  local conf="$REPO_ROOT/iso/profile/airootfs/etc/pacman.conf"
  run grep -q '^\[core\]' "$conf"
  assert_success
  run grep -q '^\[extra\]' "$conf"
  assert_success
}

@test "release workflow: calls the offline-repo builder before mkarchiso" {
  run grep -q 'build-offline-repo' "$REPO_ROOT/.github/workflows/release-iso.yml"
  assert_success
}

@test "build-offline-repo: downloads the official package closure, builds AUR packages, and repo-adds them" {
  local script="$REPO_ROOT/iso/build-offline-repo"
  assert [ -x "$script" ]
  run grep -q -- '-Syw' "$script"
  assert_success
  run grep -q 'makepkg' "$script"
  assert_success
  run grep -q 'repo-add' "$script"
  assert_success
}

@test "release workflow: logs real disk usage around the build" {
  run grep -q 'df -h' "$REPO_ROOT/.github/workflows/release-iso.yml"
  assert_success
}
