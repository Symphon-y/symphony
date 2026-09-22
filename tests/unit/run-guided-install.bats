#!/usr/bin/env bats
# Unit tests for install/run-guided-install. install-base-system and
# finish-install are both overridden via SYMPHONY_INSTALL_SCRIPT/
# SYMPHONY_FINISH_SCRIPT, mirroring install-base-system's own
# SYMPHONY_CONFIGURE_SCRIPT-style test override.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/run-guided-install"
  VARS="$BATS_TEST_TMPDIR/test.local.vars"
  : >"$VARS"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  make_stubs
}

stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1"
  chmod +x "$1"
}

# Stub bodies are single-quoted on purpose: they must expand when the stub runs, not here.
# shellcheck disable=SC2016
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  stub "$bin/install-base-system-stub" 'echo "install-base-system $*" >>"$STUB_LOG"; exit "${STUB_INSTALL_RC:-0}"'
  stub "$bin/finish-install-stub" 'echo "finish-install called" >>"$STUB_LOG"'
  export SYMPHONY_INSTALL_SCRIPT="$bin/install-base-system-stub"
  export SYMPHONY_FINISH_SCRIPT="$bin/finish-install-stub"
}

calls() {
  cat "$STUB_LOG"
}

@test "fails with usage when no vars file is given" {
  run "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "does not run finish-install when install-base-system itself fails" {
  export STUB_INSTALL_RC=1
  run "$SCRIPT" "$VARS"
  assert_failure
  run calls
  refute_output --partial "finish-install"
}

@test "--no-reboot-prompt: returns success after install, no reboot prompt, no finish-install" {
  run "$SCRIPT" --no-reboot-prompt "$VARS"
  assert_success
  assert_output --partial "Base install done."
  refute_output --partial "Reboot now?"
  run calls
  assert_line "install-base-system $VARS"
  refute_output --partial "finish-install"
}

@test "prompts to reboot and calls finish-install on yes (default)" {
  run bash -c "echo Y | \"$SCRIPT\" \"$VARS\""
  assert_success
  run calls
  assert_line "finish-install called"
}

@test "prompts to reboot and skips finish-install on no, printing the manual steps" {
  run bash -c "echo n | \"$SCRIPT\" \"$VARS\""
  assert_success
  assert_output --partial "Staying at the shell"
  run calls
  refute_output --partial "finish-install"
}
