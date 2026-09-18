#!/usr/bin/env bats
# Phase 15 acceptance tests: the static, CI-checkable half of Milestone C's
# real GUI installer boot wiring. What actually renders on the Alienware's
# real GPU is real-hardware-only (see the tracking doc's "VM -> physical
# hardware notes") -- these tests only prove the wiring is present and
# internally consistent, not that it renders correctly.

setup() {
  load '../helpers/common'
}

@test "live ISO packages: the GUI stack is present, no Vulkan driver" {
  local pkgs="$REPO_ROOT/iso/profile/packages.x86_64"
  for pkg in cage gtk4 libadwaita python-gobject mesa adwaita-icon-theme cantarell-fonts; do
    run grep -qx "$pkg" "$pkgs"
    assert_success
  done
  # Deliberately not installed: GSK_RENDERER is pinned to the GL renderer
  # (.bash_profile), not the Vulkan one GTK defaults to since 4.16, so the
  # live environment has no need for a Vulkan driver at all. Only match
  # actual package lines, not this file's own explanatory comments.
  run grep -qE '^vulkan' "$pkgs"
  assert_failure
}

@test ".bash_profile: tty1 auto-starts the GUI via cage, with GSK_RENDERER pinned" {
  local bp="$REPO_ROOT/iso/profile/airootfs/root/.bash_profile"
  # shellcheck disable=SC2016 # a literal grep pattern, not meant to expand
  run grep -q '\$(tty) == /dev/tty1' "$bp"
  assert_success
  run grep -q 'GSK_RENDERER=gl' "$bp"
  assert_success
  run grep -q 'exec cage -- /root/autarchy/gui/autarchy-installer' "$bp"
  assert_success
}

@test ".bash_profile: tty2+ still fall through to the terminal fallback banner" {
  local bp="$REPO_ROOT/iso/profile/airootfs/root/.bash_profile"
  # The tty1 branch must exec (replacing the shell) rather than fall
  # through, or every tty would try to launch the GUI.
  run grep -q 'exec cage' "$bp"
  assert_success
  run grep -q 'Run:  autarchy-install' "$bp"
  assert_success
}

@test "gui/autarchy-installer is executable and defaults to the real runner, not --dry-run" {
  local entry="$REPO_ROOT/gui/autarchy-installer"
  assert [ -x "$entry" ]
  run grep -q -- '--dry-run' "$entry"
  assert_success
  # Bare invocation (no flag) must not default dry_run to true.
  run grep -q 'dry_run=args.dry_run' "$entry"
  assert_success
}
