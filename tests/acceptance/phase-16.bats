#!/usr/bin/env bats
# Phase 16 acceptance tests: a fresh install boots into a working desktop with
# a self-contained layout -- no repo checkout, no ~/Projects, the user's XDG
# directories in place. Static, repo-checkable properties only: the install
# and first-boot behaviour itself is covered by the unit tests
# (configure-base-system, first-login) and, for real, by installing a tagged
# ISO on hardware (see the tracking doc).

setup() {
  load '../helpers/common'
}

@test "system/xdg/user-dirs.defaults creates Documents, Downloads, Music, Pictures and Videos only" {
  local f="$REPO_ROOT/system/xdg/user-dirs.defaults"
  assert [ -e "$f" ]
  run grep -E '^[A-Z]+=' "$f"
  assert_success
  assert_line "DOWNLOAD=Downloads"
  assert_line "DOCUMENTS=Documents"
  assert_line "MUSIC=Music"
  assert_line "PICTURES=Pictures"
  assert_line "VIDEOS=Videos"
  # xdg-user-dirs 0.20's own defaults also create PROJECTS (and the legacy
  # Desktop/Templates/Public); every key left out here is never created.
  refute_output --partial "PROJECTS"
  refute_output --partial "DESKTOP"
  refute_output --partial "TEMPLATES"
  refute_output --partial "PUBLICSHARE"
}

@test "system/files.txt installs the XDG defaults root-owned at /etc/xdg/user-dirs.defaults" {
  run grep -E '^0644[[:space:]]+xdg/user-dirs\.defaults[[:space:]]+/etc/xdg/user-dirs\.defaults$' "$REPO_ROOT/system/files.txt"
  assert_success
}

@test "packages: xdg-user-dirs is in the inventory, so pacstrap installs it" {
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT"/packages/*.txt
  assert_success
  assert_line "xdg-user-dirs"
}

@test "nothing that ships to an installed machine points at ~/Projects/autarchy" {
  # Docs may still describe a dev clone there; code and config must not depend
  # on it -- the installed machine has no checkout at all.
  run grep -rn 'Projects/autarchy' \
    "$REPO_ROOT/install" "$REPO_ROOT/scripts" "$REPO_ROOT/home" "$REPO_ROOT/system"
  assert_failure
}

@test "release workflow: does not bake .git into the live ISO (installed machines don't get a checkout)" {
  run grep -q -- "--exclude='.git'" "$REPO_ROOT/.github/workflows/release-iso.yml"
  assert_success
}

@test "configure-base-system installs the payload where the first-login hook looks for it" {
  # The hook (autostart.lua) and the installer must agree on one path.
  run grep -F 'readonly PAYLOAD_ROOT=/usr/local/share/autarchy' "$REPO_ROOT/install/configure-base-system"
  assert_success
  # shellcheck disable=SC2016 # matching the script's literal text, not expanding it
  run grep -F 'readonly PAYLOAD_DIR=$PAYLOAD_ROOT/current' "$REPO_ROOT/install/configure-base-system"
  assert_success
  run grep -F '/usr/local/share/autarchy/current/install/first-login' "$REPO_ROOT/home/hypr/dot-config/hypr/autostart.lua"
  assert_success
}

@test "no Hyprland exec command starts with a bracket (Hyprland would parse it as exec rules)" {
  # Found on the Alienware (Phase 16 round 2): `hl.exec_cmd("[ -x path ] && path")`
  # never ran first-login. Hyprland strips a leading `[...]` from every exec
  # command as its rule block (`[workspace 2 silent] cmd`), so the shell got
  # ` && path` -- a syntax error -- on every login, silently. A `test -x` guard
  # does the same job without the bracket.
  run grep -rnE 'exec_cmd\(\s*"\s*\[' "$REPO_ROOT"/home/hypr/dot-config/hypr/*.lua
  assert_failure
}

@test "iso/write-usb.ps1 keeps its safety checks: USB-only, not the system disk, typed confirmation, checksum, read-back" {
  # Can't be run here (Windows-only, needs a real disk); these are the guards a
  # later edit must not quietly drop.
  local ps="$REPO_ROOT/iso/write-usb.ps1"
  run grep -F "BusType -ne 'USB'" "$ps"
  assert_success
  # shellcheck disable=SC2016 # matching PowerShell's literal text, not expanding it
  run grep -F 'IsSystem -or $Disk.IsBoot' "$ps"
  assert_success
  run grep -F 'Read-Host' "$ps"
  assert_success
  run grep -F 'Test-IsoChecksum' "$ps"
  assert_success
  run grep -F 'Get-PrefixHash' "$ps"
  assert_success
}

@test "scripts/build-iso builds from git objects, not a bind mount of the working tree" {
  # No host:container volume mapping (`command -v` is a different -v).
  run grep -E -- '(^|[[:space:]])-v[[:space:]]+[^[:space:]]+:|--volume|--mount' "$REPO_ROOT/scripts/build-iso"
  assert_failure
  # shellcheck disable=SC2016 # matching the script's literal text, not expanding it
  run grep -F 'git -C "$REPO_ROOT" bundle create' "$REPO_ROOT/scripts/build-iso"
  assert_success
}
