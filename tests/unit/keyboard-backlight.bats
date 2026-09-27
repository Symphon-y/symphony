#!/usr/bin/env bats
# Unit tests for home/hardware/dot-local/bin/keyboard-backlight (#26): the keyboard
# lighting role.
#
# Brightness here is three states, not a percentage, because that is what the hardware
# has: alienfx's 0x1C command takes Enable or Disable, so the controller is either
# dimmed or not. Off is a dark colour, there being no third state. The percentages this
# script used to keep were a fiction over scaling the RGB values -- which on a 4-bit
# controller loses the smallest lit channel first and visibly shifted the hue.
#
# The painter is asked for through systemd, never run here: two at once wedge the USB
# controller.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/hardware/dot-local/bin/keyboard-backlight"
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYMPHONY_STATE="$HOME/.local/state/symphony"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  LEVEL="$SYMPHONY_STATE/led-brightness"
  mkdir -p "$SYMPHONY_STATE" "$BATS_TEST_TMPDIR/bin"
  : >"$STUB_LOG"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "alienfx-theme${*:+ $*}" >>"$STUB_LOG"\n' \
    >"$BATS_TEST_TMPDIR/bin/alienfx-theme"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "systemctl $*" >>"$STUB_LOG"\n' \
    >"$BATS_TEST_TMPDIR/bin/systemctl"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "notify-send $*" >>"$STUB_LOG"\nprintf 77\n' \
    >"$BATS_TEST_TMPDIR/bin/notify-send"
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

# --- stepping through the states the hardware actually has --------------------------

@test "a machine that has never set a level is at full, not dark" {
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "dim"
}

@test "up from dim reaches full" {
  echo dim >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run cat "$LEVEL"
  assert_output "full"
}

@test "down from dim reaches off" {
  echo dim >"$LEVEL"
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "off"
}

@test "up at full stays full rather than wrapping round to off" {
  echo full >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run cat "$LEVEL"
  assert_output "full"
}

@test "down at off stays off" {
  echo off >"$LEVEL"
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "off"
}

@test "off goes straight to dark, the thing most reached for" {
  echo full >"$LEVEL"
  run "$SCRIPT" off
  assert_success
  run cat "$LEVEL"
  assert_output "off"
}

# --- state a machine might already have --------------------------------------------

@test "a legacy numeric level is read as the nearest state, not as a failure" {
  # The level was 0-100 before the hardware dim was found. A machine updating across
  # that change must not be left dark or stuck.
  # 0 is the only percentage that means off; anything above it was lit, so it maps
  # to the nearest lit state.
  local -A expected=([0]=off [10]=dim [40]=dim [60]=full [100]=full)
  local value
  for value in "${!expected[@]}"; do
    echo "$value" >"$LEVEL"
    run "$SCRIPT" up
    assert_success
    # up from the mapped state: off -> dim, dim -> full, full -> full
    case ${expected[$value]} in
      off) assert_equal "$(cat "$LEVEL")" dim ;;
      dim) assert_equal "$(cat "$LEVEL")" full ;;
      full) assert_equal "$(cat "$LEVEL")" full ;;
    esac
  done
}

@test "a corrupted level reads as full rather than leaving the keys dark" {
  echo "banana" >"$LEVEL"
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "dim"
}

# --- the repaint ---------------------------------------------------------------------

@test "it asks for a repaint, or the new state would not show" {
  echo dim >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "restart alienfx-theme.service"
}

@test "it never runs the painter itself: two at once wedge the USB controller" {
  echo dim >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run bash -c "grep -c '^alienfx-theme' '$STUB_LOG' || true"
  assert_output "0"
}

@test "the OSD does not wait for the paint" {
  echo dim >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "--no-block"
}

@test "the OSD names the state, rather than a percentage the hardware cannot honour" {
  echo dim >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --regexp "notify-send .*[Ff]ull"
}

@test "the OSD still carries a bar position, so it reads like the volume one" {
  echo off >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "int:value:"
}

# --- usage ---------------------------------------------------------------------------

@test "an unknown verb is a usage error, and repaints nothing" {
  run "$SCRIPT" glow
  assert_failure
  assert_output --partial "usage"
  run calls
  refute_output --partial "alienfx-theme"
  refute_output --partial "systemctl"
}

@test "no verb at all is a usage error" {
  run "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}
