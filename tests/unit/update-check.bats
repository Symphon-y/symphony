#!/usr/bin/env bats
# Unit tests for home/update/dot-local/bin/update-check: the one place that decides what
# is pending (Phase 20). It is the only script in the set that touches the network, and it
# only ever writes the state file -- never a notification, never an upgrade.
#
# checkupdates, curl and notify-send are stubs on PATH.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/update/dot-local/bin/update-check"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export SYMPHONY_PAYLOAD_ROOT="$BATS_TEST_TMPDIR/payload"
  export SYMPHONY_STATE="$BATS_TEST_TMPDIR/state"
  export SYMPHONY_RELEASE_REPO="example/symphony"
  STATE="$SYMPHONY_STATE/updates"
  mkdir -p "$SYMPHONY_PAYLOAD_ROOT/current"
  echo "2026.09.01" >"$SYMPHONY_PAYLOAD_ROOT/current/VERSION"
  export STUB_CHECKUPDATES_RC=2 STUB_CHECKUPDATES_OUT="" STUB_LATEST=2026.09.01
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\necho "checkupdates $*" >>"$STUB_LOG"\nprintf "%%s" "$STUB_CHECKUPDATES_OUT"\nexit "$STUB_CHECKUPDATES_RC"\n' >"$bin/checkupdates"
  cat >"$bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >>"$STUB_LOG"
[[ -n ${STUB_CURL_FAIL:-} ]] && exit 7
printf '%s\n' "${STUB_CURL_BODY-$(printf '{"tag_name": "%s"}' "$STUB_LATEST")}"
EOF
  printf '#!/usr/bin/env bash\necho "notify-send $*" >>"$STUB_LOG"\n' >"$bin/notify-send"
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

# The value of KEY in the state file, or empty.
field() {
  sed -n "s/^$1=//p" "$STATE"
}

@test "writes the state file, creating its directory on a machine that has never checked" {
  run "$SCRIPT"
  assert_success
  assert [ -f "$STATE" ]
}

@test "records the pending packages: how many, and which" {
  STUB_CHECKUPDATES_RC=0 STUB_CHECKUPDATES_OUT=$'linux 1 -> 2\nvim 8 -> 9\n' run "$SCRIPT"
  assert_success
  run field packages
  assert_output "2"
  run field pkglist
  assert_output "linux vim"
}

@test "nothing pending is recorded as nothing, not as an absent file" {
  run "$SCRIPT"
  assert_success
  run field packages
  assert_output "0"
  run field pkglist
  assert_output ""
}

@test "records a newer release, and the version installed now" {
  STUB_LATEST=2026.09.22 run "$SCRIPT"
  assert_success
  run field release
  assert_output "2026.09.22"
  run field installed
  assert_output "2026.09.01"
}

@test "a release equal to or older than the installed one is not pending" {
  STUB_LATEST=2026.08.01 run "$SCRIPT"
  assert_success
  run field release
  assert_output ""
}

@test "a local-* payload (the dev seat) is never told a release supersedes it" {
  echo "local-abc1234" >"$SYMPHONY_PAYLOAD_ROOT/current/VERSION"
  STUB_LATEST=2026.09.22 run "$SCRIPT"
  assert_success
  run field release
  assert_output ""
}

@test "a local-* payload still gets its packages counted" {
  echo "local-abc1234" >"$SYMPHONY_PAYLOAD_ROOT/current/VERSION"
  STUB_CHECKUPDATES_RC=0 STUB_CHECKUPDATES_OUT=$'linux 1 -> 2\n' run "$SCRIPT"
  assert_success
  run field packages
  assert_output "1"
}

@test "offline: the release already known stays known, rather than reading as 'nothing pending'" {
  STUB_LATEST=2026.09.22 "$SCRIPT"
  STUB_CURL_FAIL=1 run "$SCRIPT"
  assert_success
  run field release
  assert_output "2026.09.22"
}

@test "offline: the packages already known stay known" {
  STUB_CHECKUPDATES_RC=0 STUB_CHECKUPDATES_OUT=$'linux 1 -> 2\n' "$SCRIPT"
  STUB_CHECKUPDATES_RC=1 STUB_CHECKUPDATES_OUT="" run "$SCRIPT"
  assert_success
  run field packages
  assert_output "1"
}

@test "a malformed API answer is not a crash and claims no release" {
  STUB_CURL_BODY='<html>502 bad gateway</html>' run "$SCRIPT"
  assert_success
  run field release
  assert_output ""
}

@test "the release check has a timeout, so a hung network cannot hang the timer" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "curl .*(--max-time|-m) [0-9]+"
}

@test "it never notifies and never upgrades: that is not its job" {
  STUB_CHECKUPDATES_RC=0 STUB_CHECKUPDATES_OUT=$'linux 1 -> 2\n' STUB_LATEST=2026.09.22 run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
  refute_output --partial "pacman"
  refute_output --partial "symphony-update"
}

@test "records when it ran, so a stale answer can be told from a fresh one" {
  run "$SCRIPT"
  assert_success
  run field checked
  assert_output --regexp '^[0-9]+$'
}
