#!/usr/bin/env bats
# Unit tests for home/media/dot-local/bin/player (Phase 21): the media-player role.
# playerctl and notify-send are stubs on PATH.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/media/dot-local/bin/player"
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYMPHONY_STATE="$HOME/.local/state/symphony"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$SYMPHONY_STATE" "$BATS_TEST_TMPDIR/bin"
  : >"$STUB_LOG"
  export STUB_STATUS=Playing STUB_META="Miles Davis - So What"
  cat >"$BATS_TEST_TMPDIR/bin/playerctl" <<'EOF'
#!/usr/bin/env bash
echo "playerctl $*" >>"$STUB_LOG"
[[ -n ${STUB_NO_PLAYER:-} ]] && { echo "No players found" >&2; exit 1; }
[[ $1 == status ]] && printf '%s\n' "$STUB_STATUS"
[[ $1 == metadata ]] && printf '%s\n' "$STUB_META"
exit 0
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

@test "play-pause toggles, so one key does both" {
  run "$SCRIPT" play-pause
  assert_success
  run calls
  assert_line "playerctl play-pause"
}

@test "next and previous move tracks" {
  run "$SCRIPT" next
  assert_success
  run "$SCRIPT" previous
  assert_success
  run calls
  assert_line "playerctl next"
  assert_line "playerctl previous"
}

@test "the OSD names what is playing" {
  run "$SCRIPT" next
  assert_success
  run calls
  assert_output --partial "Miles Davis - So What"
}

@test "the OSD has no progress bar: a track is not a percentage" {
  run "$SCRIPT" next
  assert_success
  run calls
  refute_output --partial "int:value"
}

@test "with no player running it says so and does not fail the keypress" {
  # A media key pressed with nothing playing is an everyday event, not an error.
  STUB_NO_PLAYER=1 run "$SCRIPT" play-pause
  assert_success
  run calls
  assert_output --regexp "notify-send .*([Nn]o player|[Nn]othing)"
}

@test "an unknown verb is a usage error, and controls nothing" {
  run "$SCRIPT" rewind
  assert_failure
  assert_output --partial "usage"
  run calls
  refute_output --partial "playerctl play"
}

@test "no verb at all is a usage error" {
  run "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "with no playerctl installed it says so" {
  PATH="$(path_without_tools)" run "$SCRIPT" next
  assert_failure
  assert_output --partial "playerctl"
}
