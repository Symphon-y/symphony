#!/usr/bin/env bats
# Unit tests for home/update/dot-local/bin/autarchy-update: the one way an installed
# machine moves from one payload to the next (Phase 18, D-0079). Everything that
# touches the network, root or the system is a stub on PATH that records its calls;
# the payload root is a temp dir. A "release" is a payload tarball the test builds
# with the real scripts/build-payload from a throwaway repo, so the download and
# unpack paths run for real.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@users.noreply.github.com
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@users.noreply.github.com
  SCRIPT="$REPO_ROOT/home/update/dot-local/bin/autarchy-update"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export AUTARCHY_PAYLOAD_ROOT="$BATS_TEST_TMPDIR/payload"
  export AUTARCHY_RELEASE_PUBKEY="$BATS_TEST_TMPDIR/release.pub"
  export AUTARCHY_PACMAN_LOCK="$BATS_TEST_TMPDIR/db.lck"
  export AUTARCHY_STATE="$BATS_TEST_TMPDIR/state"
  export AUTARCHY_RELEASE_REPO="example/autarchy"
  echo "untrusted comment: test key" >"$AUTARCHY_RELEASE_PUBKEY"
  export RELEASES="$BATS_TEST_TMPDIR/releases" # what "GitHub" serves, by tag
  mkdir -p "$RELEASES"
  make_installed_payload local-abc1234
  make_release 2026.09.22 "sleep-tool"
  export STUB_LATEST=2026.09.22
  make_stubs
}

# The payload an installed machine has: every applier present as a stub that logs
# which payload it was run from (the point of "appliers run from current").
make_installed_payload() {
  local version=$1 dir="$AUTARCHY_PAYLOAD_ROOT/current"
  mkdir -p "$dir/install" "$dir/scripts" "$dir/packages" "$dir/migrations" "$dir/home" "$dir/system"
  echo "$version" >"$dir/VERSION"
  local tool
  for tool in install/sync-system install/link-home install/enable-user-services install/enable-root-services install/install-packages scripts/migrate scripts/hwpkglist; do
    # shellcheck disable=SC2016 # stub body expands when the stub runs
    printf '#!/usr/bin/env bash\necho "%s${*:+ $*} from $(cat "$(dirname "$0")/../VERSION")" >>"$STUB_LOG"\n' "${tool##*/}" >"$dir/$tool"
    chmod +x "$dir/$tool"
  done
  echo "old-package" >"$dir/packages/base.txt"
}

# A release: a throwaway repo whose payload dirs carry the same logging stubs, packed
# by the real build-payload into $RELEASES/<tag>/ with its .sha256; the .minisig is a
# marker file the minisign stub honours.
make_release() {
  local tag=$1 package=$2
  local repo="$BATS_TEST_TMPDIR/repo-$tag"
  mkdir -p "$repo/install" "$repo/scripts" "$repo/packages" "$repo/migrations" "$repo/home" "$repo/system"
  local tool
  for tool in install/sync-system install/link-home install/enable-user-services install/enable-root-services install/install-packages scripts/migrate scripts/hwpkglist; do
    # shellcheck disable=SC2016 # stub body expands when the stub runs
    printf '#!/usr/bin/env bash\necho "%s${*:+ $*} from $(cat "$(dirname "$0")/../VERSION")" >>"$STUB_LOG"\n' "${tool##*/}" >"$repo/$tool"
    chmod +x "$repo/$tool"
  done
  echo "$package" >"$repo/packages/base.txt"
  echo "echo migrated" >"$repo/migrations/1-new.sh"
  echo 'readonly PAYLOAD_CONTENT=(home install migrations packages scripts system)' >"$repo/install/configure-base-system"
  git -C "$repo" init -q -b main
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "release $tag"
  mkdir -p "$RELEASES/$tag"
  "$REPO_ROOT/scripts/build-payload" "$repo" HEAD "$tag" "$RELEASES/$tag" >/dev/null
  echo "valid" >"$RELEASES/$tag/autarchy-$tag-payload.tar.zst.minisig"
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"

  # curl: the Releases API answers with the latest tag; an asset URL is served from
  # $RELEASES/<tag>/<file> into -o; anything else is a 404 (exit 22, like -f).
  cat >"$bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >>"$STUB_LOG"
[[ -n ${STUB_CURL_FAIL:-} ]] && exit 7
out=""; url=""
while (($#)); do
  case "$1" in
    -o) out=$2; shift 2 ;;
    http*) url=$1; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */releases/latest) printf '{"tag_name": "%s", "name": "x"}\n' "$STUB_LATEST" ;;
  */releases/download/*)
    tag=${url#*/releases/download/}; tag=${tag%%/*}; file=${url##*/}
    [[ -e $RELEASES/$tag/$file ]] || exit 22
    cp "$RELEASES/$tag/$file" "$out"
    ;;
  *) exit 22 ;;
