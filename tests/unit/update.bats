#!/usr/bin/env bats
# Unit tests for scripts/update. git, sudo, and snapper are stubbed; the five
# appliers it calls are overridden via AUTARCHY_* env vars to stub
# executables, the same override pattern install-base-system.bats uses for
# configure-base-system.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/update"
  export AUTARCHY_STATE="$BATS_TEST_TMPDIR/state"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export STUB_TAGS=$'2026.09.16\n2026.09.01'
  export STUB_BRANCH=main
  export STUB_PORCELAIN=""
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1"
  chmod +x "$1"
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"

  cat >"$bin/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >>"$STUB_LOG"
[[ $1 == -C ]] && shift 2
case "$1" in
  fetch) exit 0 ;;
  tag) printf '%s\n' "$STUB_TAGS" ;;
  diff) echo "(diff stat)" ;;
  status) [[ -n $STUB_PORCELAIN ]] && printf '%s\n' "$STUB_PORCELAIN" ;;
  rev-parse) echo "$STUB_BRANCH" ;;
  checkout | pull) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$bin/git"

  stub "$bin/sudo" 'echo "sudo $*" >>"$STUB_LOG"; shift 0; "$@"'
  stub "$bin/snapper" 'echo "snapper $*" >>"$STUB_LOG"'

  for name in install-packages sync-system link-home enable-user-services migrate; do
    stub "$bin/$name-stub" "echo \"$name \$*\" >>\"\$STUB_LOG\""
  done
  export AUTARCHY_INSTALL_PACKAGES="$bin/install-packages-stub"
  export AUTARCHY_SYNC_SYSTEM="$bin/sync-system-stub"
  export AUTARCHY_LINK_HOME="$bin/link-home-stub"
  export AUTARCHY_ENABLE_USER_SERVICES="$bin/enable-user-services-stub"
  export AUTARCHY_MIGRATE="$bin/migrate-stub"

  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "usage error on a bad subcommand" {
  run "$SCRIPT" bogus
  assert_failure
  assert_output --partial "usage"
}

@test "check: reports up to date when current matches the latest tag" {
  echo "2026.09.16" >"$BATS_TEST_TMPDIR/current-release-seed"
  mkdir -p "$AUTARCHY_STATE"
  echo "2026.09.16" >"$AUTARCHY_STATE/current-release"
  run "$SCRIPT" check
  assert_success
  assert_output --partial "up to date"
}

@test "check: reports a pending update and a change summary" {
  mkdir -p "$AUTARCHY_STATE"
  echo "2026.09.01" >"$AUTARCHY_STATE/current-release"
  run "$SCRIPT" check
  assert_success
  assert_output --partial "2026.09.01 -> 2026.09.16"
  assert_output --partial "diff stat"
}

@test "check: fails clearly when no release tags exist at all" {
  export STUB_TAGS=""
  run "$SCRIPT" check
  assert_failure
  assert_output --partial "no release tags found"
}

@test "apply: refuses when the working tree has uncommitted changes" {
  export STUB_PORCELAIN=" M some/file"
  run "$SCRIPT" apply
  assert_failure
  assert_output --partial "uncommitted changes"
  run calls
  refute_output --partial "snapper"
}

@test "apply: no-ops without snapshotting or running any applier when already current" {
  mkdir -p "$AUTARCHY_STATE"
  echo "2026.09.16" >"$AUTARCHY_STATE/current-release"
  run "$SCRIPT" apply
  assert_success
  assert_output --partial "up to date"
  run calls
  refute_output --partial "snapper"
  refute_output --partial "install-packages"
}

@test "apply: takes the pre-update snapshot before any applier runs" {
  run "$SCRIPT" apply
  assert_success
  run calls
  local snapshot_line applier_line
  snapshot_line=$(grep -n '^snapper -c root create' <<<"$output" | head -1 | cut -d: -f1)
  applier_line=$(grep -n '^install-packages' <<<"$output" | head -1 | cut -d: -f1)
  assert [ -n "$snapshot_line" ]
  assert [ -n "$applier_line" ]
  assert [ "$snapshot_line" -lt "$applier_line" ]
}

@test "apply: runs every applier in order" {
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_line --partial "install-packages"
  assert_line --partial "sudo"
  assert_line --partial "sync-system apply"
  assert_line --partial "link-home apply"
  assert_line --partial "enable-user-services apply"
  assert_line --partial "migrate apply"
}

@test "apply: refuses on a branch other than main, before touching anything" {
  export STUB_BRANCH=phase/11-default-browser
  run "$SCRIPT" apply
  assert_failure
  assert_output --partial "not main"
  run calls
  refute_output --partial "snapper"
}

@test "apply: moves a detached HEAD (post-bootstrap clone) onto main" {
  export STUB_BRANCH=HEAD
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_line --partial "checkout --quiet main"
}

@test "apply: records the new tag as current only once every step succeeds" {
  run "$SCRIPT" apply
  assert_success
  assert_equal "$(cat "$AUTARCHY_STATE/current-release")" "2026.09.16"
}
