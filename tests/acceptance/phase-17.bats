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
  BAR="$REPO_ROOT/home/waybar/dot-config/waybar"
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

# --- Step 4: the installed system -------------------------------------------------

@test "system: the installed connectivity-check override is byte-identical to the live ISO's" {
  # One source of truth: the ISO profile cannot symlink out of itself (it would
  # dangle in the image), so the live copy is a copy -- this keeps them one file.
  run cmp "$REPO_ROOT/system/networkmanager/20-connectivity.conf" \
    "$ISO/airootfs/etc/NetworkManager/conf.d/20-connectivity.conf"
  assert_success
}

@test "system: the connectivity override is installed root-owned at /etc/NetworkManager/conf.d" {
  run grep -E '^0644[[:space:]]+networkmanager/20-connectivity\.conf[[:space:]]+/etc/NetworkManager/conf\.d/20-connectivity\.conf$' \
    "$REPO_ROOT/system/files.txt"
  assert_success
}

@test "packages: wireless-regdb is in the inventory (linux-firmware does not pull it in)" {
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT"/packages/*.txt
  assert_success
  assert_line "wireless-regdb"
}

# --- Step 5: the bar and the menu ---------------------------------------------------

# Waybar's config is JSONC; strip whole-line // comments (as phase-05.bats does) so jq can read it.
bar_json() {
  sed -E 's#^[[:space:]]*//.*$##' "$BAR/config.jsonc"
}

@test "bar: the network module is interactive -- click opens the picker, right-click the settings" {
  run bash -c "$(declare -f bar_json); BAR='$BAR'; bar_json | jq -r '.network[\"on-click\"], .network[\"on-click-right\"]'"
  assert_success
  assert_line --index 0 "network-menu"
  assert_line --index 1 "network-menu edit"
}

