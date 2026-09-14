#!/usr/bin/env bats
# Unit tests for install/ssh-jump-host, which admits SSH only from one jump host. The
# jump host's address is machine-local state: the script writes it into root-owned
# files on the machine, and it never enters git.
#
# Runs a copy of the script against a throwaway repo (one host, "testhost") and a fake
# root. Addresses come from the 192.0.2.0/24 documentation range.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  REPO_COPY="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_COPY/install" "$REPO_COPY/scripts" "$REPO_COPY/system/hosts/testhost/ssh"
  cp "$REPO_ROOT/install/ssh-jump-host" "$REPO_COPY/install/" 2>/dev/null || true
  cp -R "$REPO_ROOT/scripts/lib" "$REPO_COPY/scripts/" 2>/dev/null || true
  printf '%s\n' '# alice on testhost' 'ssh-ed25519 AAAAtest alice@jumphost' '' 'ssh-ed25519 AAAAsecond alice@laptop' \
    >"$REPO_COPY/system/hosts/testhost/ssh/authorized_keys.alice"
  SCRIPT="$REPO_COPY/install/ssh-jump-host"

  ROOT="$BATS_TEST_TMPDIR/root"
  mkdir -p "$ROOT/etc"
  echo testhost >"$ROOT/etc/hostname"

  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\n%s\n' 'if [[ ${1:-} == -u ]]; then echo "${STUB_UID:-1000}"; else exec /usr/bin/id "$@"; fi' >"$bin/id"
  chmod +x "$bin/id"
  PATH="$bin:$PATH"
}

rule_lines() {
  grep -v '^#' "$ROOT/etc/nftables.d/ssh-jump-host.nft"
}

key_lines() {
  grep -v '^#' "$ROOT/etc/ssh/authorized_keys/alice"
}

@test "fails with usage when no address is given" {
  run "$SCRIPT" --root "$ROOT"
  assert_failure 2
  assert_output --partial "usage"
}

@test "rejects anything that is not a plain IPv4 address and writes nothing" {
  local bad
  for bad in not-an-ip 192.0.2 300.0.2.10 '192.0.2.10;touch' '192.0.2.10 tcp'; do
    run "$SCRIPT" --root "$ROOT" "$bad"
    assert_failure 1
  done
  run find "$ROOT" -type f ! -name hostname
  assert_output ""
}

@test "writing to the live system requires root" {
  export STUB_UID=1000
  run "$SCRIPT" 192.0.2.10
  assert_failure 1
  assert_output --partial "root"
}

@test "writes a firewall rule that admits SSH only from the address" {
  run "$SCRIPT" --root "$ROOT" 192.0.2.10
  assert_success
  run rule_lines
  assert_output "add rule inet filter input ip saddr 192.0.2.10 tcp dport 22 accept"
  run find "$ROOT/etc/nftables.d/ssh-jump-host.nft" -perm 0644
  assert_output "$ROOT/etc/nftables.d/ssh-jump-host.nft"
}

@test "installs each of the host's public keys restricted to the address" {
  run "$SCRIPT" --root "$ROOT" 192.0.2.10
  assert_success
  run key_lines
  assert_output "$(printf '%s\n' \
    'from="192.0.2.10",restrict,pty ssh-ed25519 AAAAtest alice@jumphost' \
    'from="192.0.2.10",restrict,pty ssh-ed25519 AAAAsecond alice@laptop')"
  run find "$ROOT/etc/ssh/authorized_keys/alice" -perm 0644
  assert_output "$ROOT/etc/ssh/authorized_keys/alice"
}

@test "running again with a new address replaces the old one" {
  "$SCRIPT" --root "$ROOT" 192.0.2.10
  run "$SCRIPT" --root "$ROOT" 192.0.2.20
  assert_success
  run rule_lines
  assert_output "add rule inet filter input ip saddr 192.0.2.20 tcp dport 22 accept"
  run key_lines
  refute_output --partial "192.0.2.10"
}

@test "fails when this host has no public keys in the repo" {
  echo otherhost >"$ROOT/etc/hostname"
  run "$SCRIPT" --root "$ROOT" 192.0.2.10
  assert_failure 1
  assert_output --partial "no public keys"
}

@test "refuses repo keys that carry their own options, such as a committed address" {
  printf '%s\n' 'from="192.0.2.99" ssh-ed25519 AAAAtest alice@jumphost' \
    >"$REPO_COPY/system/hosts/testhost/ssh/authorized_keys.alice"
  run "$SCRIPT" --root "$ROOT" 192.0.2.10
  assert_failure 1
  assert_output --partial "options"
}
