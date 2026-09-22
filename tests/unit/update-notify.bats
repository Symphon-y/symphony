#!/usr/bin/env bats
# Unit tests for home/update/dot-local/bin/update-notify: the daily check that
# informs about pending package updates (Phase 9, D-0059) and, since Phase 18, a
# newer autarchy release -- and never applies either. checkupdates, curl and
# notify-send are stubs on PATH.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/update/dot-local/bin/update-notify"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export AUTARCHY_PAYLOAD_ROOT="$BATS_TEST_TMPDIR/payload"
  export AUTARCHY_STATE="$BATS_TEST_TMPDIR/state"
  export AUTARCHY_RELEASE_REPO="example/autarchy"
  mkdir -p "$AUTARCHY_PAYLOAD_ROOT/current"
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
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
printf '{"tag_name": "%s"}\n' "$STUB_LATEST"
EOF
  printf '#!/usr/bin/env bash\necho "notify-send $*" >>"$STUB_LOG"\n' >"$bin/notify-send"
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "nothing pending and no new release: silent, exit 0" {
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "pending package updates: one toast naming the count (D-0059, unchanged)" {
  STUB_CHECKUPDATES_RC=0 STUB_CHECKUPDATES_OUT=$'linux 1 -> 2\nvim 1 -> 2\n' run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "2 updates available"
  refute_output --partial "pacman -Syu --noconfirm"
}

@test "a newer release: one toast naming the tag and the command to run" {
  STUB_LATEST=2026.09.22 run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "autarchy 2026.09.22 available"
  assert_output --partial "autarchy-update apply"
}

@test "the same new release on the next day: no second toast" {
  STUB_LATEST=2026.09.22 "$SCRIPT"
  : >"$STUB_LOG"
  STUB_LATEST=2026.09.22 run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "a release older than or equal to the installed one: nothing" {
  STUB_LATEST=2026.08.01 run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "a local-* payload (the dev seat) is not nagged about releases" {
  echo "local-abc1234" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  STUB_LATEST=2026.09.22 run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "the release check failing (offline) is silent and does not block the package check" {
  STUB_CURL_FAIL=1 STUB_CHECKUPDATES_RC=0 STUB_CHECKUPDATES_OUT=$'linux 1 -> 2\n' run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "1 update available"
  refute_output --partial "autarchy 2"
}

@test "the release check has a timeout, so a hung network cannot hang the timer" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "curl .*(--max-time|-m) [0-9]+"
}
