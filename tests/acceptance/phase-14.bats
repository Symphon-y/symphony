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

@test "profiledef.sh: derives file_permissions for every baked-in script from git, not a hand-typed list" {
  # A real hardware boot test hit "install/install-base-system: Permission
  # denied" (and, less visibly, the same for scripts/system-report and
  # every other baked-in script -- its call site swallows the failure
  # with `|| true`). Root cause, confirmed directly from archiso's own
  # source (archlinux/archiso, archiso/mkarchiso, _make_custom_airootfs):
  # mkarchiso copies the whole airootfs/ tree with `cp -af --no-preserve=
  # ownership,mode`, unconditionally stripping every mode bit, then
  # restores it only for paths explicitly listed in profiledef.sh's
  # file_permissions array. A CI-side chmod pass *before* mkarchiso runs
  # (tried first, didn't work) can never survive that copy. The fix has
  # to populate file_permissions itself, and it has to be derived from
  # git's own index (the one place the bit is already tracked correctly)
  # rather than hand-listed, so a script added later doesn't silently
  # ship non-executable.
  local pd="$REPO_ROOT/iso/profile/profiledef.sh"
  run grep -q 'ls-files -s' "$pd"
  assert_success
  run grep -q '100755' "$pd"
  assert_success
  run grep -q 'file_permissions\["/root/autarchy/' "$pd"
  assert_success

  # Dry-run the exact logic against this real repo (mirroring mkarchiso's
  # own pre-declared associative array) and confirm it actually finds
  # install-base-system and system-report -- the two scripts a real boot
  # test found broken.
  # shellcheck disable=SC2016 # single-quoted on purpose -- $PD expands in the subshell, not here
  run env PD="$pd" bash -c 'declare -A file_permissions; source "$PD"; echo "${file_permissions[/root/autarchy/install/install-base-system]:-}"; echo "${file_permissions[/root/autarchy/scripts/system-report]:-}"'
  assert_success
  assert_output "$(printf '0:0:755\n0:0:755')"
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
