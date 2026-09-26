#!/usr/bin/env bats
# Unit tests for scripts/lib/osd.bash: one on-screen display, replaced in place rather
# than stacked (Phase 21). Holding a volume key fires the OSD many times a second; a
# desktop shows one bar that moves, not forty toasts.
#
# mako documents neither x-canonical-private-synchronous nor a `synchronous` criterion,
# so replacement goes through what it does document: notify-send -p prints the new
# notification's id, and -r replaces that id next time.

# Each @test runs in its own subshell, so per-test state is intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYMPHONY_STATE="$HOME/.local/state/symphony"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$SYMPHONY_STATE" "$BATS_TEST_TMPDIR/bin"
  : >"$STUB_LOG"
  # notify-send -p prints the id of the notification it just raised.
  cat >"$BATS_TEST_TMPDIR/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
echo "notify-send $*" >>"$STUB_LOG"
printf '%s' "${STUB_NOTIFY_ID:-77}"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/notify-send"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck source-path=SCRIPTDIR source=../../scripts/lib/osd.bash
  source "$REPO_ROOT/scripts/lib/osd.bash"
}

calls() {
  cat "$STUB_LOG"
}

@test "raises a notification with the summary and body" {
  osd_show "Volume" "40%"
  run calls
  assert_output --partial "Volume"
  assert_output --partial "40%"
}

@test "tags itself as symphony, so mako can style it" {
  osd_show "Volume" "40%"
  run calls
  assert_output --regexp "(-a|--app-name)[= ]symphony"
}

@test "a percentage becomes a progress bar mako can draw" {
  osd_show "Volume" "40%" 40
  run calls
  assert_output --partial "int:value:40"
}

@test "no percentage means no progress hint" {
  osd_show "Player" "Paused"
  run calls
  refute_output --partial "int:value"
}

@test "the first OSD replaces nothing" {
  osd_show "Volume" "40%"
  run calls
  assert_output --regexp "(-r|--replace-id)[= ]0"
}

@test "the next OSD replaces the one before it, instead of stacking" {
  STUB_NOTIFY_ID=123 osd_show "Volume" "40%"
  : >"$STUB_LOG"
  osd_show "Volume" "45%"
  run calls
  assert_output --regexp "(-r|--replace-id)[= ]123"
}

@test "it sets its own short lifetime, not mako's 30s update-toast default" {
  # The update offer and the OSD share the app-name symphony, and that mako section
  # sets default-timeout=30000 -- which would leave a volume bar on screen for half a
  # minute. An explicit expire-time wins over a default.
  osd_show "Volume" "40%"
  run calls
  assert_output --regexp "(-t|--expire-time)[= ][0-9]{3,4}( |$)"
}

@test "with no notify-send installed it is silent, and not a failure" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  PATH="$BATS_TEST_TMPDIR/empty" run osd_show "Volume" "40%"
  assert_success
}

@test "a notify-send that fails does not take the caller down with it" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/notify-send"
  chmod +x "$BATS_TEST_TMPDIR/bin/notify-send"
  run osd_show "Volume" "40%"
  assert_success
}
