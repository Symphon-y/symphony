#!/usr/bin/env bats
# Phase 9 acceptance tests: standard Arch upkeep automation (mirror refresh,
# btrfs scrub, journal size cap, AUR build-cache cleanup, update notifications).
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01..08:
#   bats tests/acceptance
# Red run: before this phase's implementation, where the static group must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

# --- packages -----------------------------------------------------------------

@test "packages: reflector is installed" {
  run pacman -Qi reflector
  assert_success
}

# --- reflector ------------------------------------------------------------------

@test "reflector: config sets save path, protocol, and country" {
  run cat /etc/xdg/reflector/reflector.conf
  assert_success
  assert_output --partial "--save /etc/pacman.d/mirrorlist"
  assert_output --partial "--protocol https"
  assert_output --partial "--country"
}

# --- journald ---------------------------------------------------------------------

@test "journald: the size-cap drop-in is present and merged" {
  run systemd-analyze cat-config systemd/journald.conf
  assert_success
  assert_output --regexp "SystemMaxUse=[0-9]+[MG]"
}

# --- root services ------------------------------------------------------------------

@test "root services: reflector, btrfs-scrub, and pacman-filesdb-refresh timers are enabled" {
  run "$REPO_ROOT/install/enable-root-services" check
  assert_success
}

# --- yay --------------------------------------------------------------------------

@test "yay: cleanAfter is configured so AUR build sources never accumulate" {
  run jq -e '.cleanAfter == true' "$HOME/.config/yay/config.json"
  assert_success
}

# --- update-notify ------------------------------------------------------------------

@test "update-notify: user timer is enabled" {
  run "$REPO_ROOT/install/enable-user-services" check
  assert_success
}

@test "update-notify: the script runs cleanly with no pending-updates false positive" {
  run "$HOME/.local/bin/update-notify"
  assert_success
}

# --- live-session (user) -----------------------------------------------------------

@test "live-session: update-notify delivers a real desktop notification when updates are pending" {
  skip "manual: confirmed by the user once real pending updates exist to notify about"
}
