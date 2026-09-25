#!/usr/bin/env bats
# Unit tests for home/update/dot-local/bin/update-now: the one foreground entry point that
# applies what is pending (Phase 20). Run in a terminal so sudo can prompt and a long
# operation is visible. sudo, pacman, symphony-update and update-check are stubs on PATH.
#
# The order is the substance here: pacman -Syu first, because the release's own
# install-packages runs `yay -S --needed` without -u and a stale db is how a partial
# upgrade happens. And the release must not run if the upgrade failed.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/update/dot-local/bin/update-now"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export SYMPHONY_STATE="$BATS_TEST_TMPDIR/state"
  STATE="$SYMPHONY_STATE/updates"
  mkdir -p "$SYMPHONY_STATE"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin" tool
  mkdir -p "$bin"
  # ${*:+ $*} keeps a no-argument call from logging a trailing space, so a test can
  # assert the exact line it expects.
  for tool in pacman symphony-update update-check; do
    printf '#!/usr/bin/env bash\necho "%s${*:+ $*}" >>"$STUB_LOG"\nexit "${STUB_%s_RC:-0}"\n' \
      "$tool" "$(tr 'a-z-' 'A-Z_' <<<"$tool")" >"$bin/$tool"
  done
  cat >"$bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >>"$STUB_LOG"
exec "$@"
EOF
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

state() {
  printf '%s\n' "$@" >"$STATE"
}

calls() {
  cat "$STUB_LOG"
}

@test "nothing pending: says so, changes nothing, exits 0" {
  state "packages=0" "pkglist=" "release=" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  assert_output --partial "up to date"
  run calls
  refute_output --partial "pacman"
  refute_output --partial "symphony-update"
}

@test "packages pending: pacman -Syu, through sudo" {
  state "packages=2" "pkglist=linux vim" "release=" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_line --regexp "^sudo pacman -Syu"
}

@test "a release pending: symphony-update apply" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_line --regexp "^symphony-update apply"
}

@test "both pending: packages first, then the release -- never the other way round" {
  state "packages=2" "pkglist=linux vim" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  local pac rel
  pac=$(grep -n 'pacman -Syu' "$STUB_LOG" | cut -d: -f1 | head -1)
  rel=$(grep -n 'symphony-update apply' "$STUB_LOG" | cut -d: -f1 | head -1)
  assert [ "$pac" -lt "$rel" ]
}

@test "a failed upgrade stops there: the release is never applied on top of it" {
  state "packages=2" "pkglist=linux vim" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  STUB_PACMAN_RC=1 run "$SCRIPT"
  assert_failure
  run calls
  refute_output --partial "symphony-update apply"
}

@test "a failed upgrade says what went wrong, rather than exiting quietly" {
  state "packages=1" "pkglist=linux" "release=" "installed=2026.09.24" "checked=1790000000"
  STUB_PACMAN_RC=1 run "$SCRIPT"
  assert_failure
  assert_output --partial "pacman"
}

@test "the state is refreshed at the end, so the badge clears" {
  state "packages=1" "pkglist=linux" "release=" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "update-check"
}

@test "a failed release apply is reported and fails the run" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  STUB_SYMPHONY_UPDATE_RC=1 run "$SCRIPT"
  assert_failure
}

@test "it says what it is about to do before doing it" {
  state "packages=2" "pkglist=linux vim" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  assert_output --partial "2026.09.25"
  assert_output --partial "2"
}

@test "no state file: it checks first rather than assuming nothing is pending" {
  rm -f "$STATE"
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "update-check"
}
