#!/usr/bin/env bats
# Unit tests for scripts/migrate. Runs against fixture migrations and a fixture
# state dir (both overridden via env vars), never the real migrations/ directory.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/migrate"
  export AUTARCHY_MIGRATIONS_DIR="$BATS_TEST_TMPDIR/migrations"
  export AUTARCHY_STATE="$BATS_TEST_TMPDIR/state"
  mkdir -p "$AUTARCHY_MIGRATIONS_DIR"
}

# A migration that appends its own name to a log each time it actually runs --
# lets a test prove it ran exactly once regardless of how many times apply is
# invoked.
fixture_migration() {
  local name="$1" path="$AUTARCHY_MIGRATIONS_DIR/$1"
  printf '#!/usr/bin/env bash\necho "ran: %s" >>"%s"\n' "$name" "$BATS_TEST_TMPDIR/ran.log" >"$path"
  chmod +x "$path"
}

@test "fails with usage when no command is given" {
  run "$SCRIPT"
  assert_failure 2
  assert_output --partial "usage"
}

@test "check reports nothing pending against an empty migrations directory" {
  run "$SCRIPT" check
  assert_success
  assert_output --partial "nothing pending"
}

@test "check lists a migration that hasn't run yet" {
  fixture_migration "1000-first.sh"
  run "$SCRIPT" check
  assert_success
  assert_output --partial "pending: 1000-first.sh"
}

@test "apply runs a pending migration and marks it complete" {
  fixture_migration "1000-first.sh"
  run "$SCRIPT" apply
  assert_success
  assert_output --partial "running: 1000-first.sh"
  assert [ -e "$AUTARCHY_STATE/migrations/1000-first.sh" ]
  run cat "$BATS_TEST_TMPDIR/ran.log"
  assert_output "ran: 1000-first.sh"
}

@test "a completed migration is never run again" {
  fixture_migration "1000-first.sh"
  "$SCRIPT" apply
  run "$SCRIPT" apply
  assert_success
  refute_output --partial "running: 1000-first.sh"
  run cat "$BATS_TEST_TMPDIR/ran.log"
  assert_output "ran: 1000-first.sh"
}

@test "apply stops at the first failing migration and never marks it complete" {
  fixture_migration "1000-first.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$AUTARCHY_MIGRATIONS_DIR/1001-broken.sh"
  chmod +x "$AUTARCHY_MIGRATIONS_DIR/1001-broken.sh"
  fixture_migration "1002-third.sh"

  run "$SCRIPT" apply
  assert_failure
  assert [ -e "$AUTARCHY_STATE/migrations/1000-first.sh" ]
  assert [ ! -e "$AUTARCHY_STATE/migrations/1001-broken.sh" ]
  assert [ ! -e "$AUTARCHY_STATE/migrations/1002-third.sh" ]
  run cat "$BATS_TEST_TMPDIR/ran.log"
  refute_output --partial "third"
}

@test "migrations run in filename (timestamp) order" {
  fixture_migration "1002-second.sh"
  fixture_migration "1000-first.sh"
  "$SCRIPT" apply
  run cat "$BATS_TEST_TMPDIR/ran.log"
  assert_output "$(printf 'ran: 1000-first.sh\nran: 1002-second.sh')"
}
