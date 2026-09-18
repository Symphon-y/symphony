#!/usr/bin/env bats
# Unit tests for install/finish-install. umount/cryptsetup/reboot are all
# stubbed on PATH so the script never touches the real machine.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/finish-install"
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
  stub "$bin/umount" 'echo "umount $*" >>"$STUB_LOG"'
  stub "$bin/cryptsetup" 'echo "cryptsetup $*" >>"$STUB_LOG"'
  stub "$bin/sleep" 'echo "sleep $*" >>"$STUB_LOG"'
  stub "$bin/reboot" 'echo "reboot $*" >>"$STUB_LOG"'
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "unmounts, closes the encrypted volume by name from layout.conf, then reboots" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "umount -R /mnt"
  # The mapper name is layout.conf's own $LUKS_MAPPER, not hardcoded here.
  local luks_mapper
  luks_mapper=$(grep '^LUKS_MAPPER=' "$REPO_ROOT/system/storage/layout.conf" | cut -d= -f2)
  assert_line "cryptsetup close $luks_mapper"
  assert_line --partial "reboot"
}
