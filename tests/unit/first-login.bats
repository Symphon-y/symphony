#!/usr/bin/env bats
# Unit tests for install/first-login. The real install/enable-user-services
# needs a live user D-Bus/systemd session (systemctl --user) that doesn't
# exist in this sandbox, and matugen needs a real palette source, so both are
# swapped out (SYMPHONY_ENABLE_USER_SERVICES_SCRIPT, SYMPHONY_MATUGEN) for
# stubs that just log their own invocation.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/first-login"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export SYMPHONY_FIRST_LOGIN_MARKER="$BATS_TEST_TMPDIR/state/first-login-done"
  export SYMPHONY_ENABLE_USER_SERVICES_SCRIPT="$BATS_TEST_TMPDIR/enable-user-services-stub"
  export SYMPHONY_MATUGEN="$BATS_TEST_TMPDIR/matugen-stub"
  export SYMPHONY_FIRST_LOGIN_VERIFY_DELAY=0
  cat >"$SYMPHONY_ENABLE_USER_SERVICES_SCRIPT" <<EOF
#!/usr/bin/env bash
echo "enable-user-services \$*" >>"$STUB_LOG"
if [[ \${1:-} == check ]]; then
  [[ -n \${STUB_CHECK_FAIL:-} ]] && exit 1
  # Fail the first STUB_CHECK_FAIL_COUNT checks (this call is already logged above).
  if [[ -n \${STUB_CHECK_FAIL_COUNT:-} ]]; then
    n=\$(grep -c '^enable-user-services check\$' "$STUB_LOG")
    ((n <= STUB_CHECK_FAIL_COUNT)) && exit 1
  fi
fi
exit 0
EOF
  cat >"$SYMPHONY_MATUGEN" <<EOF
#!/usr/bin/env bash
echo "matugen \$*" >>"$STUB_LOG"
[[ -n \${STUB_MATUGEN_FAIL:-} ]] && exit 1
exit 0
EOF
  chmod +x "$SYMPHONY_ENABLE_USER_SERVICES_SCRIPT" "$SYMPHONY_MATUGEN"
}

calls() {
  cat "$STUB_LOG"
}

@test "first run: calls enable-user-services apply and creates the marker" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "enable-user-services apply"
  assert [ -e "$SYMPHONY_FIRST_LOGIN_MARKER" ]
}

@test "first run: renders the theme from the current wallpaper before any service starts (Phase 16)" {
  # Nothing else renders it on a fresh install: waybar's style.css imports
  # colors.css, which only matugen writes -- so it has to exist before the
  # bar (and mako, hyprlock, ...) come up.
  run "$SCRIPT"
  assert_success
  run calls
  assert_line --index 0 "matugen --config $HOME/.config/matugen/config.toml image $HOME/.local/share/backgrounds/current.png --source-color-index 0"
  assert_line --index 1 "enable-user-services apply"
}

@test "first run: verifies the services actually came up before writing the marker (Phase 16)" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line --index 2 "enable-user-services check"
}

@test "first run: no marker when the services never come up, so the next login retries" {
  STUB_CHECK_FAIL=1 run "$SCRIPT"
  assert_failure
  assert [ ! -e "$SYMPHONY_FIRST_LOGIN_MARKER" ]
  # Retried a few times first, not given up on at the first failed check.
  run grep -c '^enable-user-services check$' "$STUB_LOG"
  assert_output "5"
}

@test "first run: tolerates a check that fails at first while units are still settling" {
  # Fails the first two checks, then passes: still succeeds and writes the marker.
  STUB_CHECK_FAIL_COUNT=2 run "$SCRIPT"
  assert_success
  assert [ -e "$SYMPHONY_FIRST_LOGIN_MARKER" ]
}

@test "first run: no marker when the theme render fails, so the next login retries" {
  STUB_MATUGEN_FAIL=1 run "$SCRIPT"
  assert_failure
  assert [ ! -e "$SYMPHONY_FIRST_LOGIN_MARKER" ]
}

@test "first run: enables this machine's hardware user units after the services (Phase 19), and a failure there does not block the marker" {
  printf '#!/usr/bin/env bash\necho "symphony-hardware $*" >>"$STUB_LOG"\nexit "${STUB_HW_RC:-0}"\n' >"$BATS_TEST_TMPDIR/hardware-stub"
  chmod +x "$BATS_TEST_TMPDIR/hardware-stub"
  export SYMPHONY_HARDWARE_SCRIPT="$BATS_TEST_TMPDIR/hardware-stub"
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "symphony-hardware apply --user-only"
  assert [ -e "$SYMPHONY_FIRST_LOGIN_MARKER" ]
  rm "$SYMPHONY_FIRST_LOGIN_MARKER"
  STUB_HW_RC=1 run "$SCRIPT"
  assert_success
  assert [ -e "$SYMPHONY_FIRST_LOGIN_MARKER" ]
}

@test "second run: the marker already exists, so it's a no-op" {
  mkdir -p "$(dirname "$SYMPHONY_FIRST_LOGIN_MARKER")"
  touch "$SYMPHONY_FIRST_LOGIN_MARKER"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}
