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

@test "apply keeps enabling the remaining units when one fails, then exits non-zero (Phase 16)" {
  # Under set -e the first failing unit used to abort the loop, silently
  # leaving every later unit (waybar, cliphist, ...) never enabled.
  STUB_FAIL_ENABLE="mako.service" run "$SCRIPT" apply
  assert_failure
  assert_output --partial "failed: mako.service"
  run cat "$STUB_LOG"
  assert_line "systemctl --user enable --now cliphist.service"
}
