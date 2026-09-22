#!/usr/bin/env bats
# Unit tests for home/hardware/dot-local/bin/alienfx-theme: the AlienFX zones take the
# theme's primary colour (D-0084). The colour comes from the matugen render
# (~/.config/symphony/theme.env, one home); alienfx is a stub on PATH that records the
# theme file it was given.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/hardware/dot-local/bin/alienfx-theme"
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  mkdir -p "$HOME/.config/symphony" "$BATS_TEST_TMPDIR/bin"
  printf 'PRIMARY=#3fa7d6\nBACKGROUND=#101418\n' >"$HOME/.config/symphony/theme.env"
  # The controller, present and writable (the udev rule applied), in fake sysfs/dev.
  export SYMPHONY_SYS="$BATS_TEST_TMPDIR/sys" SYMPHONY_DEV="$BATS_TEST_TMPDIR/dev"
  mkdir -p "$SYMPHONY_SYS/bus/usb/devices/2-1" "$SYMPHONY_DEV/bus/usb/002"
  printf '187c\n' >"$SYMPHONY_SYS/bus/usb/devices/2-1/idVendor"
  printf '0525\n' >"$SYMPHONY_SYS/bus/usb/devices/2-1/idProduct"
  printf '2\n' >"$SYMPHONY_SYS/bus/usb/devices/2-1/busnum"
  printf '4\n' >"$SYMPHONY_SYS/bus/usb/devices/2-1/devnum"
  : >"$SYMPHONY_DEV/bus/usb/002/004"
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\necho "alienfx $*" >>"$STUB_LOG"\n[[ $1 == --theme ]] && cp "$HOME/.config/alienfx/$2.json" "$STUB_LOG.theme" 2>/dev/null\n' >"$BATS_TEST_TMPDIR/bin/alienfx"
  chmod +x "$BATS_TEST_TMPDIR/bin/alienfx"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "writes a theme with every Alienware 14 zone in the primary colour, and applies it" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "alienfx --theme symphony"
  run python3 -c "
import json,sys
t=json.load(open('$HOME/.config/alienfx/symphony.json'))
zones=set(z for state in t if state!='speed' for block in t[state] for z in block['zones'])
print(sorted(zones))
print(t['AC Charged'][0]['loop'][0]['colours'][0])
print(sorted(k for k in t if k!='speed'))
"
  assert_line --index 0 "['Alien Head', 'Left Keyboard', 'Logo', 'Middle-left Keyboard', 'Middle-right Keyboard', 'Right Keyboard', 'Status LEDs', 'Touchpad']"
  assert_line --index 1 "[4, 10, 13]"
  assert_line --index 2 "['AC Charged', 'AC Charging', 'AC Sleep', 'Battery Critical', 'Battery On', 'Battery Sleep', 'Boot']"
}

@test "the colour is scaled to the controller's 4-bit channels (0-15)" {
  printf 'PRIMARY=#ffffff\n' >"$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  run python3 -c "import json; print(json.load(open('$HOME/.config/alienfx/symphony.json'))['Boot'][0]['loop'][0]['colours'][0])"
  assert_output "[15, 15, 15]"
}

@test "no theme colour yet (first login before a render): silent, exit 0, nothing applied" {
  rm "$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  assert_output ""
  run calls
  assert_output ""
}

@test "alienfx not installed (a machine without the controller): silent, exit 0" {
  # Removing the stub is not enough on a machine that has the real tool (the dev
  # seat): give the script a PATH with only what it needs and no alienfx.
  rm "$BATS_TEST_TMPDIR/bin/alienfx"
  local tool
  for tool in bash sed head mkdir; do ln -s "$(command -v "$tool")" "$BATS_TEST_TMPDIR/bin/$tool"; done
  run env PATH="$BATS_TEST_TMPDIR/bin" "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}

@test "no controller on the bus (a machine that got the package by mistake, or it is unplugged): silent, exit 0" {
  rm -rf "$SYMPHONY_SYS/bus/usb/devices/2-1"
  run "$SCRIPT"
  assert_success
  assert_output ""
  run calls
  assert_output ""
}

@test "a controller present but not writable (udev rule not applied yet) gives one line on stderr, never alienfx's retry flood" {
  chmod 444 "$SYMPHONY_DEV/bus/usb/002/004"
  run --separate-stderr "$SCRIPT"
  assert_success
  [[ $stderr == *"not writable"* ]]
  [[ $stderr == *"/dev/bus/usb/002/004"* ]]
  run calls
  refute_output --partial "alienfx --theme"
}

@test "alienfx failing (device unplugged, no access) is reported on stderr but does not fail the caller" {
  printf '#!/usr/bin/env bash\necho "no device" >&2\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/alienfx"
  run --separate-stderr "$SCRIPT"
  assert_success
  [[ $stderr == *"no device"* ]]
}
