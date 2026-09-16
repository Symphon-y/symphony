#!/usr/bin/env bats
# Unit tests for scripts/lib/identifiers.bash and scripts/check-identifiers, which keep
# network and personal identifiers (IP and MAC addresses, email addresses) out of git.
#
# Fixture identifiers are assembled at runtime from pieces, so this file never contains
# a literal one and passes the very scanner it tests.

setup() {
  load '../helpers/common'
  # shellcheck source-path=SCRIPTDIR source=../../scripts/lib/identifiers.bash
  source "$REPO_ROOT/scripts/lib/identifiers.bash"
  SCANNER="$REPO_ROOT/scripts/check-identifiers"
  FIXTURE="$BATS_TEST_TMPDIR/sample.txt"

  local octet=168
  LAN_IP="192.$octet.1.15"
  MAC="52:54:00$(printf ':%s' 59 52 7c)"
  ULA="fd$(printf c8):1e1e:9c0f:3511:5054:ff:fe59:527c"
  LINK_LOCAL="fe$(printf 80)::5054:ff:fe59:527c"
  EMAIL="someone$(printf '@')mail.test"
}

@test "finds IPv4, MAC, IPv6, and email identifiers with file and line" {
  printf '%s\n' "addr $LAN_IP/24" "link/ether $MAC" "inet6 $ULA/64" "inet6 $LINK_LOCAL/64" "author $EMAIL" >"$FIXTURE"
  run find_identifiers "$FIXTURE"
  assert_line "$FIXTURE:1: ipv4"
  assert_line "$FIXTURE:2: mac"
  assert_line "$FIXTURE:3: ipv6"
  assert_line "$FIXTURE:4: ipv6"
  assert_line "$FIXTURE:5: email"
}

@test "never prints the identifier itself" {
  printf '%s\n' "addr $LAN_IP" "link/ether $MAC" >"$FIXTURE"
  run find_identifiers "$FIXTURE"
  refute_output --partial "$LAN_IP"
  refute_output --partial "$MAC"
}

@test "allows unspecified, loopback, and documentation addresses and project emails" {
  printf '%s\n' \
    "listen 0.0.0.0:22 and 127.0.0.1:53 and ::1" \
    "docs 192.0.2.10 198.51.100.7 203.0.113.9 2001:db8::1" \
    "prefix fe80::/10 and 00:00:00:00:00:00" \
    "security@anthropic.com noreply@anthropic.com 12345+someone@users.noreply.github.com" >"$FIXTURE"
  run find_identifiers "$FIXTURE"
  assert_output ""
}

@test "allows SSH algorithm names, which look like email addresses but name nobody" {
  printf '%s\n' \
    "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com" \
    "KexAlgorithms curve25519-sha256@libssh.org,sntrup761x25519-sha512@openssh.com" >"$FIXTURE"
  run find_identifiers "$FIXTURE"
  assert_output ""
}

@test "allows systemd escaped-root-path instance units, which also look like email addresses" {
  printf '%s\n' "btrfs-scrub@-.timer" "btrfs-scrub@-.service" >"$FIXTURE"
  run find_identifiers "$FIXTURE"
  assert_output ""
}

@test "does not mistake times, dates, or version numbers for identifiers" {
  printf '%s\n' "Local time: 04:00:13" "released 2026-09-13" "Claude Code 2.1.236" \
    "OpenSSH 10.5p1" "Summer 2024: notes" "sha256 3a624a5a7cd79bbad4d32bd7" >"$FIXTURE"
  run find_identifiers "$FIXTURE"
  assert_output ""
}

@test "redact_identifiers masks identifiers and keeps the surrounding text" {
  run redact_identifiers <<<"enp1s0 UP $LAN_IP/24 $ULA/64 $LINK_LOCAL/64"
  assert_output "enp1s0 UP <ipv4>/24 <ipv6>/64 <ipv6>/64"
  run redact_identifiers <<<"link/ether $MAC brd ff:ff:ff:ff:ff:ff"
  assert_output "link/ether <mac> brd <mac>"
  run redact_identifiers <<<"Local time: Sun 2026-09-13 04:00:13 UTC"
  assert_output "Local time: Sun 2026-09-13 04:00:13 UTC"
}

@test "check-identifiers fails and lists files that contain identifiers" {
  printf '%s\n' "clean line" "addr $LAN_IP" >"$FIXTURE"
  run "$SCANNER" "$FIXTURE"
  assert_failure 1
  assert_line "$FIXTURE:2: ipv4"
  refute_output --partial "$LAN_IP"
}

@test "check-identifiers fails closed when there is no git repository to scan" {
  # A guardrail that finds nothing to check must not report success.
  local copy="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$copy/scripts/lib"
  cp "$SCANNER" "$copy/scripts/"
  cp "$REPO_ROOT/scripts/lib/identifiers.bash" "$copy/scripts/lib/"
  run "$copy/scripts/check-identifiers"
  assert_failure
  assert_output --partial "git"
}

@test "check-identifiers passes on clean files" {
  printf '%s\n' "nothing to see" "listen 0.0.0.0:22" >"$FIXTURE"
  run "$SCANNER" "$FIXTURE"
  assert_success
}
