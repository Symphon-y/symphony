#!/usr/bin/env bats
# Unit tests for the live ISO's root login profile: on tty1 it starts the GUI
# installer under cage -- unless the kernel command line says autarchy.nogui, the way
# to a plain terminal on tty1 (cage has no VT switching, D-0066, so there is no other).
# tty and cage are stubbed on PATH; nothing real starts.

setup() {
  load '../helpers/common'
  PROFILE="$REPO_ROOT/iso/profile/airootfs/root/.bash_profile"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "${STUB_TTY:-/dev/tty1}"\n' >"$bin/tty"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "cage $*" >>"$STUB_LOG"\n' >"$bin/cage"
  chmod +x "$bin/tty" "$bin/cage"
  PATH="$bin:$PATH"
  export AUTARCHY_CMDLINE_FILE="$BATS_TEST_TMPDIR/cmdline"
}

# The profile is sourced by a login shell; run it the same way.
login() {
  run bash -c "source '$PROFILE'"
}

@test "tty1 starts the GUI installer under cage on a normal boot" {
  echo "BOOT_IMAGE=/arch/boot/x86_64/vmlinuz-linux archisobasedir=arch quiet" >"$AUTARCHY_CMDLINE_FILE"
  login
  run cat "$STUB_LOG"
  assert_output --partial "cage -- /root/autarchy/gui/autarchy-installer"
}

@test "autarchy.nogui on the kernel command line skips the GUI and leaves a terminal" {
  echo "BOOT_IMAGE=/arch/boot/x86_64/vmlinuz-linux archisobasedir=arch autarchy.nogui" >"$AUTARCHY_CMDLINE_FILE"
  login
  assert_success
  run cat "$STUB_LOG"
  assert_output ""
  # ...and the login banner still says what to do.
  run bash -c "source '$PROFILE'"
  assert_output --partial "autarchy-install"
}

@test "only the exact word disables it, not a lookalike" {
  echo "autarchy.nogui-not autarchy.nogui.x" >"$AUTARCHY_CMDLINE_FILE"
  login
  run cat "$STUB_LOG"
  assert_output --partial "cage --"
}

@test "other terminals never start the GUI" {
  echo "quiet" >"$AUTARCHY_CMDLINE_FILE"
  STUB_TTY=/dev/tty2 login
  run cat "$STUB_LOG"
  assert_output ""
}

@test "the banner says how to get a terminal on tty1 for diagnosing" {
  run grep -F 'autarchy.nogui' "$PROFILE"
  assert_success
}
