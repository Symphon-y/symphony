#!/usr/bin/env bats
# Unit tests for install/enable-root-services. systemctl is stubbed so the tests
# control enabled/active state without touching real root-scope systemd state.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/enable-root-services"
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
    if [[ "$1" == "is-enabled" ]]; then
      [[ " ${STUB_NOT_ENABLED:-} " == *" $unit "* ]] && exit 1 || exit 0
    fi
    if [[ "$1" == "is-active" ]]; then
      [[ " ${STUB_NOT_ACTIVE:-} " == *" $unit "* ]] && exit 1 || exit 0
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
  STUB_NOT_ENABLED="reflector.timer" run "$SCRIPT" check
  assert_failure
  assert_output --partial "not enabled: reflector.timer"
}

@test "check reports a unit that isn't active" {
  STUB_NOT_ACTIVE="btrfs-scrub@-.timer" run "$SCRIPT" check
  assert_failure
  assert_output --partial "not active: btrfs-scrub@-.timer"
}

@test "apply enables every declared unit, without --user" {
  run "$SCRIPT" apply
  assert_success
  run cat "$STUB_LOG"
  assert_line "systemctl enable --now reflector.timer"
  assert_line "systemctl enable --now pacman-filesdb-refresh.timer"
  refute_output --partial "--user"
}

@test "apply --root DIR enables every declared unit inside that root, without --now (Phase 16)" {
  # Install-time use: configure-base-system runs this against the not-yet-booted
  # target, where there is no running systemd to start anything on -- enable only.
  run "$SCRIPT" apply --root /mnt
  assert_success
  run cat "$STUB_LOG"
  assert_line "systemctl --root=/mnt enable reflector.timer"
  assert_line "systemctl --root=/mnt enable btrfs-scrub@-.timer"
  assert_line "systemctl --root=/mnt enable pacman-filesdb-refresh.timer"
  refute_output --partial "--now"
}

@test "apply --root without a directory is a usage error" {
  run "$SCRIPT" apply --root
  assert_failure 2
  assert_output --partial "usage"
}
