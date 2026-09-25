#!/usr/bin/env bats
# Phase 18 acceptance tests: a signed release payload and the updater that applies
# it. Static, repo-checkable properties; the updater's behaviour is unit-tested
# (tests/unit/symphony-update.bats) and the pipeline is exercised for real on the
# Alienware (see the tracking doc).

setup() {
  load '../helpers/common'
  WORKFLOW="$REPO_ROOT/.github/workflows/release-iso.yml"
  UPDATE="$REPO_ROOT/home/update/dot-local/bin"
}

# --- the release ------------------------------------------------------------------

@test "release: the workflow builds, signs and publishes the payload in its own job, before the ISO" {
  run yq -r '.jobs | keys | .[]' "$WORKFLOW"
  assert_success
  assert_line "payload"
  run yq -r '.jobs["build-and-release"].needs' "$WORKFLOW"
  assert_output "payload"
  run grep -F 'scripts/build-payload' "$WORKFLOW"
  assert_success
  run grep -E 'minisign -S' "$WORKFLOW"
  assert_success
  run grep -F 'MINISIGN_SECRET_KEY' "$WORKFLOW"
  assert_success
}

@test "release: a tag with a suffix (2026.09.22-test1) is published as a pre-release" {
  run grep -F -- '--prerelease' "$WORKFLOW"
  assert_success
}

@test "release: the public key ships in the system, root-owned, where the updater reads it" {
  local key="$REPO_ROOT/system/symphony/release.pub"
  assert [ -e "$key" ]
  run head -n1 "$key"
  assert_output --partial "untrusted comment:"
  run sed -n 2p "$key"
  assert_output --regexp '^[A-Za-z0-9+/=]{40,}$'
  run grep -E '^0644[[:space:]]+symphony/release\.pub[[:space:]]+/etc/symphony/release\.pub$' "$REPO_ROOT/system/files.txt"
  assert_success
}

@test "packages: minisign and zstd are in the inventory (every installed machine verifies and unpacks)" {
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT"/packages/*.txt
  assert_success
  assert_line "minisign"
  assert_line "zstd"
}

@test "release: the payload allow-list has one home, shared by the installer and the builder" {
  run grep -F 'PAYLOAD_CONTENT=(home install migrations packages scripts system)' "$REPO_ROOT/install/configure-base-system"
  assert_success
  run grep -F 'configure-base-system' "$REPO_ROOT/scripts/build-payload"
  assert_success
}

# --- the updater ------------------------------------------------------------------

@test "updater: one command, four subcommands, in the payload (home/), never in scripts/" {
  assert [ -x "$UPDATE/symphony-update" ]
  assert [ ! -e "$REPO_ROOT/scripts/update" ]
  run grep -E 'usage: symphony-update check \| apply .* \| rollback \| version' "$UPDATE/symphony-update"
  assert_success
}

@test "updater: verifies with minisign against /etc/symphony/release.pub, and downloads only over https" {
  run grep -F '/etc/symphony/release.pub' "$UPDATE/symphony-update"
  assert_success
  run grep -E "curl .*--proto '=https'" "$UPDATE/symphony-update"
  assert_success
}

@test "updater: the payload path stays physically the same across updates (stow, D-0067)" {
  # current/ is a real directory replaced by rename, never a symlink.
  # shellcheck disable=SC2016 # matching the script's literal text, not expanding it
  run grep -E 'mv "\$staging" "\$CURRENT"' "$UPDATE/symphony-update"
  assert_success
  run grep -E 'ln -s' "$UPDATE/symphony-update"
  assert_failure
}

@test "updater: update-notify lives in the same package and checks releases/latest" {
  assert [ -x "$UPDATE/update-notify" ]
  assert [ ! -e "$REPO_ROOT/home/update-notify" ]
  run grep -F 'releases/latest' "$UPDATE/update-notify"
  assert_success
  run grep -F 'symphony-update apply' "$UPDATE/update-notify"
  assert_success
}

@test "installer: no per-user release marker is seeded any more (VERSION in the payload is the one source)" {
  run grep -F 'current-release' "$REPO_ROOT/install/install-base-system"
  assert_failure
}

# --- the record -----------------------------------------------------------------------

@test "docs: LICENSE exists (the repo is public)" {
  assert [ -f "$REPO_ROOT/LICENSE" ]
}

@test "docs: DECISIONS.md records D-0078 to D-0080" {
  local id
  for id in D-0078 D-0079 D-0080; do
    run grep -E "^## $id " "$REPO_ROOT/DECISIONS.md"
    assert_success
  done
}

@test "release: the one-time signing setup is a script, and it never puts a secret key in the repo" {
  assert [ -x "$REPO_ROOT/scripts/setup-signing" ]
  run grep -F 'gh secret set MINISIGN_SECRET_KEY' "$REPO_ROOT/scripts/setup-signing"
  assert_success
  run git -C "$REPO_ROOT" ls-files -- '*.key' 'system/symphony/'
  assert_output "system/symphony/release.pub"
}
