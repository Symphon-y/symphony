#!/usr/bin/env bats
# Phase 17 acceptance tests: optional Wi-Fi at install, and an interactive network
# bar. Static, repo-checkable properties only -- the Wi-Fi logic itself is unit-tested
# (gui/tests/test_wifi.py, tests/unit/configure-base-system.bats, network-menu.bats)
# and the radio, the bar and the installer page are verified on real hardware (see
# the tracking doc).

setup() {
  load '../helpers/common'
  ISO="$REPO_ROOT/iso/profile"
  WANTS="$ISO/airootfs/etc/systemd/system/multi-user.target.wants"
}

# --- Step 1: the live ISO runs NetworkManager ------------------------------------

@test "iso: NetworkManager and systemd-resolved are enabled on the live medium" {
  assert is_symlink "$WANTS/NetworkManager.service"
  assert is_symlink "$WANTS/systemd-resolved.service"
}

@test "iso: iwd and dhcpcd are gone -- one network stack, the installed system's" {
  # A second manager on the same interface would fight NetworkManager for it.
  run grep -E '^(iwd|dhcpcd)$' "$ISO/packages.x86_64"
  assert_failure
  refute is_symlink "$WANTS/iwd.service"
  refute is_symlink "$WANTS/dhcpcd.service"
}

@test "iso: packages.x86_64 lists networkmanager" {
  run grep -Fx 'networkmanager' "$ISO/packages.x86_64"
  assert_success
}

@test "iso: packages.x86_64 no longer describes itself as a network installer (D-0063: it is offline)" {
  run grep -i 'network installer' "$ISO/packages.x86_64"
  assert_failure
  run grep -i 'offline' "$ISO/packages.x86_64"
  assert_success
}

@test "iso: the live session's NetworkManager does not phone home (connectivity check off)" {
  local conf="$ISO/airootfs/etc/NetworkManager/conf.d/20-connectivity.conf"
  assert [ -e "$conf" ]
  run grep -Fx '[connectivity]' "$conf"
  assert_success
  run grep -Fx 'enabled=false' "$conf"
  assert_success
}

@test "iso: the terminal-fallback login banner says how to join Wi-Fi (nmtui)" {
  # The live ISO used to need an undocumented `iwctl`; with NetworkManager the
  # standard nmtui does it, and whatever it saves is carried to the new system.
  run grep -F 'nmtui' "$ISO/airootfs/root/.bash_profile"
  assert_success
}

# --- Step 3: the installer's Wi-Fi page ------------------------------------------

@test "installer: the Wi-Fi page sits between LanguageRegion and Account" {
  local pages="$REPO_ROOT/gui/installer/pages/__init__.py"
  local list lang wifi account
  list=$(awk '/^PAGES = \[/,/^\]/' "$pages")
  lang=$(grep -n 'LanguageRegionPage' <<<"$list" | cut -d: -f1)
  wifi=$(grep -n 'WifiPage' <<<"$list" | cut -d: -f1)
  account=$(grep -n 'AccountPage' <<<"$list" | cut -d: -f1)
  assert [ -n "$wifi" ]
  assert [ "$lang" -lt "$wifi" ]
  assert [ "$wifi" -lt "$account" ]
}

@test "installer: the Review page shows the Wi-Fi network (or that it was skipped)" {
  run grep -F '"Wi-Fi"' "$REPO_ROOT/gui/installer/pages/review.py"
  assert_success
}

@test "installer: the Wi-Fi page picks the demo backend under --dry-run, and never stores a password in Answers" {
  local page="$REPO_ROOT/gui/installer/pages/wifi.py"
  run grep -F 'dry_run' "$page"
  assert_success
  run grep -F 'demo_backend' "$page"
  assert_success
  run grep -E 'answers\.[a-z_]*(psk|pass)' "$page"
  assert_failure
}
