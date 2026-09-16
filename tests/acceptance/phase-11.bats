#!/usr/bin/env bats
# Phase 11 acceptance tests: default browser and web-app launching.
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01..09:
#   bats tests/acceptance
# Red run: before this phase's implementation, where the static group must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

# --- packages -------------------------------------------------------------------

@test "packages: chromium and xdg-utils are installed" {
  run pacman -Qi chromium
  assert_success
  run pacman -Qi xdg-utils
  assert_success
}

# --- default browser --------------------------------------------------------------

@test "xdg: chromium is the registered default web browser" {
  run xdg-settings get default-web-browser
  assert_success
  assert_output --partial "chromium"
}

@test "webapp-launch: fails clearly on a missing url argument" {
  run "$HOME/.local/bin/webapp-launch"
  assert_failure 2
  assert_output --partial "usage"
}

# --- live-session (user, from Unraid's console, after logging into Hyprland) -------

@test "live-session: fuzzel finds and launches chromium" {
  skip "manual: confirmed by the user -- fuzzel's search UI isn't scriptable over SSH"
}

@test "live-session: webapp-install + webapp-launch open a real app-mode window" {
  skip "manual: confirmed by the user"
}
