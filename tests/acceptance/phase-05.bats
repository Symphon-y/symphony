#!/usr/bin/env bats
# Phase 5 acceptance tests: interaction (launcher, keybindings, clipboard,
# screenshots, status bar, power menu).
#
# Two groups, same split as Phase 4. Static (this file's default): runnable over
# SSH, no graphical session needed. Live-session (tagged in each test name): needs
# an actual logged-in Hyprland session on seat0. Package installation and the
# generic Hyprland-config/home-linking checks are already covered by
# phase-04.bats's tests (which iterate all of packages/desktop.txt and all of
# home/), so this file only adds Phase-5-specific checks, not duplicates.
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01..04:
#   bats tests/acceptance
# Red run: before this phase's implementation, where the static group must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

# --- status bar (waybar) ------------------------------------------------------

@test "status bar: waybar's config is valid JSON" {
  run jq empty "$HOME/.config/waybar/config.jsonc"
  assert_success
}

@test "theming: matugen renders the waybar template" {
  run matugen --config "$HOME/.config/matugen/config.toml" color hex "#1e1e2e"
  assert_success
  assert [ -s "$HOME/.config/waybar/colors.css" ]
}

# --- live-session (user, from Unraid's console, logged into Hyprland) ---------

@test "live-session: waybar is running" {
  run pgrep -x waybar
  assert_success
}

@test "live-session: fuzzel runs" {
  run fuzzel --version
  assert_success
}

@test "live-session: a screenshot can be captured" {
  local out="$BATS_TEST_TMPDIR/screenshot-test.png"
  run grim "$out"
  assert_success
  assert [ -s "$out" ]
}

@test "live-session: clipboard history captures a copied value" {
  local marker="phase-05-clipboard-test-$$"
  printf '%s' "$marker" | wl-copy
  sleep 1
  run cliphist list
  assert_success
  assert_output --partial "$marker"
}
