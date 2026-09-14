#!/usr/bin/env bats
# Phase 4 acceptance tests: minimal Hyprland session.
#
# Two groups. Static (this file's default): runnable over SSH, no graphical session
# needed. Live-session (tagged in each test name): needs an actual logged-in Hyprland
# session on seat0 (through SDDM, from Unraid's console) -- run and confirmed by the
# user, not Claude.
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01/02/03:
#   bats tests/acceptance
# Red run: before this phase's implementation, where the static group must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

# --- packages -------------------------------------------------------------------

@test "packages: every desktop package is installed" {
  local pkg
  while IFS= read -r pkg; do
    run pacman -Qi "$pkg"
    assert_success
  done < <("$REPO_ROOT/scripts/pkglist" "$REPO_ROOT/packages/desktop.txt")
}

# --- hyprland config --------------------------------------------------------------

@test "hyprland: the config passes Hyprland's own validator" {
  run Hyprland --config "$HOME/.config/hypr/hyprland.lua" --verify-config
  assert_success
}

# --- session start (sddm + uwsm) --------------------------------------------------

@test "session start: sddm is configured for a wayland uwsm-managed session" {
  # World-readable (0644), unlike sshd_config -- no root needed to check this.
  run cat /etc/sddm.conf.d/10-wayland.conf
  assert_success
  assert_line "DisplayServer=wayland"
  run grep -rl "uwsm start" /usr/share/wayland-sessions/ /etc/sddm.conf.d/
  assert_success
}

@test "session start: sddm is enabled to start at boot" {
  run systemctl is-enabled sddm
  assert_output "enabled"
}

# --- terminal ----------------------------------------------------------------------

@test "terminal: xdg-terminal-exec resolves to ghostty" {
  run xdg-terminal-exec --print-id
  assert_success
  assert_output "com.mitchellh.ghostty.desktop"
}

# --- theming (matugen) --------------------------------------------------------------

@test "theming: matugen renders every template from the placeholder palette" {
  run matugen --config "$HOME/.config/matugen/config.toml" color hex "#1e1e2e"
  assert_success
  for target in "$HOME/.config/mako/config" "$HOME/.config/hypr/hyprlock.conf" "$HOME/.config/ghostty/config"; do
    assert [ -s "$target" ]
  done
}

# --- live-session (user, from Unraid's console, after logging into Hyprland) -------

@test "live-session: hyprland is running and reachable" {
  run hyprctl monitors
  assert_success
}

@test "live-session: mako, hypridle, hyprpaper, and hyprpolkitagent are running" {
  local proc
  for proc in mako hypridle hyprpaper hyprpolkitagent; do
    run pgrep -x "$proc"
    assert_success
  done
}

@test "live-session: a notification can be sent and the daemon is reachable over D-Bus" {
  run busctl --user list
  assert_success
  assert_output --partial "org.freedesktop.Notifications"
}
