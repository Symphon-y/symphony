#!/usr/bin/env bats
# Unit tests for scripts/build-payload: a release payload -- the six directories an
# installed machine runs from (D-0067) plus VERSION -- built from a committed ref of
# a repo, as a tar.zst. Runs against a throwaway git repo, like build-iso.bats.

setup() {
  load '../helpers/common'
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@users.noreply.github.com
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@users.noreply.github.com
  SCRIPT="$REPO_ROOT/scripts/build-payload"
  OUT="$BATS_TEST_TMPDIR/out"
  mkdir -p "$OUT"
  make_repo
}

# A repo with every top-level directory the real one has, one file each, so the
# allow-list (not an exclude list) is what the test exercises.
make_repo() {
  REPO="$BATS_TEST_TMPDIR/repo"
  local dir
  for dir in home/pkg/dot-config install migrations packages scripts system tests gui iso docs; do
    mkdir -p "$REPO/$dir"
    echo "x" >"$REPO/$dir/file"
  done
  echo "secret" >"$REPO/base-install.local.vars"
  echo "# readme" >"$REPO/README.md"
  git -C "$REPO" init -q -b main
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "first"
}

listing() {
  tar --zstd -tf "$OUT/autarchy-$1-payload.tar.zst" | sort
}

@test "usage: needs a repo, a ref, a tag and an out dir" {
  run "$SCRIPT" "$REPO" HEAD
  assert_failure 2
  assert_output --partial "usage"
}

@test "packs exactly the payload directories plus VERSION, nothing else" {
  run "$SCRIPT" "$REPO" HEAD 2026.09.22 "$OUT"
  assert_success
  run listing 2026.09.22
  assert_line "VERSION"
  assert_line "home/pkg/dot-config/file"
  assert_line "install/file"
  assert_line "migrations/file"
  assert_line "packages/file"
  assert_line "scripts/file"
  assert_line "system/file"
  refute_output --partial "tests/"
  refute_output --partial "gui/"
  refute_output --partial "iso/"
  refute_output --partial "docs/"
  refute_output --partial "README"
  refute_output --partial ".git"
  refute_output --partial "local.vars"
}

@test "VERSION carries the tag" {
  run "$SCRIPT" "$REPO" HEAD 2026.09.22 "$OUT"
  assert_success
  run tar --zstd -xOf "$OUT/autarchy-2026.09.22-payload.tar.zst" VERSION
  assert_output "2026.09.22"
}

@test "packs the committed ref, not the working tree" {
  echo "uncommitted" >"$REPO/scripts/extra"
  run "$SCRIPT" "$REPO" HEAD 2026.09.22 "$OUT"
  assert_success
  run listing 2026.09.22
  refute_output --partial "scripts/extra"
}

@test "writes a sha256 beside the archive that verifies" {
  run "$SCRIPT" "$REPO" HEAD 2026.09.22 "$OUT"
  assert_success
  run bash -c "cd '$OUT' && sha256sum -c autarchy-2026.09.22-payload.tar.zst.sha256"
  assert_success
}

@test "fails clearly on a ref that does not exist" {
  run "$SCRIPT" "$REPO" no-such-ref 2026.09.22 "$OUT"
  assert_failure
  assert_output --partial "no-such-ref"
  assert [ ! -e "$OUT/autarchy-2026.09.22-payload.tar.zst" ]
}

@test "the same commit packs to the same bytes (reproducible: fixed mtime and owner)" {
  "$SCRIPT" "$REPO" HEAD 2026.09.22 "$OUT"
  local first
  first=$(sha256sum <"$OUT/autarchy-2026.09.22-payload.tar.zst")
  sleep 1
  "$SCRIPT" "$REPO" HEAD 2026.09.22 "$OUT"
  assert_equal "$(sha256sum <"$OUT/autarchy-2026.09.22-payload.tar.zst")" "$first"
}
