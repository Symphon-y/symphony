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
    # "-" marks a filesystem without per-file permissions (the vfat ESP).
    if [[ $mode != - ]]; then
      run find "$ROOT$target" -perm "$mode"
      assert_output "$ROOT$target"
    fi
  done < <(manifest_entries)
}

@test "check ignores the mode of files marked '-' (the ESP has no Unix permissions)" {
  "$SCRIPT" --root "$ROOT" apply
  # On a vfat ESP mounted with fmask=0077, every file reports mode 0700.
  chmod 0700 "$ROOT/efi/loader/loader.conf"
  run "$SCRIPT" --root "$ROOT" check
  assert_success
  assert_output --partial "in sync"
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
  # A non-root runner already owns the files it installed. A root runner (the CI
  # container) must hand one to an unprivileged owner. /usr/bin/id is the real id;
  # the stub on PATH answers for the script.
  if (($(/usr/bin/id -u) == 0)); then
    chown 65534 "$ROOT/etc/nftables.conf"
  fi
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

# --- machine-specific files: system/hosts/<hostname>/files.txt ------------------

# A throwaway copy of the script and system/ with one extra host, "testhost", so the
# tests never depend on (or add to) the real repository's hosts.
make_repo_copy() {
  REPO_COPY="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_COPY/install" "$REPO_COPY/scripts"
  cp "$SCRIPT" "$REPO_COPY/install/sync-system"
  cp -R "$REPO_ROOT/scripts/lib" "$REPO_COPY/scripts/"
  cp -R "$REPO_ROOT/system" "$REPO_COPY/"
  mkdir -p "$REPO_COPY/system/hosts/testhost/ssh"
  echo "ssh-ed25519 AAAAtest alice@jumphost" >"$REPO_COPY/system/hosts/testhost/ssh/authorized_keys.alice"
  printf '%s\n' '# testhost only' '0644  ssh/authorized_keys.alice  /etc/ssh/authorized_keys/alice' \
    >"$REPO_COPY/system/hosts/testhost/files.txt"
  COPY_SCRIPT="$REPO_COPY/install/sync-system"
}

set_hostname() {
  mkdir -p "$ROOT/etc"
  echo "$1" >"$ROOT/etc/hostname"
}

@test "apply installs the host's own files when the root's hostname matches" {
  make_repo_copy
  set_hostname testhost
  run "$COPY_SCRIPT" --root "$ROOT" apply
  assert_success
  assert_line "updated: /etc/ssh/authorized_keys/alice"
  run cmp "$REPO_COPY/system/hosts/testhost/ssh/authorized_keys.alice" "$ROOT/etc/ssh/authorized_keys/alice"
  assert_success
  run cmp "$REPO_COPY/system/nftables/nftables.conf" "$ROOT/etc/nftables.conf"
  assert_success
}

@test "apply ignores files that belong to other hosts" {
  make_repo_copy
  set_hostname otherhost
  run "$COPY_SCRIPT" --root "$ROOT" apply
  assert_success
  assert [ ! -e "$ROOT/etc/ssh/authorized_keys/alice" ]
  assert [ -e "$ROOT/etc/nftables.conf" ]
}

@test "without a hostname file only the base files are managed" {
  make_repo_copy
  run "$COPY_SCRIPT" --root "$ROOT" apply
  assert_success
  assert [ ! -e "$ROOT/etc/ssh/authorized_keys/alice" ]
}

@test "check reports drift in the host's own files" {
  make_repo_copy
  set_hostname testhost
  "$COPY_SCRIPT" --root "$ROOT" apply
  echo "ssh-ed25519 AAAAintruder mallory" >>"$ROOT/etc/ssh/authorized_keys/alice"
  run "$COPY_SCRIPT" --root "$ROOT" check
  assert_failure 1
  assert_line "content: /etc/ssh/authorized_keys/alice"
}

# --- --manifest FILE (Phase 19: hardware entries, symphony-hardware) ---------------

@test "--manifest FILE: installs only that manifest's entries (sources relative to system/), none of the base ones" {
  printf '0644  hardware/60-alienfx.rules  /etc/udev/rules.d/60-alienfx.rules\n' >"$BATS_TEST_TMPDIR/hw.txt"
  run "$SCRIPT" --root "$ROOT" --manifest "$BATS_TEST_TMPDIR/hw.txt" apply
  assert_success
  assert_line "updated: /etc/udev/rules.d/60-alienfx.rules"
  run cmp "$REPO_ROOT/system/hardware/60-alienfx.rules" "$ROOT/etc/udev/rules.d/60-alienfx.rules"
  assert_success
  assert [ ! -e "$ROOT/etc/nftables.conf" ]
}

@test "--manifest FILE: check reports that manifest's drift, and passes after apply" {
  printf '0644  hardware/60-alienfx.rules  /etc/udev/rules.d/60-alienfx.rules\n' >"$BATS_TEST_TMPDIR/hw.txt"
  run "$SCRIPT" --root "$ROOT" --manifest "$BATS_TEST_TMPDIR/hw.txt" check
  assert_failure
  assert_output --partial "60-alienfx.rules"
  "$SCRIPT" --root "$ROOT" --manifest "$BATS_TEST_TMPDIR/hw.txt" apply >/dev/null
  run "$SCRIPT" --root "$ROOT" --manifest "$BATS_TEST_TMPDIR/hw.txt" check
  assert_success
}

@test "--manifest with a file that does not exist is a usage error" {
  run "$SCRIPT" --root "$ROOT" --manifest "$BATS_TEST_TMPDIR/nope.txt" apply
  assert_failure
  assert_output --partial "nope.txt"
}
