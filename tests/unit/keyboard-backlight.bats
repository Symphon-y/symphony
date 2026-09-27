#!/usr/bin/env bats
# Unit tests for home/hardware/dot-local/bin/keyboard-backlight (#26): the keyboard
# lighting role. There is no kernel LED device for the AlienFX, so "brightness" is a
# scale the painter applies before quantising -- this script only moves the level and
# asks alienfx-theme to repaint.

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

@test "a machine that has never set a level is at full, not dark" {
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "95"
}

@test "up raises the level" {
  echo 50 >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run cat "$LEVEL"
  assert_output "55"
}

@test "down lowers it" {
  echo 50 >"$LEVEL"
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "45"
}

@test "it stops at 100 rather than climbing past it" {
  echo 100 >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run cat "$LEVEL"
  assert_output "100"
}

@test "it stops at 0, which is off" {
  echo 0 >"$LEVEL"
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "0"
}

@test "off goes straight to dark, the thing most reached for" {
  echo 80 >"$LEVEL"
  run "$SCRIPT" off
  assert_success
  run cat "$LEVEL"
  assert_output "0"
}

@test "a step can be given" {
  echo 50 >"$LEVEL"
  run "$SCRIPT" up 25
  assert_success
  run cat "$LEVEL"
  assert_output "75"
}

@test "it asks for a repaint, or the new level would not show until the next wallpaper" {
  echo 50 >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "restart alienfx-theme.service"
}

@test "it never runs the painter itself: two at once wedge the USB controller" {
  # A held key spawned one painter per press; the losers spun forever on the device,
  # the level and the OSD moved, and the lights did not.
  echo 50 >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  refute_line "alienfx-theme"
}

@test "the OSD does not wait for the paint" {
  echo 50 >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "--no-block"
}

@test "the OSD says the level" {
  echo 50 >"$LEVEL"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "55%"
}

@test "a corrupted level reads as full rather than leaving the keys dark" {
  echo "banana" >"$LEVEL"
  run "$SCRIPT" down
  assert_success
  run cat "$LEVEL"
  assert_output "95"
}

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
