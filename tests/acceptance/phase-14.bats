#!/usr/bin/env bats
# Phase 14 acceptance tests: the repo itself baked into the ISO, so the core
# install needs zero network/GitHub access. Static, VM-checkable properties
# only -- the baked-in repo content is CI-generated and gitignored (same as
# Phase 13's local package cache), so real verification is a real tag push,
# not a static test (see the tracking doc).

setup() {
  load '../helpers/common'
}

@test "release workflow: bakes the repo into the live environment before the offline-repo/ISO build" {
  local wf="$REPO_ROOT/.github/workflows/release-iso.yml"
  run grep -q 'rsync' "$wf"
  assert_success

  local bake_line release_line build_line
  release_line=$(grep -n 'Record the release tag' "$wf" | head -1 | cut -d: -f1)
  bake_line=$(grep -n 'rsync' "$wf" | head -1 | cut -d: -f1)
  build_line=$(grep -n '/workspace/iso/build-offline-repo' "$wf" | head -1 | cut -d: -f1)
  assert [ -n "$release_line" ]
  assert [ -n "$bake_line" ]
  assert [ -n "$build_line" ]
  assert [ "$release_line" -lt "$bake_line" ]
  assert [ "$bake_line" -lt "$build_line" ]
}

@test "release workflow: excludes .git and the airootfs it's copying into (avoids self-nesting and doubling the package cache)" {
  local wf="$REPO_ROOT/.github/workflows/release-iso.yml"
  run grep -q -- "--exclude='.git'" "$wf"
  assert_success
  run grep -q -- "--exclude='iso/profile/airootfs'" "$wf"
  assert_success
}

@test "release workflow: re-stamps executable bits on the baked-in repo copy, from git, after the bake-in and before the build" {
  # A real hardware boot test hit "install/install-base-system: Permission
  # denied" -- the executable bit was lost somewhere in the checkout ->
  # rsync -> mkarchiso pipeline for a script git's own index confirms is
  # 100755. Re-stamped from git (the one place the bit is guaranteed
  # correct) right before mkarchiso reads the tree.
  local wf="$REPO_ROOT/.github/workflows/release-iso.yml"
  run grep -q "git ls-files -s" "$wf"
  assert_success
  run grep -q '100755' "$wf"
  assert_success

  local bake_line chmod_line build_line
  bake_line=$(grep -n 'rsync' "$wf" | head -1 | cut -d: -f1)
  chmod_line=$(grep -n 'git ls-files -s' "$wf" | head -1 | cut -d: -f1)
  build_line=$(grep -n '/workspace/iso/build-offline-repo' "$wf" | head -1 | cut -d: -f1)
  assert [ -n "$chmod_line" ]
  assert [ "$bake_line" -lt "$chmod_line" ]
  assert [ "$chmod_line" -lt "$build_line" ]
}

@test "autarchy-bootstrap is fully retired -- no trace outside historical records" {
  assert [ ! -e "$REPO_ROOT/iso/profile/airootfs/usr/local/bin/autarchy-bootstrap" ]
  # docs/phases/ is allowed to still mention the retired name: phase-10 and
  # phase-12's tracking docs are accurate history of what was true when
  # they ran (established precedent, see docs/roadmap.md's Phase 13 entry),
  # and this phase's own tracking doc explains what it retired and why.
  # Everything else -- scripts, other docs, other tests -- must be clean.
  run bash -c "grep -rl 'autarchy-bootstrap' '$REPO_ROOT' --exclude-dir=.git --exclude-dir=phases | grep -v tests/acceptance/phase-14.bats"
  assert_failure
  assert_output ""
}

@test "autarchy-install no longer conditionally clones -- the repo is always already there" {
  local script="$REPO_ROOT/iso/profile/airootfs/usr/local/bin/autarchy-install"
  assert [ -x "$script" ]
  run grep -q 'CLONE_DIR=/root/autarchy' "$script"
  assert_success
  # shellcheck disable=SC2016 # a literal grep pattern, not meant to expand
  run grep -q 'cd "\$CLONE_DIR"' "$script"
  assert_success
}
