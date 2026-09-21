#!/usr/bin/env bats
# Unit tests for home/network/dot-local/bin/network-menu. Everything it launches is
# stubbed on PATH, so nothing real opens.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/network/dot-local/bin/network-menu"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  local tool
  for tool in network-picker networkmanager_dmenu nm-connection-editor; do
    # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
    printf '#!/usr/bin/env bash\necho "${0##*/}${*:+ $*}" >>"$STUB_LOG"\n' >"$BIN/$tool"
  done
  # nmcli answers the profile snapshot; network-watch records the snapshot it is handed.
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "nmcli $*" >>"$STUB_LOG"\nprintf "u-1\nu-2\n"\n' >"$BIN/nmcli"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\necho "network-watch [$(tr "\n" " " </dev/stdin)]" >>"$STUB_LOG"\n' >"$BIN/network-watch"
  chmod +x "$BIN"/*
  PATH="$BIN:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "with no argument: snapshots the saved profiles, opens the picker, then watches the outcome" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line --index 0 "nmcli -t -f UUID connection show"
  assert_line --index 1 "network-picker"
  assert_line --index 2 "network-watch [u-1 u-2 ]"
  # The upstream picker is reached only through network-picker (D-0077); it is
  # stubbed here so a regression can't open the real one mid-test.
  refute_line "networkmanager_dmenu"
}

@test "'edit' opens the full network settings (nm-connection-editor), with no watcher" {
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

@test "the exit status of the picker is passed through, and it is still watched" {
  printf '#!/usr/bin/env bash\nexit 7\n' >"$BIN/network-picker"
  run "$SCRIPT"
  assert_failure 7
  run calls
  assert_output --partial "network-watch"
}

@test "if the profiles cannot be listed, the picker still opens but nothing is watched (an empty snapshot would make every saved profile look new)" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$BIN/nmcli"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output "network-picker"
}
