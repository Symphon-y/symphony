#!/usr/bin/env bats
# Unit tests for install/enable-user-services. systemctl is stubbed so the tests
# control enabled/active state without touching a real systemd user session.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/enable-user-services"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\n%s\n' '
    echo "systemctl $*" >>"$STUB_LOG"
    unit="${*: -1}"
    if [[ "$1 $2" == "--user is-enabled" ]]; then
      [[ " ${STUB_NOT_ENABLED:-} " == *" $unit "* ]] && exit 1 || exit 0
    fi
    if [[ "$1 $2" == "--user is-active" ]]; then
      [[ " ${STUB_NOT_ACTIVE:-} " == *" $unit "* ]] && exit 1 || exit 0
    fi
    if [[ "$1 $2" == "--user enable" ]]; then
      [[ " ${STUB_FAIL_ENABLE:-} " == *" $unit "* ]] && exit 1
    fi
    if [[ "$1 $2" == "--user try-restart" ]]; then
      [[ " ${STUB_FAIL_RESTART:-} " == *" $unit "* ]] && exit 1
    fi
    exit 0
  ' >"$bin/systemctl"
  chmod +x "$bin/systemctl"
  PATH="$bin:$PATH"
}

@test "fails with usage when no command is given" {
  run "$SCRIPT"
  assert_failure 2
  assert_output --partial "usage"
}

@test "check passes when every declared unit is enabled and active" {
  run "$SCRIPT" check
  assert_success
  assert_output --partial "enabled and active"
}

@test "check reports a unit that isn't enabled" {
  STUB_NOT_ENABLED="waybar.service" run "$SCRIPT" check
  assert_failure
  assert_output --partial "not enabled: waybar.service"
}

@test "check reports a unit that isn't active" {
  STUB_NOT_ACTIVE="mako.service" run "$SCRIPT" check
  assert_failure
  assert_output --partial "not active: mako.service"
}

@test "apply enables every declared unit" {
  run "$SCRIPT" apply
  assert_success
  run cat "$STUB_LOG"
  assert_line "systemctl --user enable --now mako.service"
  assert_line "systemctl --user enable --now cliphist.service"
}

# --- restart, so a deploy's config actually reaches the running desktop (#25) ---------
#
# `enable --now` is a no-op on a unit that is already enabled and running, so a payload
# that changes waybar's config -- or a unit file -- changed nothing on screen. That is
# how Phase 20's update badge shipped and never appeared.

@test "restart re-reads the unit files before restarting anything" {
  # Otherwise a changed unit file is missed: systemd keeps the definition it parsed at
  # boot, and `enable --now` does not re-read it either.
  run "$SCRIPT" restart
  assert_success
  run cat "$STUB_LOG"
  assert_line --index 0 "systemctl --user daemon-reload"
}

@test "restart restarts every declared unit" {
  run "$SCRIPT" restart
  assert_success
  run cat "$STUB_LOG"
  assert_line "systemctl --user try-restart mako.service"
  assert_line "systemctl --user try-restart waybar.service"
  assert_line "systemctl --user try-restart cliphist.service"
  assert_line "systemctl --user try-restart update-notify.timer"
}

@test "restart starts nothing that was not already running" {
  # try-restart, never restart or start: a unit someone stopped on purpose stays
  # stopped, and a machine with no session is left alone.
  run "$SCRIPT" restart
  assert_success
  run bash -c "grep -E 'systemctl --user (restart|start) ' '$STUB_LOG' || true"
  assert_output ""
}

@test "restart keeps going when one unit fails, then exits non-zero" {
  STUB_FAIL_RESTART="mako.service" run "$SCRIPT" restart
  assert_failure
  assert_output --partial "failed: mako.service"
  run cat "$STUB_LOG"
  assert_line "systemctl --user try-restart cliphist.service"
}

@test "restart says what it restarted, so a deploy log shows it happened" {
  run "$SCRIPT" restart
  assert_success
  assert_output --partial "restarted:"
  assert_output --partial "waybar.service"
}

@test "an unknown command is still a usage error" {
  run "$SCRIPT" reboot
  assert_failure 2
  assert_output --partial "usage"
}

@test "apply keeps enabling the remaining units when one fails, then exits non-zero (Phase 16)" {
  # Under set -e the first failing unit used to abort the loop, silently
  # leaving every later unit (waybar, cliphist, ...) never enabled.
  STUB_FAIL_ENABLE="mako.service" run "$SCRIPT" apply
  assert_failure
  assert_output --partial "failed: mako.service"
  run cat "$STUB_LOG"
  assert_line "systemctl --user enable --now cliphist.service"
}
