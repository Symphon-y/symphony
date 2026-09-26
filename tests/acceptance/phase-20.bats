#!/usr/bin/env bats
# Phase 20 acceptance tests: an update you can take from the desktop -- a daily check, a
# toast with a button, a waybar badge that stays until you take it (D-0087).
#
# Static group (this file's default): runnable over SSH. Live-session tests are tagged
# in their names and need a logged-in Hyprland session with mako and waybar running.
#
# Run on the machine as the regular user:
#   bats tests/acceptance/phase-20.bats

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

# --- the pieces, and the one-job-each split -----------------------------------------

@test "four scripts ship, each doing one of check, tell, show, apply" {
  local script
  for script in update-check update-notify update-status update-now; do
    assert [ -x "$REPO_ROOT/home/update/dot-local/bin/$script" ]
  done
}

@test "only update-check talks to the release API: the others read its state file" {
  local script
  for script in update-notify update-status update-now; do
    run grep -n "api.github.com" "$REPO_ROOT/home/update/dot-local/bin/$script"
    assert_failure
  done
  run grep -q "api.github.com" "$REPO_ROOT/home/update/dot-local/bin/update-check"
  assert_success
}

@test "the state format has one home, sourced by all four" {
  assert [ -f "$REPO_ROOT/scripts/lib/updates.bash" ]
  local script
  for script in update-check update-notify update-status update-now; do
    run grep -q "scripts/lib/updates.bash" "$REPO_ROOT/home/update/dot-local/bin/$script"
    assert_success
  done
}

@test "nothing applies an upgrade unattended: only update-now runs pacman or the updater" {
  # The timer must never upgrade by itself -- that is the partial-upgrade anti-pattern.
  local script
  for script in update-check update-notify update-status; do
    run grep -nE "pacman -Syu|symphony-update apply" "$REPO_ROOT/home/update/dot-local/bin/$script"
    assert_failure
  done
}

@test "update-now upgrades packages before applying a release" {
  local pac rel
  pac=$(grep -n "pacman -Syu" "$REPO_ROOT/home/update/dot-local/bin/update-now" | cut -d: -f1 | head -1)
  rel=$(grep -n "symphony-update apply" "$REPO_ROOT/home/update/dot-local/bin/update-now" | cut -d: -f1 | head -1)
  assert [ -n "$pac" ]
  assert [ -n "$rel" ]
  assert [ "$pac" -lt "$rel" ]
}

# --- the timer ------------------------------------------------------------------------

@test "the service runs the check and then the notification, in that order" {
  run cat "$REPO_ROOT/home/update/dot-config/systemd/user/update-notify.service"
  assert_success
  assert_line --regexp "ExecStart=.*update-check$"
  assert_line --regexp "ExecStart=.*update-notify$"
  local check notify
  check=$(grep -n "update-check" "$REPO_ROOT/home/update/dot-config/systemd/user/update-notify.service" | cut -d: -f1)
  notify=$(grep -n "update-notify$" "$REPO_ROOT/home/update/dot-config/systemd/user/update-notify.service" | cut -d: -f1)
  assert [ "$check" -lt "$notify" ]
}

@test "the timer is daily, catches up after a machine was off, and is not exactly midnight" {
  run cat "$REPO_ROOT/home/update/dot-config/systemd/user/update-notify.timer"
  assert_success
  assert_line "OnCalendar=daily"
  assert_line "Persistent=true"
  assert_output --partial "RandomizedDelaySec="
}

@test "the timer is enabled and active on this machine" {
  run systemctl --user is-enabled update-notify.timer
  assert_success
  run systemctl --user is-active update-notify.timer
  assert_success
}

# --- the surfaces ---------------------------------------------------------------------

@test "waybar declares the update module, clicking applies and right-clicking re-checks" {
  run cat "$REPO_ROOT/home/waybar/dot-config/waybar/config.jsonc"
  assert_success
  assert_output --partial '"custom/update"'
  assert_output --partial '"exec": "update-status"'
  assert_output --partial '"return-type": "json"'
  assert_output --partial "update-now"
  assert_output --partial "update-notify.service"
}

@test "waybar styles the update module in both of its states" {
  run cat "$REPO_ROOT/home/waybar/dot-config/waybar/style.css"
  assert_success
  assert_output --partial "#custom-update"
  assert_output --partial "#custom-update.release"
}

@test "mako invokes the action on a click, or the button does nothing" {
  run cat "$REPO_ROOT/home/matugen/dot-config/matugen/templates/mako.ini"
  assert_success
  assert_output --partial "[app-name=symphony]"
  assert_output --partial "on-button-left=invoke-default-action"
}

@test "the toast offers an action rather than a command to retype" {
  run grep -E '\-A update=' "$REPO_ROOT/home/update/dot-local/bin/update-notify"
  assert_success
}

@test "the terminal is launched detached, so a oneshot unit cannot kill it mid-update" {
  run grep -E "systemd-run .*--scope" "$REPO_ROOT/home/update/dot-local/bin/update-notify"
  assert_success
}

# --- on this machine ------------------------------------------------------------------

@test "update-status prints either nothing or parseable waybar JSON" {
  run update-status
  assert_success
  if [[ -n $output ]]; then
    run bash -c "update-status | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sorted(d))'"
    assert_success
    assert_output --partial "class"
    assert_output --partial "text"
  fi
}

@test "update-check writes a state file naming this machine's installed version" {
  run update-check
  assert_success
  run grep -E "^installed=" "$HOME/.local/state/symphony/updates"
  assert_success
}

@test "live-session: the update module is in the running bar's config" {
  run pgrep -x waybar
  assert_success
  run grep -q "custom/update" "$HOME/.config/waybar/config.jsonc"
  assert_success
}

@test "live-session: mako has the generated app-name rule (matugen rendered it)" {
  run grep -q "on-button-left=invoke-default-action" "$HOME/.config/mako/config"
  assert_success
}
