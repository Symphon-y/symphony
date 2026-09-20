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
