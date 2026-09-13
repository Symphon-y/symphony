#!/usr/bin/env bats
# Unit tests for install/sync-system, which copies root-owned files listed in
# system/files.txt into a root filesystem.
#
# Runs against a fake root in a temp directory. visudo and id are stubbed so the
# tests control sudoers validation and whether the script believes it is root.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/sync-system"
  ROOT="$BATS_TEST_TMPDIR/root"
  mkdir -p "$ROOT"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\n%s\n' 'echo "visudo $*" >>"$STUB_LOG"; exit "${STUB_VISUDO_RC:-0}"' >"$bin/visudo"
  printf '#!/usr/bin/env bash\n%s\n' 'if [[ ${1:-} == -u ]]; then echo "${STUB_UID:-1000}"; else exec /usr/bin/id "$@"; fi' >"$bin/id"
  chmod +x "$bin/visudo" "$bin/id"
  PATH="$bin:$PATH"
}

# Manifest entries as "mode source target" lines.
manifest_entries() {
  grep -Ev '^[[:space:]]*(#|$)' "$REPO_ROOT/system/files.txt"
}

@test "fails with usage when no command is given" {
  run "$SCRIPT"
  assert_failure 2
  assert_output --partial "usage"
}

@test "check reports every manifest file as missing on an empty root" {
  run "$SCRIPT" --root "$ROOT" check
  assert_failure 1
  assert_line "missing: /etc/nftables.conf"
  assert_line "missing: /efi/loader/loader.conf"
}

@test "apply installs every manifest file with its content and mode" {
  run "$SCRIPT" --root "$ROOT" apply
  assert_success

  local mode source target
  while read -r mode source target; do
    run cmp "$REPO_ROOT/system/$source" "$ROOT$target"
    assert_success
    run find "$ROOT$target" -perm "$mode"
    assert_output "$ROOT$target"
  done < <(manifest_entries)
}

@test "check passes right after apply" {
  "$SCRIPT" --root "$ROOT" apply
  run "$SCRIPT" --root "$ROOT" check
  assert_success
  assert_output --partial "in sync"
}

@test "check reports content drift" {
  "$SCRIPT" --root "$ROOT" apply
  echo "# edited by hand" >>"$ROOT/etc/nftables.conf"
  run "$SCRIPT" --root "$ROOT" check
  assert_failure 1
  assert_line "content: /etc/nftables.conf"
}

@test "check reports mode drift" {
  "$SCRIPT" --root "$ROOT" apply
  chmod 0666 "$ROOT/etc/nftables.conf"
  run "$SCRIPT" --root "$ROOT" check
  assert_failure 1
  assert_line "mode: /etc/nftables.conf"
}

@test "check run as root reports files not owned by root" {
  "$SCRIPT" --root "$ROOT" apply
  export STUB_UID=0
  run "$SCRIPT" --root "$ROOT" check
  assert_failure 1
  assert_line "owner: /etc/nftables.conf"
}

@test "apply rewrites only the files that changed" {
  "$SCRIPT" --root "$ROOT" apply
  echo "# edited by hand" >>"$ROOT/etc/nftables.conf"
  run "$SCRIPT" --root "$ROOT" apply
  assert_success
  assert_line "updated: /etc/nftables.conf"
  refute_line "updated: /etc/systemd/zram-generator.conf"
  run cmp "$REPO_ROOT/system/nftables/nftables.conf" "$ROOT/etc/nftables.conf"
  assert_success
}

@test "apply validates sudoers files with visudo before installing" {
  run "$SCRIPT" --root "$ROOT" apply
  assert_success
  run cat "$STUB_LOG"
  assert_line "visudo -cf $REPO_ROOT/system/sudo/10-wheel"
}

@test "apply refuses invalid sudoers and changes nothing" {
  export STUB_VISUDO_RC=1
  run "$SCRIPT" --root "$ROOT" apply
  assert_failure 1
  assert_output --partial "sudoers"
  run find "$ROOT" -type f
  assert_output ""
}

@test "apply to the live root requires root" {
  export STUB_UID=1000
  run "$SCRIPT" apply
  assert_failure 1
  assert_output --partial "root"
}
