#!/usr/bin/env bats
# Unit tests for home/media/dot-local/bin/brightness (Phase 21): the brightness role,
# called by XF86MonBrightnessUp/Down. brightnessctl and notify-send are stubs on PATH.
#
# brightnessctl -m prints one machine-readable line:
#   intel_backlight,backlight,3000,45%,7500
# -- device, class, current, percent, max. Field 4 is what the OSD shows.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/media/dot-local/bin/brightness"
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYMPHONY_STATE="$HOME/.local/state/symphony"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$SYMPHONY_STATE" "$BATS_TEST_TMPDIR/bin"
  : >"$STUB_LOG"
  export STUB_BRIGHTNESS="intel_backlight,backlight,3000,45%,7500"
  cat >"$BATS_TEST_TMPDIR/bin/brightnessctl" <<'EOF'
#!/usr/bin/env bash
echo "brightnessctl $*" >>"$STUB_LOG"
[[ $* == *-m* ]] && printf '%s\n' "$STUB_BRIGHTNESS"
exit "${STUB_BRIGHTNESSCTL_RC:-0}"
EOF
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "notify-send $*" >>"$STUB_LOG"\nprintf 77\n' \
    >"$BATS_TEST_TMPDIR/bin/notify-send"
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

# A PATH holding only what the script needs before its own `command -v` guard runs --
# bash for the `env bash` shebang included -- so "not installed" means it, rather than
# falling through to the real binary that happens to be on this machine.
path_without_tools() {
  local dir="$BATS_TEST_TMPDIR/nobin" tool
  mkdir -p "$dir"
  for tool in bash realpath dirname; do
    ln -sf "$(command -v "$tool")" "$dir/$tool"
  done
  echo "$dir"
}

@test "up raises the backlight" {
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --regexp "brightnessctl .*set [0-9]+%\\+"
}

@test "down lowers it, with a floor so the screen never goes black" {
  # `set 5%-` at 3% lands on 0 and the panel is unusable with no way to see the way
  # back. A minimum keeps the screen readable.
  #
  # The floor must be passed attached (--min-value=N or -nN), never as `-n N`: the
  # short option's argument is optional, so a separated value is read as the
  # operation, brightnessctl falls back to `info` and exits 0 having changed nothing.
  # An earlier version shipped `-n 5` and silently did not work.
  run "$SCRIPT" down
  assert_success
  run calls
  assert_output --regexp "brightnessctl .*set [0-9]+%-"
  assert_output --regexp "(--min-value=[0-9]+|-n[0-9]+)"
  refute_output --regexp "\-n [0-9]"
}

@test "the OSD shows the level, read back from brightnessctl -m" {
  STUB_BRIGHTNESS="intel_backlight,backlight,5000,72%,7500" run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "72%"
}

@test "the OSD carries the level as a progress value too" {
  STUB_BRIGHTNESS="intel_backlight,backlight,5000,72%,7500" run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "int:value:72"
}

@test "a step can be given" {
  run "$SCRIPT" up 10
  assert_success
  run calls
  assert_output --partial "10%+"
}

@test "an unknown verb is a usage error, and changes nothing" {
  run "$SCRIPT" brighter
  assert_failure
  assert_output --partial "usage"
  run calls
  refute_output --partial "set "
}

@test "no verb at all is a usage error" {
  run "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "with no brightnessctl it says so rather than failing silently" {
  # Confirmed absent on the dev seat before this phase; a machine that never
  # installed it should get a sentence, not a stack trace.
  PATH="$(path_without_tools)" run "$SCRIPT" up
  assert_failure
  assert_output --partial "brightnessctl"
}

@test "a brightnessctl that fails is reported, not swallowed" {
  STUB_BRIGHTNESSCTL_RC=1 run "$SCRIPT" up
  assert_failure
}
