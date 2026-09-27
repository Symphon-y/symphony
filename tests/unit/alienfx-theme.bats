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

# The colour the written theme asks the controller for.
colour() {
  python3 -c "import json; print(json.load(open('$HOME/.config/alienfx/symphony.json'))['Boot'][0]['loop'][0]['colours'][0])"
}

@test "writes a theme with every Alienware 14 zone in the primary colour, and applies it" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line --regexp "^alienfx --theme symphony --dim (on|off)$"
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
  run colour
  assert_output "[15, 15, 15]"
}

@test "a pastel palette colour loses its white floor, so the LED shows the hue instead of a wash" {
  # Material You's dark-scheme primaries are pastels: #f9bb72's lowest channel is 114
  # of 255, and an LED with 16 levels and a diffuser renders that white floor as pale
  # pink, not amber (seen on the Alienware). Stretching each channel so the lowest
  # reaches zero keeps the hue and the brightness and drops the wash -- as far as
  # dimming leaves room for, below.
  printf 'PRIMARY=#f9bb72\n' >"$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  run colour
  assert_output "[15, 10, 4]"
}

@test "each hue keeps its own character once the floor is gone" {
  local hex expected
  # green pastel -> green; lavender -> lavender, not pure blue; warm amber -> gold
  for hex in "#b0d18b:[8, 12, 4]" "#c1c1ff:[4, 4, 15]" "#ae885d:[10, 7, 4]"; do
    printf 'PRIMARY=%s\n' "${hex%%:*}" >"$HOME/.config/symphony/theme.env"
    expected=${hex#*:}
    run "$SCRIPT"
    assert_success
    run colour
    assert_output "$expected"
  done
}

@test "a grey palette (a monochrome wallpaper) stays grey rather than being forced to a hue" {
  printf 'PRIMARY=#808080\n' >"$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  run colour
  assert_output "[8, 8, 8]"
}

# --- the stretch leaves room for the hardware dim (D-0088) ---------------------------
#
# The dim is multiplicative in the controller's 4 bits, so a channel below 4 of 15 keeps
# fewer than two levels once halved and rounding decides the hue. Fully stretched,
# #cabeff is (3, 0, 15) and dims to about (1, 0, 7): violet to pure blue, which is what
# shipped and what was reported. The stretch is therefore backed off until every lit
# channel survives a dim.

@test "the stretch stops short of a channel that could not survive being dimmed" {
  # The colour that showed the bug. Fully stretched it is (3, 0, 15).
  printf 'PRIMARY=#cabeff\n' >"$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  run colour
  assert_output "[7, 5, 15]"
}

@test "no lit channel is left below the dim floor, whatever the palette is" {
  local hex channel
  # Material You primaries across the hue circle; none of these has a dark channel, so
  # every channel of every one of them has to clear the floor.
  for hex in cabeff f9bb72 b0d18b ae885d a8d5a2 3fa7d6 7f6ae0; do
    printf 'PRIMARY=#%s\n' "$hex" >"$HOME/.config/symphony/theme.env"
    run "$SCRIPT"
    assert_success
    run colour
    for channel in ${output//[^0-9]/ }; do
      ((channel >= 4)) || fail "#$hex gave $output: channel $channel cannot survive a dim"
    done
  done
}

@test "a channel the palette itself left dark stays dark: there is no hue to preserve" {
  printf 'PRIMARY=#0000ff\n' >"$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  run colour
  assert_output "[0, 0, 15]"
}

@test "a colour too dark to satisfy the floor is left alone rather than stretched anyway" {
  # (32, 32, 64) quantises to (2, 2, 4) unstretched and no stretch improves that, so the
  # rule gives up on the floor rather than spending the headroom for nothing.
  printf 'PRIMARY=#202040\n' >"$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  run colour
  assert_output "[2, 2, 4]"
}

@test "black does not divide by zero" {
  printf 'PRIMARY=#000000\n' >"$HOME/.config/symphony/theme.env"
  run "$SCRIPT"
  assert_success
  run colour
  assert_output "[0, 0, 0]"
}

# --- the keyboard backlight level (#26) ----------------------------------------------
#
# Brightness is a hardware state now (alienfx 0x1C, patched in), not a scale on the
# colour. Scaling could not work: with 16 levels per channel a colour whose smallest lit
# channel is a small fraction of its largest loses that channel first, so #cabeff's
# violet flipped to pure blue as it dimmed.

@test "full and dim paint the same colour: only the dim state differs" {
  mkdir -p "$HOME/.local/state/symphony"
  echo full >"$HOME/.local/state/symphony/led-brightness"
  run "$SCRIPT"
  assert_success
  local at_full
  at_full=$(colour)
  echo dim >"$HOME/.local/state/symphony/led-brightness"
  run "$SCRIPT"
  assert_success
  assert_equal "$(colour)" "$at_full"
}

@test "dim asks the hardware to dim" {
  mkdir -p "$HOME/.local/state/symphony"
  echo dim >"$HOME/.local/state/symphony/led-brightness"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "alienfx .*--dim on"
}

@test "full asks the hardware not to dim" {
  mkdir -p "$HOME/.local/state/symphony"
  echo full >"$HOME/.local/state/symphony/led-brightness"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "alienfx .*--dim off"
}

@test "off goes dark, since the controller has no third brightness state" {
  mkdir -p "$HOME/.local/state/symphony"
  echo off >"$HOME/.local/state/symphony/led-brightness"
  run "$SCRIPT"
  assert_success
  run colour
  assert_output "[0, 0, 0]"
}

@test "no level set yet is full brightness, not dark" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "alienfx .*--dim off"
}

@test "a legacy numeric level still means something sensible" {
  # The level used to be 0-100. A machine updating across this change must not end up
  # dark or unreadable because its state file predates the state names.
  mkdir -p "$HOME/.local/state/symphony"
  echo 100 >"$HOME/.local/state/symphony/led-brightness"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "alienfx .*--dim off"
}

@test "a corrupted level is treated as full rather than leaving the keys dark" {
  mkdir -p "$HOME/.local/state/symphony"
  echo "banana" >"$HOME/.local/state/symphony/led-brightness"
  run "$SCRIPT"
  assert_success
  run colour
  refute_output "[0, 0, 0]"
}

@test "the colour is never scaled: no arithmetic on the channels" {
  # The property the old code violated: the same channels at every brightness, the dim
  # being a controller state rather than arithmetic.
  mkdir -p "$HOME/.local/state/symphony"
  local level
  for level in full dim; do
    echo "$level" >"$HOME/.local/state/symphony/led-brightness"
    run "$SCRIPT"
    assert_success
    run colour
    assert_output "[4, 10, 13]"
  done
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
  # realpath and dirname too: the script resolves its own payload root to find
  # scripts/lib, so a PATH without them kills it before the alienfx check.
  for tool in bash sed head mkdir realpath dirname; do
    ln -s "$(command -v "$tool")" "$BATS_TEST_TMPDIR/bin/$tool"
  done
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
  # Root writes a read-only node regardless of its mode, so this state cannot be
  # staged there at all (CI's container is root).
  if ((EUID == 0)); then skip "root can write a 0444 node; the unwritable case cannot be staged"; fi
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
