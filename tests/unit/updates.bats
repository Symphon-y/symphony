#!/usr/bin/env bats
# Unit tests for scripts/lib/updates.bash: the state file's shape, and the one way to
# render a package list for a human (Phase 20, D-0087). Four scripts read this; the
# format and the truncation live here so they cannot drift apart.

# Each @test runs in its own subshell, so the UPDATE_* assignments are intentionally
# local to it -- that is what keeps the tests independent.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  export HOME="$BATS_TEST_TMPDIR/home"
  export SYMPHONY_STATE="$HOME/.local/state/symphony"
  mkdir -p "$SYMPHONY_STATE"
  # shellcheck source-path=SCRIPTDIR source=../../scripts/lib/updates.bash
  source "$REPO_ROOT/scripts/lib/updates.bash"
}

@test "an unwritten state file reads as nothing pending, not as an error" {
  updates_load
  assert_equal "$UPDATE_PACKAGES" 0
  assert_equal "$UPDATE_RELEASE" ""
  run updates_pending
  assert_failure
}

@test "a saved state round-trips" {
  UPDATE_PACKAGES=2 UPDATE_PKGLIST="linux vim" UPDATE_RELEASE=2026.09.25 UPDATE_INSTALLED=2026.09.24
  updates_save
  updates_load
  assert_equal "$UPDATE_PACKAGES" 2
  assert_equal "$UPDATE_PKGLIST" "linux vim"
  assert_equal "$UPDATE_RELEASE" "2026.09.25"
  assert_equal "$UPDATE_INSTALLED" "2026.09.24"
}

@test "a corrupted state file is parsed, never executed" {
  # shellcheck disable=SC2016 # the point is that this does NOT expand: it must reach
  # the state file literally, so the test proves updates_load does not run it
  printf 'packages=$(touch %s/pwned)\n' "$BATS_TEST_TMPDIR" >"$SYMPHONY_STATE/updates"
  updates_load
  assert [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
  assert_equal "$UPDATE_PACKAGES" 0
}

@test "either kind pending counts as pending" {
  UPDATE_PACKAGES=1 UPDATE_PKGLIST=linux UPDATE_RELEASE="" UPDATE_INSTALLED=2026.09.24
  run updates_pending
  assert_success
  UPDATE_PACKAGES=0 UPDATE_PKGLIST="" UPDATE_RELEASE=2026.09.25 UPDATE_INSTALLED=2026.09.24
  run updates_pending
  assert_success
}

# --- rendering a package list for a human ---------------------------------------------

@test "a short list is shown whole" {
  run updates_pkglist_summary "linux vim git" 5
  assert_output "linux, vim, git"
}

@test "a long list is cut short and counts the rest: 37 names is not a tooltip" {
  run updates_pkglist_summary "a b c d e f g h" 3
  assert_output "a, b, c and 5 more"
}

@test "a list exactly at the limit is not truncated" {
  run updates_pkglist_summary "a b c" 3
  assert_output "a, b, c"
}

@test "one over the limit says 'and 1 more', not 'and 1 mores'" {
  run updates_pkglist_summary "a b c d" 3
  assert_output "a, b, c and 1 more"
}

@test "an empty list renders as nothing" {
  run updates_pkglist_summary "" 5
  assert_output ""
}