@test "bar: the network module shows signal strength and every state it can be in" {
  run bash -c "$(declare -f bar_json); BAR='$BAR'; bar_json | jq -e '
    (.network[\"format-icons\"] | length) >= 4
    and (.network | has(\"format-wifi\") and has(\"format-ethernet\") and has(\"format-disconnected\")
         and has(\"format-disabled\") and has(\"format-linked\"))
    and (.network.interval <= 10)
    and (.network | has(\"tooltip-format-wifi\") and has(\"tooltip-format-disconnected\"))'"
  assert_success
}

@test "bar: a battery module sits on the right, with warning below critical thresholds" {
  run bash -c "$(declare -f bar_json); BAR='$BAR'; bar_json | jq -e '
    (.[\"modules-right\"] | index(\"battery\") != null) and (.[\"modules-right\"] | index(\"network\") != null)
    and (.battery.states.warning > .battery.states.critical) and (.battery.states.critical > 0)'"
  assert_success
}

@test "bar: the header no longer claims there is no battery module" {
  run grep -F 'no cpu/memory/battery' "$BAR/config.jsonc"
  assert_failure
}

@test "bar: the stylesheet styles the network and battery states" {
  local selector
  for selector in '#network.disconnected' '#network.disabled' '#network.linked' '#battery.warning' '#battery.critical'; do
    run grep -F "$selector" "$BAR/style.css"
    assert_success
  done
}

@test "bar: every colour the stylesheet uses is defined by the matugen template" {
  # A stylesheet that names a colour colors.css doesn't define fails to load, and
  # the bar is left unstyled -- so the template is the single list to check against.
  local template="$REPO_ROOT/home/matugen/dot-config/matugen/templates/waybar.css"
  local name
  while read -r name; do
    run grep -F "@define-color $name " "$template"
    assert_success
  done < <(grep -o '@[a-z_]*' "$BAR/style.css" | sort -u | grep -vx '@import' | sed 's/^@//')
}

@test "bar: the palette gains an error colour" {
  run grep -F '@define-color error ' "$REPO_ROOT/home/matugen/dot-config/matugen/templates/waybar.css"
  assert_success
}

@test "menu: SUPER+CTRL+N opens network-menu" {
  run grep -E 'CTRL \+ N".*exec_cmd\("network-menu"\)' "$REPO_ROOT/home/hypr/dot-config/hypr/bindings.lua"
  assert_success
}

@test "menu: the networkmanager-dmenu config uses fuzzel and masks the password as it is typed" {
  # networkmanager-dmenu only passes fuzzel --password when obscure = True; its
  # default is False, which would show a Wi-Fi password in plain text.
  local conf="$REPO_ROOT/home/network/dot-config/networkmanager-dmenu/config.ini"
  run grep -E '^dmenu_command[[:space:]]*=[[:space:]]*fuzzel$' "$conf"
  assert_success
  run awk '/^\[dmenu_passphrase\]/{s=1;next} /^\[/{s=0} s && /^obscure[[:space:]]*=[[:space:]]*True$/{f=1} END{exit !f}' "$conf"
  assert_success
}

@test "menu: fuzzel does not quit on an empty dmenu list (it would close the Wi-Fi password prompt)" {
  # networkmanager-dmenu gives fuzzel an empty stdin for the passphrase prompt. With
  # exit-immediately-if-empty=yes fuzzel quits at once, the passphrase is empty, and a
  # profile is saved that never connects (found on the Alienware, D-0075).
  run grep -E '^[[:space:]]*exit-immediately-if-empty' \
    "$REPO_ROOT/home/matugen/dot-config/matugen/templates/fuzzel.ini"
  assert_failure
}

@test "bar: the linked tooltip is true for Wi-Fi too (a link with no address yet is not necessarily a cable)" {
  run bash -c "$(declare -f bar_json); BAR='$BAR'; bar_json | jq -r '.network[\"tooltip-format-linked\"]'"
  assert_success
  refute_output --partial "cable"
  assert_output --partial "{ifname}"
}

@test "menu: network-watch reports the connection outcome, and network-menu calls it (D-0075)" {
  # Executable on Linux; a Windows checkout loses the bit, so the index mode answers there.
  [[ -x "$REPO_ROOT/home/network/dot-local/bin/network-watch" ]] ||
    git -C "$REPO_ROOT" ls-files -s -- home/network/dot-local/bin/network-watch | grep -q '^100755'
  run grep -F 'network-watch' "$REPO_ROOT/home/network/dot-local/bin/network-menu"
  assert_success
}

@test "menu: the picker is reached through network-picker, which prefers wpa-psk on transition networks (D-0077)" {
  # Upstream networkmanager_dmenu hard-codes sae for any WPA3-capable AP; the wl
  # driver cannot do SAE, so the Alienware's picker saved profiles that never
  # connected. network-menu must never call the upstream script directly.
  local shim="$REPO_ROOT/home/network/dot-local/bin/network-picker"
  [[ -x $shim ]] || git -C "$REPO_ROOT" ls-files -s -- home/network/dot-local/bin/network-picker | grep -q '^100755'
  run grep -E '^\s*network-picker' "$REPO_ROOT/home/network/dot-local/bin/network-menu"
  assert_success
  run grep -E '^\s*networkmanager_dmenu' "$REPO_ROOT/home/network/dot-local/bin/network-menu"
  assert_failure
  run grep -F '"wpa-psk"' "$shim"
  assert_success
}

@test "packages: the network picker and the settings window are in the inventory" {
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT"/packages/*.txt
  assert_success
  assert_line "networkmanager-dmenu"
  assert_line "nm-connection-editor"
}

# --- Step 6: the record --------------------------------------------------------------

@test "docs: DECISIONS.md records D-0068 to D-0072" {
  local id
  for id in D-0068 D-0069 D-0070 D-0071 D-0072; do
    run grep -E "^## $id " "$REPO_ROOT/DECISIONS.md"
    assert_success
  done
}

@test "docs: omarchy-influences.md classifies network / Wi-Fi and Bluetooth" {
  run grep -E '^### Network and Wi-Fi' "$REPO_ROOT/docs/omarchy-influences.md"
  assert_success
  run grep -E '^### Bluetooth' "$REPO_ROOT/docs/omarchy-influences.md"
  assert_success
}

@test "docs: the install runbook says Wi-Fi is optional and how to join from a terminal" {
  run grep -F 'nmtui' "$REPO_ROOT/docs/runbooks/base-install.md"
  assert_success
}

# --- Hotfix: diagnosing a blocked or missing Wi-Fi radio on the live ISO ------------

@test "iso: the live ISO carries the tools to diagnose Wi-Fi hardware (iw, lspci, lsusb, evtest)" {
  local pkg
  for pkg in iw pciutils usbutils evtest; do
    run grep -Fx "$pkg" "$ISO/packages.x86_64"
    assert_success
  done
}

@test "docs: the runbook explains symphony.nogui for a terminal on the live ISO" {
  run grep -F 'symphony.nogui' "$REPO_ROOT/docs/runbooks/base-install.md"
  assert_success
}

# --- Hardware that needs extra packages: the PCI-ID map (Broadcom BCM4352) ---------------

@test "hardware: every map entry names a package list that exists" {
  local id list
  while read -r id list _; do
    assert [ -e "$REPO_ROOT/packages/hardware/$list.txt" ]
  done < <(sed -E 's/#.*//' "$REPO_ROOT/system/hardware.txt" | awk 'NF >= 2')
}

@test "hardware: the BCM4352 (14e4:43b1) needs the proprietary wl driver, with headers for both kernels" {
  run grep -E '^14e4:43b1[[:space:]]+broadcom-wl([[:space:]]|$)' "$REPO_ROOT/system/hardware.txt"
  assert_success
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT/packages/hardware/broadcom-wl.txt"
  assert_success
  assert_line "broadcom-wl-dkms"
  # DKMS builds against the headers of each installed kernel; the system has both (D-0012).
  assert_line "linux-headers"
  assert_line "linux-lts-headers"
}

@test "hardware: the proprietary driver is gated by the hardware, not in the general inventory" {
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT"/packages/*.txt
  assert_success
  refute_line "broadcom-wl-dkms"
}

@test "hardware: the offline package repo bakes in the hardware lists too, so an offline install can add them" {
  run grep -F 'packages/hardware' "$REPO_ROOT/iso/build-offline-repo"
  assert_success
}

@test "hardware: the installer asks scripts/hwpkglist what to add" {
  run grep -F 'hwpkglist' "$REPO_ROOT/install/install-base-system"
  assert_success
}

@test "hardware: the installer page reads the same map to describe an adapter" {
  run grep -F 'hardware_map' "$REPO_ROOT/gui/installer/pages/wifi.py"
  assert_success
}

@test "docs: DECISIONS.md records D-0073, D-0074 and D-0076" {
  local id
  for id in D-0073 D-0074 D-0076; do
    run grep -E "^## $id " "$REPO_ROOT/DECISIONS.md"
    assert_success
  done
}

# --- Firmware quirks and the picker outcome (D-0075, D-0076) -----------------------

@test "quirks: the installer asks scripts/quirkparams and hands the result to configure-base-system" {
  run grep -F 'quirkparams' "$REPO_ROOT/install/install-base-system"
  assert_success
  run grep -F 'SYMPHONY_KERNEL_PARAMS' "$REPO_ROOT/install/configure-base-system"
  assert_success
}

@test "quirks: every entry in system/quirks.txt is a DMI pattern and one plain kernel parameter" {
  # The parser is scripts/quirkparams (a malformed line makes it fail), run here against
  # the real map and an empty machine.
  local empty="$BATS_TEST_TMPDIR/sys"
  mkdir -p "$empty"
  SYMPHONY_SYS="$empty" run "$REPO_ROOT/scripts/quirkparams"
  assert_success
}

@test "docs: DECISIONS.md records D-0075, and D-0071 points at it" {
  run grep -E '^## D-0075 ' "$REPO_ROOT/DECISIONS.md"
  assert_success
  run grep -F 'Amended by D-0075' "$REPO_ROOT/DECISIONS.md"
  assert_success
}

@test "docs: DECISIONS.md records D-0077 (the picker's key management), and D-0075 points at it" {
  run grep -E '^## D-0077 ' "$REPO_ROOT/DECISIONS.md"
  assert_success
  run grep -F 'D-0077' "$REPO_ROOT/DECISIONS.md"
  assert_output --partial 'Extended by D-0077'
}

@test "quirks: the Alienware 14's dell_rbtn blacklist is keyed to its DMI, not to every machine" {
  run grep -E '^dmi:[^[:space:]]*Alienware[^[:space:]]*[[:space:]]+module_blacklist=dell_rbtn([[:space:]]|$)' \
    "$REPO_ROOT/system/quirks.txt"
  assert_success
}
