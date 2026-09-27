#!/usr/bin/env bats
# Unit tests for scripts/lib/lighting.bash: asking for a repaint.
#
# The reason this exists: the painter writes to a USB device, and running two at once
# wedges the controller. `alienfx --theme` that cannot claim the device spins forever in
# _wait_controller_ready, having already issued a reset -- which is what made the keys
# flash and the colour never land, 25 processes deep. So a caller never runs the painter;
# it asks systemd to restart the unit that owns it, and returns immediately.
#
# systemctl and alienfx-theme are stubs on PATH.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
  : >"$STUB_LOG"
  cat >"$BATS_TEST_TMPDIR/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >>"$STUB_LOG"
exit "${STUB_SYSTEMCTL_RC:-0}"
EOF
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "alienfx-theme${*:+ $*}" >>"$STUB_LOG"\nexit "${STUB_THEME_RC:-0}"\n' \
    >"$BATS_TEST_TMPDIR/bin/alienfx-theme"
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck source-path=SCRIPTDIR source=../../scripts/lib/lighting.bash
  source "$REPO_ROOT/scripts/lib/lighting.bash"
}

calls() {
  cat "$STUB_LOG"
}

@test "it asks systemd to restart the unit that owns the painter" {
  run lighting_repaint
  assert_success
  run calls
  assert_output --partial "restart alienfx-theme.service"
}

@test "it does not wait for the paint: the OSD must not lag behind a USB write" {
  run lighting_repaint
  assert_success
  run calls
  assert_output --partial "--no-block"
}

@test "it never starts a painter itself when systemd answered" {
  # Two painters at once is the whole bug: the loser spins forever on the device.
  run lighting_repaint
  assert_success
  # Per line: "alienfx-theme" is a substring of the unit name systemctl was given.
  run bash -c "grep -c '^alienfx-theme' '$STUB_LOG' || true"
  assert_output "0"
}

@test "with no session (a chroot, a TTY, first-login) it paints here instead" {
  STUB_SYSTEMCTL_RC=1 run lighting_repaint
  assert_success
  run calls
  assert_line "alienfx-theme"
}

@test "with no painter installed at all it is silent and successful" {
  # A PATH that genuinely lacks it: this machine has a real alienfx-theme, so removing
  # the stub alone would fall through to it.
  mkdir -p "$BATS_TEST_TMPDIR/nobin"
  PATH="$BATS_TEST_TMPDIR/nobin" run lighting_repaint
  assert_success
  run calls
  assert_output ""
}

@test "a failing fallback never fails the caller: lighting is not worth a keypress" {
  STUB_SYSTEMCTL_RC=1 STUB_THEME_RC=1 run lighting_repaint
  assert_success
}

@test "it restarts rather than starts, so a running painter is replaced not queued" {
  # `start` on an already-running oneshot is a no-op, which would drop the new level.
  run lighting_repaint
  assert_success
  run calls
  assert_output --regexp "systemctl .*restart"
  refute_output --regexp "systemctl .*(^| )start "
}
