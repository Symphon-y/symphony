#!/usr/bin/env bats
# Unit tests for home/update/dot-local/bin/update-status: the waybar badge (Phase 20).
# Reads the state file update-check wrote and prints waybar JSON -- nothing else. No
# network, so waybar can poll it as often as it likes.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/update/dot-local/bin/update-status"
  export SYMPHONY_STATE="$BATS_TEST_TMPDIR/state"
  STATE="$SYMPHONY_STATE/updates"
  mkdir -p "$SYMPHONY_STATE"
}

# Write a state file with the given key=value lines.
state() {
  printf '%s\n' "$@" >"$STATE"
}

@test "nothing pending prints nothing, which is how waybar hides the module" {
  state "packages=0" "pkglist=" "release=" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "no state file at all (never checked) prints nothing rather than failing" {
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "a pending release names the tag" {
  state "packages=0" "pkglist=" "release=2026.09.24" "installed=2026.09.22" "checked=1790000000"
  run bash -c "$SCRIPT | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"text\"])'"
  assert_success
  assert_output --partial "2026.09.24"
}

@test "output is valid JSON with the keys waybar reads" {
  state "packages=3" "pkglist=linux vim git" "release=2026.09.24" "installed=2026.09.22" "checked=1790000000"
  run bash -c "$SCRIPT | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sorted(d))'"
  assert_success
  assert_output --partial "class"
  assert_output --partial "text"
  assert_output --partial "tooltip"
}

@test "packages alone: the count is in the text, and the class says which kind" {
  state "packages=3" "pkglist=linux vim git" "release=" "installed=2026.09.24" "checked=1790000000"
  run bash -c "$SCRIPT | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[\"text\"], d[\"class\"])'"
  assert_success
  assert_output --partial "3"
  assert_output --partial "packages"
}

@test "a release outranks packages in the class, being the bigger change" {
  state "packages=3" "pkglist=linux vim git" "release=2026.09.24" "installed=2026.09.22" "checked=1790000000"
  run bash -c "$SCRIPT | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"class\"])'"
  assert_success
  assert_output "release"
}

@test "the tooltip names both halves when both are pending" {
  state "packages=2" "pkglist=linux vim" "release=2026.09.24" "installed=2026.09.22" "checked=1790000000"
  run bash -c "$SCRIPT | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"tooltip\"])'"
  assert_success
  assert_output --partial "2026.09.24"
  assert_output --partial "linux"
}

@test "a long package list is cut short in the tooltip rather than pasted in whole" {
  state "packages=37" "pkglist=$(printf 'pkg%02d ' $(seq 1 37))" "release=" "installed=2026.09.24" "checked=1790000000"
  run bash -c "$SCRIPT | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"tooltip\"])'"
  assert_success
  assert_output --partial "more"
  refute_output --partial "pkg37"
}

@test "a package name that would break JSON is escaped, not pasted in raw" {
  state 'packages=1' 'pkglist=we"ird' "release=" "installed=2026.09.24" "checked=1790000000"
  run bash -c "$SCRIPT | python3 -c 'import json,sys; json.load(sys.stdin); print(\"parsed\")'"
  assert_success
  assert_output "parsed"
}
