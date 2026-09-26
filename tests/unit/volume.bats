#!/usr/bin/env bats
# Unit tests for home/media/dot-local/bin/volume (Phase 21): the volume role. The
# XF86Audio* keys call it, and so will SUPER+v once prefix groups land -- hardware
# differences live here, never in a binding.
#
# wpctl and notify-send are stubs on PATH, the tests/unit/update-notify.bats pattern.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/media/dot-local/bin/volume"
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYMPHONY_STATE="$HOME/.local/state/symphony"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$SYMPHONY_STATE" "$BATS_TEST_TMPDIR/bin"
  : >"$STUB_LOG"
  export STUB_VOLUME="Volume: 0.40"
  cat >"$BATS_TEST_TMPDIR/bin/wpctl" <<'EOF'
#!/usr/bin/env bash
echo "wpctl $*" >>"$STUB_LOG"
[[ $1 == get-volume ]] && printf '%s\n' "$STUB_VOLUME"
exit "${STUB_WPCTL_RC:-0}"
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

@test "up raises the default sink" {
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --regexp "wpctl set-volume .*@DEFAULT_AUDIO_SINK@ [0-9]+%\\+"
}

@test "up is capped, so a held key cannot push past 100%" {
  # wpctl will happily go to 150% and distort; -l 1.0 is the ceiling.
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --regexp "wpctl set-volume .*(-l|--limit) 1(\\.0)? "
}

@test "down lowers the default sink" {
  run "$SCRIPT" down
  assert_success
  run calls
  assert_output --regexp "wpctl set-volume .*@DEFAULT_AUDIO_SINK@ [0-9]+%-"
}

@test "mute toggles rather than forcing a state, so one key does both ways" {
  run "$SCRIPT" mute
  assert_success
  run calls
  assert_line "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
}

@test "the OSD shows the level it ended on, read back rather than guessed" {
  STUB_VOLUME="Volume: 0.65" run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "65%"
}

@test "the OSD carries the level as a progress value too" {
  STUB_VOLUME="Volume: 0.65" run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "int:value:65"
}

@test "a muted sink says so rather than showing a level" {
  STUB_VOLUME="Volume: 0.40 [MUTED]" run "$SCRIPT" mute
  assert_success
  run calls
  assert_output --regexp "notify-send .*[Mm]uted"
}

@test "an unmuted sink does not say muted" {
  STUB_VOLUME="Volume: 0.40" run "$SCRIPT" mute
  assert_success
  run calls
  refute_output --regexp "notify-send .*[Mm]uted"
}

@test "a step can be given, for a coarser or finer key" {
  run "$SCRIPT" up 10
  assert_success
  run calls
  assert_output --partial "10%+"
}

@test "an unknown verb is a usage error, and changes nothing" {
  run "$SCRIPT" sideways
  assert_failure
  assert_output --partial "usage"
  run calls
  refute_output --partial "set-volume"
}

@test "no verb at all is a usage error" {
  run "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "with no notify-send the volume still changes: the OSD is a nicety" {
  rm "$BATS_TEST_TMPDIR/bin/notify-send"
  run "$SCRIPT" up
  assert_success
  run calls
  assert_output --partial "set-volume"
}

@test "a wpctl that fails is reported, not swallowed" {
  STUB_WPCTL_RC=1 run "$SCRIPT" up
  assert_failure
}