esac
EOF

  # minisign -V: valid when the .minisig says so and the pubkey is the configured one.
  cat >"$bin/minisign" <<'EOF'
#!/usr/bin/env bash
echo "minisign $*" >>"$STUB_LOG"
sig=""; pub=""; file=""
while (($#)); do
  case "$1" in
    -V) shift ;;
    -p) pub=$2; shift 2 ;;
    -x) sig=$2; shift 2 ;;
    -m) file=$2; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z $sig ]] && sig="$file.minisig"
[[ $pub == "$AUTARCHY_RELEASE_PUBKEY" && $(cat "$sig") == valid ]] || { echo "Signature verification failed" >&2; exit 1; }
echo "Signature and comment signature verified"
EOF

  # sudo: log, then run the command as-is -- except chown, which a non-root test
  # cannot do and only needs to have been asked for (the payload dir is ours).
  printf '#!/usr/bin/env bash\necho "sudo $*" >>"$STUB_LOG"\n[[ $1 == chown ]] && exit 0\nexec "$@"\n' >"$bin/sudo"
  printf '#!/usr/bin/env bash\necho "snapper $*" >>"$STUB_LOG"\n' >"$bin/snapper"
  printf '#!/usr/bin/env bash\necho "notify-send $*" >>"$STUB_LOG"\n' >"$bin/notify-send"
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

installed_version() {
  cat "$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
}

# --- version / check ---------------------------------------------------------------

@test "usage error on a bad subcommand" {
  run "$SCRIPT" bogus
  assert_failure 2
  assert_output --partial "usage"
}

@test "version prints the installed payload's VERSION" {
  run "$SCRIPT" version
  assert_success
  assert_output "local-abc1234"
}

@test "check: a newer release is reported with what changed in packages/ and migrations/" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  run "$SCRIPT" check
  assert_success
  assert_output --partial "2026.09.01 -> 2026.09.22"
  assert_output --partial "sleep-tool"
  assert_output --partial "1-new.sh"
}

@test "check: up to date when the installed version is the latest" {
  echo "2026.09.22" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  run "$SCRIPT" check
  assert_success
  assert_output --partial "up to date (2026.09.22)"
  run calls
  refute_output --partial "releases/download"
}

@test "check: a local-* payload says so and names the release it would be replaced by" {
  run "$SCRIPT" check
  assert_success
  assert_output --partial "local-abc1234"
  assert_output --partial "2026.09.22"
  assert_output --partial "--yes"
}

@test "check: fails clearly when the release list cannot be fetched" {
  STUB_CURL_FAIL=1 run "$SCRIPT" check
  assert_failure
  assert_output --partial "could not"
}

# --- apply: refusals, before anything is touched -----------------------------------

@test "apply: refuses to replace a local-* payload from a release without --yes" {
  run "$SCRIPT" apply
  assert_failure
  assert_output --partial "--yes"
  assert_equal "$(installed_version)" "local-abc1234"
  run calls
  refute_output --partial "snapper"
}

