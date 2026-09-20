#!/usr/bin/env bats
# Unit tests for home/network/dot-local/bin/network-menu. Both tools it launches are
# stubbed on PATH, so nothing real opens.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/network/dot-local/bin/network-menu"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  local tool
  for tool in networkmanager_dmenu nm-connection-editor; do
    # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
    printf '#!/usr/bin/env bash\necho "${0##*/}${*:+ $*}" >>"$STUB_LOG"\n' >"$bin/$tool"
    chmod +x "$bin/$tool"
  done
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "with no argument, opens the network picker (networkmanager-dmenu)" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output "networkmanager_dmenu"
}

@test "'edit' opens the full network settings (nm-connection-editor)" {
  run "$SCRIPT" edit
  assert_success
  run calls
  assert_output "nm-connection-editor"
}

@test "anything else is a usage error and launches nothing" {
  run "$SCRIPT" bogus
  assert_failure 2
  assert_output --partial "usage"
  run calls
  assert_output ""
}

@test "the exit status of the launched tool is passed through" {
  printf '#!/usr/bin/env bash\nexit 7\n' >"$BATS_TEST_TMPDIR/bin/networkmanager_dmenu"
  run "$SCRIPT"
  assert_failure 7
}
