#!/usr/bin/env bats
# Unit tests for scripts/pkglist, the single parser for packages/*.txt.

setup() {
  load '../helpers/common'
  PKGLIST="$REPO_ROOT/scripts/pkglist"
}

# Write a package-list fixture where each argument is one line; print its path.
fixture() {
  local path="$BATS_TEST_TMPDIR/$1"
  shift
  printf '%s\n' "$@" >"$path"
  echo "$path"
}

@test "prints each declared package on its own line" {
  list=$(fixture a.txt "git" "neovim")
  run "$PKGLIST" "$list"
  assert_success
  assert_output "$(printf 'git\nneovim')"
}

@test "ignores full-line and trailing comments" {
  list=$(fixture a.txt "# heading" "git   # version control" "neovim# editor")
  run "$PKGLIST" "$list"
  assert_success
  assert_output "$(printf 'git\nneovim')"
}

@test "ignores blank and whitespace-only lines" {
  list=$(fixture a.txt "" "git" "   " $'\t' "neovim")
  run "$PKGLIST" "$list"
  assert_success
  assert_output "$(printf 'git\nneovim')"
}

@test "merges several lists into one sorted list without duplicates" {
  a=$(fixture a.txt "zsh" "git")
  b=$(fixture b.txt "git" "bats")
  run "$PKGLIST" "$a" "$b"
  assert_success
  assert_output "$(printf 'bats\ngit\nzsh')"
}

@test "fails and names the file when a list is missing" {
  run "$PKGLIST" "$BATS_TEST_TMPDIR/missing.txt"
  assert_failure 1
  assert_output --partial "missing.txt"
}

@test "fails with usage when given no lists" {
  run "$PKGLIST"
  assert_failure 2
  assert_output --partial "usage"
}

@test "rejects a line naming more than one package and prints no packages" {
  list=$(fixture a.txt "git" "neovim vim")
  run "$PKGLIST" "$list"
  assert_failure 1
  assert_output --partial "a.txt:2"
  refute_line "git"
}