@test "apply: refuses while a pacman transaction holds the lock" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  touch "$AUTARCHY_PACMAN_LOCK"
  run "$SCRIPT" apply
  assert_failure
  assert_output --partial "pacman"
  run calls
  refute_output --partial "snapper"
}

@test "apply: a bad signature stops before the snapshot, touches nothing, and leaves no download behind" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  echo "forged" >"$RELEASES/2026.09.22/autarchy-2026.09.22-payload.tar.zst.minisig"
  run "$SCRIPT" apply
  assert_failure
  assert_output --partial "signature"
  assert_equal "$(installed_version)" "2026.09.01"
  assert [ ! -e "$AUTARCHY_PAYLOAD_ROOT/previous" ]
  run calls
  refute_output --partial "snapper"
  run find "$BATS_TEST_TMPDIR" -name 'autarchy-2026.09.22-payload.tar.zst' -not -path "$RELEASES/*"
  assert_output ""
}

@test "apply: a checksum mismatch after a good signature is still a refusal" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  echo "0000000000000000000000000000000000000000000000000000000000000000  autarchy-2026.09.22-payload.tar.zst" \
    >"$RELEASES/2026.09.22/autarchy-2026.09.22-payload.tar.zst.sha256"
  run "$SCRIPT" apply
  assert_failure
  assert_output --partial "checksum"
  assert_equal "$(installed_version)" "2026.09.01"
}

@test "apply: up to date does nothing" {
  echo "2026.09.22" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  run "$SCRIPT" apply
  assert_success
  assert_output --partial "up to date"
  run calls
  refute_output --partial "snapper"
}

# --- apply: the pipeline ------------------------------------------------------------

@test "apply: verifies, snapshots, swaps, then runs every applier and the migrations from the NEW payload" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  run "$SCRIPT" apply
  assert_success
  assert_equal "$(installed_version)" "2026.09.22"
  assert_equal "$(cat "$AUTARCHY_PAYLOAD_ROOT/previous/VERSION")" "2026.09.01"
  run calls
  # Order: verify before the snapshot, the snapshot before anything moves.
  local verify snap sync
  verify=$(grep -n '^minisign' "$STUB_LOG" | cut -d: -f1 | head -1)
  snap=$(grep -n '^snapper' "$STUB_LOG" | cut -d: -f1 | head -1)
  sync=$(grep -n '^sync-system' "$STUB_LOG" | cut -d: -f1 | head -1)
  assert [ "$verify" -lt "$snap" ]
  assert [ "$snap" -lt "$sync" ]
  assert_line "snapper -c root create -d pre-update: 2026.09.01 -> 2026.09.22"
  # Every applier reports the payload it ran from -- the new one.
  assert_line "install-packages from 2026.09.22"
  assert_line "sync-system apply from 2026.09.22"
  assert_line "link-home apply from 2026.09.22"
  assert_line "enable-user-services apply from 2026.09.22"
  assert_line "enable-root-services apply from 2026.09.22"
  assert_line "migrate apply from 2026.09.22"
  refute_output --partial "from 2026.09.01"
}

@test "apply: root-only steps go through sudo, user-level ones do not" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_output --partial "sudo snapper"
  assert_output --regexp "sudo .*/current/install/sync-system apply"
  assert_output --regexp "sudo .*/current/install/enable-root-services apply"
  refute_output --regexp "sudo .*/link-home"
  refute_output --regexp "sudo .*/enable-user-services"
  refute_output --regexp "sudo .*/migrate"
}

@test "apply: hardware packages for this machine are installed alongside the declared ones" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_line "hwpkglist from 2026.09.22"
}

