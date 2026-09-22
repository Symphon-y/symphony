#!/usr/bin/env bats
# Phase 19 acceptance tests: hardware detection and enablement. Static, repo-checkable
# properties; the mechanism is unit-tested (hwmatch, symphony-hardware) and verified on
# the Alienware (see the tracking doc).

setup() {
  load '../helpers/common'
  HW="$REPO_ROOT/home/hardware/dot-local/bin"
}

@test "map: one hardware map, no separate quirks file" {
  assert [ -e "$REPO_ROOT/system/hardware.txt" ]
  assert [ ! -e "$REPO_ROOT/system/quirks.txt" ]
  run grep -rn 'quirks.txt' "$REPO_ROOT/install" "$REPO_ROOT/scripts" "$REPO_ROOT/home" "$REPO_ROOT/gui"
  assert_failure
}

@test "map: every line parses (hwmatch fails closed on a bad one)" {
  run "$REPO_ROOT/scripts/hwmatch" --all
  assert_success
}

@test "map: the Alienware 14's three entries are there -- Broadcom by PCI, dell_rbtn by DMI, AlienFX by USB" {
  run grep -E '^pci:14e4:43b1[[:space:]]+.*packages=broadcom-wl' "$REPO_ROOT/system/hardware.txt"
  assert_success
  run grep -E '^dmi:[^[:space:]]*Alienware[^[:space:]]*[[:space:]]+.*cmdline=module_blacklist=dell_rbtn' "$REPO_ROOT/system/hardware.txt"
  assert_success
  run grep -E '^usb:187c:0525[[:space:]]+.*packages=alienfx' "$REPO_ROOT/system/hardware.txt"
  assert_success
}

@test "wiring: the installer, first-login and the updater all go through symphony-hardware" {
  run grep -F 'symphony-hardware' "$REPO_ROOT/install/configure-base-system"
  assert_success
  run grep -F 'symphony-hardware' "$REPO_ROOT/install/first-login"
  assert_success
  run grep -F 'symphony-hardware' "$REPO_ROOT/home/update/dot-local/bin/symphony-update"
  assert_success
  assert [ -x "$HW/symphony-hardware" ]
}

@test "sound: the global soft-mixer rule is gone; alsa-utils and rtkit ship" {
  run find "$REPO_ROOT/home" -name '*soft-mixer*'
  assert_output ""
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT"/packages/*.txt
  assert_line "alsa-utils"
  assert_line "rtkit"
}

@test "power: power-profiles-daemon ships and is enabled at boot" {
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT"/packages/*.txt
  assert_line "power-profiles-daemon"
  run grep -E '^power-profiles-daemon\.service' "$REPO_ROOT/system/services-root.txt"
  assert_success
}

@test "alienfx: our PKGBUILD (upstream's AUR one is uninstallable), a uaccess udev rule, a theme script and a user unit" {
  assert [ -e "$REPO_ROOT/packages/aur/alienfx/PKGBUILD" ]
  run grep -E "python-pkg_resources" "$REPO_ROOT/packages/aur/alienfx/PKGBUILD"
  assert_failure
  run grep -E 'TAG\+="uaccess"' "$REPO_ROOT/system/hardware/60-alienfx.rules"
  assert_success
  run grep -E 'MODE.*666' "$REPO_ROOT/system/hardware/60-alienfx.rules"
  assert_failure
  assert [ -x "$HW/alienfx-theme" ]
  assert [ -e "$REPO_ROOT/home/hardware/dot-config/systemd/user/alienfx-theme.service" ]
}

@test "alienfx: the theme colour has one home, written by the matugen render, read by alienfx-theme and wallpaper-set calls it" {
  run grep -F 'theme.env' "$REPO_ROOT/home/matugen/dot-config/matugen/config.toml"
  assert_success
  run grep -F 'theme.env' "$HW/alienfx-theme"
  assert_success
  run grep -F 'alienfx-theme' "$REPO_ROOT/home/hyprpaper/dot-local/bin/wallpaper-set"
  assert_success
}

@test "iso: the offline repo builds AUR packages from packages/aur/, so the hardware entry ships" {
  run grep -F 'packages/aur' "$REPO_ROOT/iso/build-offline-repo"
  assert_success
}

@test "docs: DECISIONS.md records D-0082 to D-0084; the hardware runbook exists" {
  local id
  for id in D-0082 D-0083 D-0084; do
    run grep -E "^## $id " "$REPO_ROOT/DECISIONS.md"
    assert_success
  done
  assert [ -f "$REPO_ROOT/docs/runbooks/hardware.md" ]
}
