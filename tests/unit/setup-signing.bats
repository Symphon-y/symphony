#!/usr/bin/env bats
# Unit tests for scripts/setup-signing: the maintainer's one-time step that makes
# releases signable -- a minisign keypair, the public half committed into the repo,
# the secret half and its password stored as repository secrets, never on disk in
# the repo. minisign and gh are stubs on PATH.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/setup-signing"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/system/autarchy" "$REPO/scripts"
  cp "$SCRIPT" "$REPO/scripts/setup-signing"
  SCRIPT="$REPO/scripts/setup-signing"
  export KEYDIR="$BATS_TEST_TMPDIR/keys"
  export MINISIGN_PASSWORD_INPUT="hunter22"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  # minisign -G writes a fake keypair; the password comes on stdin (twice).
  cat >"$bin/minisign" <<'EOF'
#!/usr/bin/env bash
echo "minisign $*" >>"$STUB_LOG"
pub=""; sec=""
while (($#)); do
  case "$1" in
    -p) pub=$2; shift 2 ;;
    -s) sec=$2; shift 2 ;;
    *) shift ;;
  esac
done
read -r pw1; read -r pw2
[[ $pw1 == "$pw2" ]] || { echo "Passwords don't match" >&2; exit 1; }
printf 'untrusted comment: minisign public key FAKE\nRWQFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEF\n' >"$pub"
printf 'untrusted comment: minisign encrypted secret key\nSECRETSECRET\n' >"$sec"
EOF
  cat >"$bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >>"$STUB_LOG"
if [[ $1 == secret && $2 == set ]]; then
  cat >"$BATS_TEST_TMPDIR/secret.$3"
fi
EOF
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

run_setup() {
  printf '%s\n%s\n' "$MINISIGN_PASSWORD_INPUT" "$MINISIGN_PASSWORD_INPUT" | "$SCRIPT"
}

@test "generates the keypair outside the repo and commits only the public half" {
  run run_setup
  assert_success
  assert [ -e "$KEYDIR/autarchy.key" ]
  assert [ -e "$KEYDIR/autarchy.pub" ]
  run cat "$REPO/system/autarchy/release.pub"
  assert_line --index 0 --partial "untrusted comment:"
  assert_line --index 1 "RWQFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEF"
  run find "$REPO" -name '*.key'
  assert_output ""
}

@test "stores the secret key and the password as repository secrets, from stdin, never as arguments" {
  run run_setup
  assert_success
  run calls
  assert_line "gh secret set MINISIGN_SECRET_KEY"
  assert_line "gh secret set MINISIGN_PASSWORD"
  refute_output --partial "hunter22"
  refute_output --partial "SECRETSECRET"
  assert_equal "$(cat "$BATS_TEST_TMPDIR/secret.MINISIGN_PASSWORD")" "hunter22"
  run cat "$BATS_TEST_TMPDIR/secret.MINISIGN_SECRET_KEY"
  assert_output --partial "SECRETSECRET"
}

@test "refuses to overwrite an existing secret key (a second run would orphan every signed release)" {
  run_setup >/dev/null
  : >"$STUB_LOG"
  run run_setup
  assert_failure
  assert_output --partial "already exists"
  run calls
  refute_output --partial "minisign -G"
}

@test "the secret key file is readable by its owner only" {
  run run_setup
  assert_success
  run stat -c %a "$KEYDIR/autarchy.key"
  assert_output "600"
}

@test "says what to do next: commit the public key, then tag" {
  run run_setup
  assert_success
  assert_output --partial "system/autarchy/release.pub"
  assert_output --partial "git add"
}