@test "apply: the swap is the same physical path (stow keeps its links) and previous is replaced, not nested" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  mkdir -p "$AUTARCHY_PAYLOAD_ROOT/previous"
  echo "2026.08.01" >"$AUTARCHY_PAYLOAD_ROOT/previous/VERSION"
  run "$SCRIPT" apply
  assert_success
  assert_equal "$(cat "$AUTARCHY_PAYLOAD_ROOT/previous/VERSION")" "2026.09.01"
  assert [ ! -e "$AUTARCHY_PAYLOAD_ROOT/previous/previous" ]
  assert [ ! -L "$AUTARCHY_PAYLOAD_ROOT/current" ]
  run find "$AUTARCHY_PAYLOAD_ROOT" -maxdepth 1 -name 'staging*'
  assert_output ""
}

@test "apply --yes: replaces a local-* payload from a release" {
  run "$SCRIPT" apply --yes
  assert_success
  assert_equal "$(installed_version)" "2026.09.22"
}

@test "apply: the new payload is root-owned before anything runs from it" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  run "$SCRIPT" apply
  assert_success
  run calls
  local chown sync
  chown=$(grep -n '^sudo chown -R root:root' "$STUB_LOG" | cut -d: -f1 | head -1)
  sync=$(grep -n '^sync-system' "$STUB_LOG" | cut -d: -f1 | head -1)
  assert [ -n "$chown" ]
  assert [ "$chown" -lt "$sync" ]
}

# --- apply --from DIR: the dev seat ------------------------------------------------

@test "apply --from DIR: stages the checkout with no download or verification, versioned local-<sha>" {
  local repo="$BATS_TEST_TMPDIR/repo-2026.09.22"
  local short
  short=$(git -C "$repo" rev-parse --short HEAD)
  run "$SCRIPT" apply --from "$repo"
  assert_success
  assert_equal "$(installed_version)" "local-$short"
  run calls
  refute_output --partial "curl"
  refute_output --partial "minisign"
  assert_line "snapper -c root create -d pre-update: local-abc1234 -> local-$short"
  assert_line "sync-system apply from local-$short"
}

@test "apply --from DIR: uncommitted changes deploy, with a warning (it is the working tree, like dev-deploy was)" {
  local repo="$BATS_TEST_TMPDIR/repo-2026.09.22"
  echo "wip" >"$repo/scripts/wip"
  run "$SCRIPT" apply --from "$repo"
  assert_success
  assert_output --partial "uncommitted"
  assert [ -e "$AUTARCHY_PAYLOAD_ROOT/current/scripts/wip" ]
}

@test "apply --from DIR: refuses a directory that is not a checkout of this repo" {
  mkdir -p "$BATS_TEST_TMPDIR/not-a-repo"
  run "$SCRIPT" apply --from "$BATS_TEST_TMPDIR/not-a-repo"
  assert_failure
  assert_output --partial "not-a-repo"
  assert_equal "$(installed_version)" "local-abc1234"
}

# --- rollback ----------------------------------------------------------------------

@test "rollback: previous becomes current again, the appliers run from it, migrations are not undone (and it says so)" {
  echo "2026.09.01" >"$AUTARCHY_PAYLOAD_ROOT/current/VERSION"
  "$SCRIPT" apply >/dev/null
  : >"$STUB_LOG"
  run "$SCRIPT" rollback
  assert_success
  assert_equal "$(installed_version)" "2026.09.01"
  assert_equal "$(cat "$AUTARCHY_PAYLOAD_ROOT/previous/VERSION")" "2026.09.22"
  assert_output --partial "migrations"
  run calls
  assert_line "snapper -c root create -d pre-rollback: 2026.09.22 -> 2026.09.01"
  assert_line "sync-system apply from 2026.09.01"
  assert_line "link-home apply from 2026.09.01"
  refute_output --partial "migrate apply"
}

@test "rollback: nothing to roll back to is a clear failure" {
  run "$SCRIPT" rollback
  assert_failure
  assert_output --partial "previous"
}
