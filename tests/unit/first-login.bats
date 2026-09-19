#!/usr/bin/env bats
# Unit tests for install/first-login. The real install/enable-user-services
# needs a live user D-Bus/systemd session (systemctl --user) that doesn't
# exist in this sandbox, so it's swapped out via AUTARCHY_ENABLE_USER_SERVICES_SCRIPT
# for a stub that just logs its own invocation.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/first-login"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export AUTARCHY_FIRST_LOGIN_MARKER="$BATS_TEST_TMPDIR/state/first-login-done"
  export AUTARCHY_ENABLE_USER_SERVICES_SCRIPT="$BATS_TEST_TMPDIR/enable-user-services-stub"
  cat >"$AUTARCHY_ENABLE_USER_SERVICES_SCRIPT" <<EOF
#!/usr/bin/env bash
echo "enable-user-services \$*" >>"$STUB_LOG"
EOF
  chmod +x "$AUTARCHY_ENABLE_USER_SERVICES_SCRIPT"
}

calls() {
  cat "$STUB_LOG"
}

@test "first run: calls enable-user-services apply and creates the marker" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "enable-user-services apply"
  assert [ -e "$AUTARCHY_FIRST_LOGIN_MARKER" ]
}

@test "second run: the marker already exists, so it's a no-op" {
  mkdir -p "$(dirname "$AUTARCHY_FIRST_LOGIN_MARKER")"
  touch "$AUTARCHY_FIRST_LOGIN_MARKER"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}
