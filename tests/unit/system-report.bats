#!/usr/bin/env bats
# Unit tests for scripts/system-report's Wi-Fi section (Phase 17). The rest of the
# report reads the real machine and is read-only; nmcli and rfkill are stubbed here so
# the section's content is known.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/system-report"
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nprintf "WIFI-HW  WIFI\nmissing  enabled\n"\n' >"$bin/nmcli"
  printf '#!/usr/bin/env bash\nprintf "0: phy0: Wireless LAN\n\tSoft blocked: no\n\tHard blocked: yes\n"\n' >"$bin/rfkill"
  chmod +x "$bin/nmcli" "$bin/rfkill"
  PATH="$bin:$PATH"
}

@test "has a Wi-Fi section" {
  run "$SCRIPT"
  assert_output --partial "## Wi-Fi"
}

@test "the Wi-Fi section reports NetworkManager's view of the radio" {
  run "$SCRIPT"
  assert_output --partial "missing  enabled"
}

@test "the Wi-Fi section reports rfkill, including a hard block" {
  run "$SCRIPT"
  assert_output --partial "phy0: Wireless LAN"
  assert_output --partial "Hard blocked: yes"
}

@test "the Wi-Fi section carries the machine's own facts (the installer page's Details)" {
  run "$SCRIPT"
  assert_output --partial "Wi-Fi adapter"
}
