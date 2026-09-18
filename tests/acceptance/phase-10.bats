#!/usr/bin/env bats
# Phase 10 acceptance tests: the installable release ISO and the ongoing
# update pipeline. Everything here is checkable from the VM -- no physical
# hardware is needed for this phase.

setup() {
  load '../helpers/common'
}

# --- archiso profile ------------------------------------------------------

@test "iso: a standard archiso profile exists" {
  assert [ -f "$REPO_ROOT/iso/profile/profiledef.sh" ]
  assert [ -f "$REPO_ROOT/iso/profile/packages.x86_64" ]
  assert [ -f "$REPO_ROOT/iso/profile/pacman.conf" ]
}

@test "iso: profiledef.sh only enables the UEFI boot mode (D-0010, UEFI-only)" {
  run awk '/^bootmodes=/,/\)/' "$REPO_ROOT/iso/profile/profiledef.sh"
  assert_success
  refute_output --partial "bios."
  assert_output --partial "uefi.systemd-boot"
}

@test "iso: packages.x86_64 stays a thin installer -- no desktop-stack packages baked in" {
  run grep -Ex 'hyprland|waybar|chromium' "$REPO_ROOT/iso/profile/packages.x86_64"
  assert_failure
}

@test "iso: packages.x86_64 includes what the live installer environment needs" {
  local pkg
  # git/gh/bats: the repo-access and test-running tools this runbook step
  # itself names. gptfdisk/parted/cryptsetup/btrfs-progs/dosfstools/
  # arch-install-scripts: every external command install-base-system
  # calls directly on the live medium (not through arch-chroot) during
  # partition/LUKS/Btrfs/ESP/pacstrap -- parted (for partprobe) was
  # missing here on a real hardware boot test ("partprobe: command not
  # found"), unlike the stock Arch ISO, which carries it by default.
  for pkg in git github-cli bats bats-assert bats-support \
    gptfdisk parted cryptsetup btrfs-progs dosfstools arch-install-scripts; do
    run grep -qx "$pkg" "$REPO_ROOT/iso/profile/packages.x86_64"
    assert_success
  done
}

@test "iso: pacman.conf declares no custom repo (stays clear of D-0050's REJECT)" {
  run grep -E '^\[' "$REPO_ROOT/iso/profile/pacman.conf"
  assert_success
  refute_output --partial "[omarchy]"
  assert_line "[core]"
  assert_line "[extra]"
}

# --- release workflow -------------------------------------------------------

@test "release workflow: exists and is valid YAML" {
  local wf="$REPO_ROOT/.github/workflows/release-iso.yml"
  assert [ -f "$wf" ]
  run yq '.' "$wf"
  assert_success
}

@test "release workflow: triggers only on a date-shaped tag push" {
  local wf="$REPO_ROOT/.github/workflows/release-iso.yml"
  run yq '.on.push.tags[]' "$wf"
  assert_success
  assert_output --partial "20*.*.*"
}

@test "release workflow: runs mkarchiso and publishes a GitHub Release" {
  run grep -q 'mkarchiso' "$REPO_ROOT/.github/workflows/release-iso.yml"
  assert_success
  run grep -qE 'action-gh-release|gh release' "$REPO_ROOT/.github/workflows/release-iso.yml"
  assert_success
}

# --- new scripts exist and are wired in ------------------------------------

@test "install-base-system: exists, is executable, and requires a vars file" {
  local script="$REPO_ROOT/install/install-base-system"
  assert [ -x "$script" ]
  run "$script"
  assert_failure
  assert_output --partial "usage"
}

@test "scripts/update: exists, is executable, and supports check and apply" {
  local script="$REPO_ROOT/scripts/update"
  assert [ -x "$script" ]
  run "$script" bogus-subcommand
  assert_failure
  assert_output --partial "usage"
}

@test "docs: base-install.md documents both the release-ISO path and the manual fallback" {
  run grep -qi "release" "$REPO_ROOT/docs/runbooks/base-install.md"
  assert_success
  run grep -qi "install-base-system" "$REPO_ROOT/docs/runbooks/base-install.md"
  assert_success
}

@test "docs: docs/runbooks/update.md exists" {
  assert [ -f "$REPO_ROOT/docs/runbooks/update.md" ]
}
