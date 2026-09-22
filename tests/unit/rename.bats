#!/usr/bin/env bats
# Unit tests for scripts/rename: the project's name is a plain token, renamed by one
# mechanical, re-runnable script (D-0081) -- content in three cases (lower, Capital,
# UPPER), tracked paths, nothing else. Runs against a throwaway git repo.

setup() {
  load '../helpers/common'
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@users.noreply.github.com
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@users.noreply.github.com
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/scripts" "$REPO/system/oldname" "$REPO/system/hosts/oldname-vm" "$REPO/home/x/dot-local/bin"
  cp "$REPO_ROOT/scripts/rename" "$REPO/scripts/rename"
  # a fake check so the script's final step has something to run
  printf '#!/usr/bin/env bash\necho check-ran\n' >"$REPO/scripts/check"
  chmod +x "$REPO/scripts/check"
  cat >"$REPO/README.md" <<'EOF'
# oldname

Oldname is an OLDNAME_STYLE project. Run oldname-update. See github.com/Someone/oldname.
The word boldnamed and unoldnamely contain the letters but are not the token.
EOF
  # shellcheck disable=SC2016 # fixture content, not expanded
  printf 'readonly ROOT="${OLDNAME_ROOT:-/usr/local/share/oldname}"\n' >"$REPO/scripts/tool"
  printf 'key\n' >"$REPO/system/oldname/release.pub"
  printf 'x\n' >"$REPO/system/hosts/oldname-vm/files.txt"
  printf '#!/usr/bin/env bash\necho oldname\n' >"$REPO/home/x/dot-local/bin/oldname-update"
  chmod +x "$REPO/home/x/dot-local/bin/oldname-update"
  printf '\x89PNG\r\n\x1a\n oldname \x00\x01' >"$REPO/logo.png"
  git -C "$REPO" init -q -b main
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "first"
  SCRIPT="$REPO/scripts/rename"
}

@test "usage: needs OLD and NEW" {
  run "$SCRIPT" oldname
  assert_failure 2
  assert_output --partial "usage"
}

@test "refuses a name that is not lowercase letters, digits and hyphens" {
  run "$SCRIPT" oldname "New Name"
  assert_failure
  assert_output --partial "lowercase"
  run "$SCRIPT" oldname 9lives
  assert_failure
}

@test "refuses a dirty tree (the rename must be one clean, reviewable commit)" {
  echo "wip" >"$REPO/wip"
  run "$SCRIPT" oldname newname
  assert_failure
  assert_output --partial "uncommitted"
}

@test "renames the token in all three cases, in every tracked text file" {
  run "$SCRIPT" oldname newname
  assert_success
  run cat "$REPO/README.md"
  assert_line "# newname"
  assert_line --partial "Newname is an NEWNAME_STYLE project. Run newname-update. See github.com/Someone/newname."
  run cat "$REPO/scripts/tool"
  # shellcheck disable=SC2016 # expected literal text
  assert_output 'readonly ROOT="${NEWNAME_ROOT:-/usr/local/share/newname}"'
}

@test "leaves the letters alone inside other words (exact token only)" {
  run "$SCRIPT" oldname newname
  assert_success
  run grep -c 'boldnamed and unoldnamely' "$REPO/README.md"
  assert_output "1"
}

@test "moves every tracked path that carries the token, files and directories" {
  run "$SCRIPT" oldname newname
  assert_success
  assert [ -e "$REPO/system/newname/release.pub" ]
  assert [ -e "$REPO/system/hosts/newname-vm/files.txt" ]
  assert [ -x "$REPO/home/x/dot-local/bin/newname-update" ]
  assert [ ! -e "$REPO/system/oldname" ]
  assert [ ! -e "$REPO/home/x/dot-local/bin/oldname-update" ]
  # moved with git, so history follows the file
  run git -C "$REPO" status --porcelain
  assert_output --partial "R  system/oldname/release.pub -> system/newname/release.pub"
}

@test "leaves binary files untouched" {
  local before
  before=$(sha256sum <"$REPO/logo.png")
  run "$SCRIPT" oldname newname
  assert_success
  assert_equal "$(sha256sum <"$REPO/logo.png")" "$before"
}

@test "runs the checks at the end and reports what it did" {
  run "$SCRIPT" oldname newname
  assert_success
  assert_output --partial "check-ran"
  assert_output --partial "files changed"
  assert_output --partial "paths moved"
}

@test "nothing left: the old token does not appear anywhere tracked afterwards" {
  "$SCRIPT" oldname newname >/dev/null
  # as a token, in any case -- the fixture's "boldnamed" is not the token
  run git -C "$REPO" grep -I -i -l -E '(^|[^a-z0-9])oldname([^a-z0-9]|$)' -- . ':!logo.png'
  assert_failure
  assert_output ""
}

@test "is idempotent: a second run has nothing to do and succeeds" {
  "$SCRIPT" oldname newname >/dev/null
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "rename"
  run "$SCRIPT" oldname newname
  assert_success
  assert_output --partial "nothing to rename"
}

@test "a file marked '# rename: keep' is left alone and does not count as NEW being in use" {
  printf '# rename: keep\nmoves oldname to newname\n' >"$REPO/migrations-note.md"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "note"
  run "$SCRIPT" oldname newname
  assert_success
  run cat "$REPO/migrations-note.md"
  assert_line "moves oldname to newname"
}

@test "refuses when NEW is already in use as a token (would merge two names)" {
  echo "newname is taken" >"$REPO/taken.md"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "taken"
  run "$SCRIPT" oldname newname
  assert_failure
  assert_output --partial "already"
}
