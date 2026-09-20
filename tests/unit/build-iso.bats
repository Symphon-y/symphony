#!/usr/bin/env bats
# Unit tests for scripts/build-iso. The script runs against a throwaway git
# repo (it bundles whatever repo it lives in), and the container engine is a
# stub on PATH that records how it was called -- no real container, network or
# multi-gigabyte build here; the real build is verified by actually running it.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@users.noreply.github.com
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@users.noreply.github.com
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  make_repo
  make_stubs
  cd "$BATS_TEST_TMPDIR/out-cwd" || return 1
}

# A tiny repo with the two files the script copies into the container and one
# commit -- the script bundles whichever repo it sits in.
make_repo() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/scripts" "$REPO/iso" "$BATS_TEST_TMPDIR/out-cwd"
  cp "$REPO_ROOT/scripts/build-iso" "$REPO/scripts/build-iso"
  echo '#!/usr/bin/env bash' >"$REPO/iso/build-in-container"
  git -C "$REPO" init -q -b main
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "first"
  SHA=$(git -C "$REPO" rev-parse HEAD)
  SHORT=$(git -C "$REPO" rev-parse --short HEAD)
  SCRIPT="$REPO/scripts/build-iso"
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  cat >"$bin/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >>"$STUB_LOG"
case "$1" in
  create)
    printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/create.args"
    exit "${STUB_CREATE_RC:-0}"
    ;;
  start)
    cat >"$BATS_TEST_TMPDIR/bundle.in"
    exit "${STUB_START_RC:-0}"
    ;;
  cp)
    # The output copy runs from inside the out dir: cp NAME:/out/. .
    if [[ ${2:-} == *:/out/. ]]; then
      tag=$(sed -n 's/^AUTARCHY_TAG=//p' "$BATS_TEST_TMPDIR/create.args")
      : >"autarchy-$tag.iso"
      : >"autarchy-$tag.iso.sha256"
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$bin/docker"
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "usage error on an unknown flag, without touching the container engine" {
  run "$SCRIPT" --bogus
  assert_failure 2
  assert_output --partial "usage"
  run calls
  assert_output ""
}

@test "fails before starting a container when the ref doesn't exist" {
  run "$SCRIPT" --ref no-such-branch
  assert_failure
  assert_output --partial "no-such-branch"
  run calls
  refute_output --partial "docker create"
}

@test "fails clearly when the container engine isn't installed" {
  AUTARCHY_CONTAINER_ENGINE=definitely-not-installed run "$SCRIPT"
  assert_failure
  assert_output --partial "definitely-not-installed"
}

@test "builds in a privileged Arch container, with the resolved commit and default tag passed in" {
  run "$SCRIPT" --out "$BATS_TEST_TMPDIR/out"
  assert_success
  run cat "$BATS_TEST_TMPDIR/create.args"
  assert_line "--privileged"
  assert_line "archlinux:latest"
  assert_line "AUTARCHY_SHA=$SHA"
  # No tag given: named after the commit so a booted build can be told apart.
  assert_line "AUTARCHY_TAG=local-$SHORT"
}

@test "--tag overrides the default tag; --ref selects the commit" {
  git -C "$REPO" commit -q --allow-empty -m "second"
  run "$SCRIPT" --ref HEAD~1 --tag 2026.09.20-test1 --out "$BATS_TEST_TMPDIR/out"
  assert_success
  run cat "$BATS_TEST_TMPDIR/create.args"
  assert_line "AUTARCHY_TAG=2026.09.20-test1"
  assert_line "AUTARCHY_SHA=$SHA"
}

@test "streams a git bundle of the repo into the container instead of bind-mounting the working tree" {
  # A bind mount would carry the host's line endings, flattened symlinks and
  # modes into the ISO; a bundle rebuilds the tree from git objects.
  run "$SCRIPT" --out "$BATS_TEST_TMPDIR/out"
  assert_success
  run head -1 "$BATS_TEST_TMPDIR/bundle.in"
  assert_output --regexp '^# v[23] git bundle'
  run calls
  refute_output --partial " -v "
}

@test "copies the in-container build script into the container before starting it" {
  run "$SCRIPT" --out "$BATS_TEST_TMPDIR/out"
  assert_success
  run calls
  # A relative path (the script cds into the repo first): an absolute host path
  # would need translating on Windows, where the engine is a native program.
  assert_line --regexp '^docker cp iso/build-in-container autarchy-iso-build-[0-9]+:/build\.sh$'
}

@test "copies the built ISO and its checksum into the out dir and says where" {
  run "$SCRIPT" --tag t1 --out "$BATS_TEST_TMPDIR/out"
  assert_success
  assert [ -e "$BATS_TEST_TMPDIR/out/autarchy-t1.iso" ]
  assert [ -e "$BATS_TEST_TMPDIR/out/autarchy-t1.iso.sha256" ]
  assert_output --partial "autarchy-t1.iso"
}

@test "removes the container after a successful build" {
  run "$SCRIPT" --out "$BATS_TEST_TMPDIR/out"
  assert_success
  run calls
  assert_line --regexp '^docker rm -f autarchy-iso-build-[0-9]+$'
}

@test "removes the container and fails when the build fails" {
  STUB_START_RC=1 run "$SCRIPT" --out "$BATS_TEST_TMPDIR/out"
  assert_failure
  run calls
  assert_line --regexp '^docker rm -f autarchy-iso-build-[0-9]+$'
  refute_output --partial "docker cp autarchy-iso-build"
}

@test "fails when the build ends without producing the expected ISO" {
  # A container that exits 0 without an ISO (say a build script that swallowed
  # an error) must not be reported as success.
  cat >"$BATS_TEST_TMPDIR/bin/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >>"$STUB_LOG"
[[ $1 == start ]] && cat >/dev/null
exit 0
EOF
  run "$SCRIPT" --tag t2 --out "$BATS_TEST_TMPDIR/out"
  assert_failure
  assert_output --partial "autarchy-t2.iso"
}

@test "warns that uncommitted changes are not in the ISO" {
  echo change >>"$REPO/iso/build-in-container"
  run "$SCRIPT" --out "$BATS_TEST_TMPDIR/out"
  assert_success
  assert_output --partial "uncommitted"
}

@test "says nothing about uncommitted changes when the tree is clean" {
  run "$SCRIPT" --out "$BATS_TEST_TMPDIR/out"
  assert_success
  refute_output --partial "uncommitted"
}
