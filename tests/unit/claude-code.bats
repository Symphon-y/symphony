#!/usr/bin/env bats
# Unit tests for install/claude-code, which installs Claude Code only after checking
# the release manifest's GPG signature and the binary's SHA256.
#
# Network and crypto tools (curl, gpg, sha256sum) and uname/id are stubbed. The
# manifest is a real JSON fixture parsed by the real jq.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/claude-code"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export FIXTURES="$BATS_TEST_TMPDIR/fixtures"
  mkdir -p "$FIXTURES"

  GOOD_SHA=$(printf 'a%.0s' $(seq 64))
  export GOOD_SHA
  printf '{"version":"2.1.236","platforms":{"linux-x64":{"checksum":"%s","size":1},"linux-arm64":{"checksum":"%s","size":1}}}\n' \
    "$GOOD_SHA" "$(printf 'b%.0s' $(seq 64))" >"$FIXTURES/manifest.json"

  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"

  # curl [flags] [-o FILE] URL: serves fixtures by URL suffix.
  cat >"$bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >>"$STUB_LOG"
out="" url=""
while (($#)); do
  case "$1" in
    -o) out=$2; shift 2 ;;
    --proto) shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
emit() { if [[ -n $out ]]; then cat >"$out"; else cat; fi; }
case "$url" in
  */stable) printf '%s\n' "${STUB_STABLE:-2.1.236}" | emit ;;
  */manifest.json) emit <"$FIXTURES/manifest.json" ;;
  */manifest.json.sig) echo "signature" | emit ;;
  */claude-code.asc) echo "public key" | emit ;;
  */linux-x64/claude) printf '#!/usr/bin/env bash\necho "downloaded-claude $*" >>"$STUB_LOG"\n' | emit ;;
  *) echo "unexpected url: $url" >&2; exit 22 ;;
esac
EOF

  # gpg: --verify reports a valid signature by STUB_SIG_FPR, exiting STUB_GPG_RC.
  cat >"$bin/gpg" <<'EOF'
#!/usr/bin/env bash
echo "gpg $*" >>"$STUB_LOG"
if [[ " $* " == *" --verify "* ]]; then
  fpr=${STUB_SIG_FPR:-31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE}
  echo "[GNUPG:] VALIDSIG $fpr 2026-09-01 1788000000 0 4 0 1 10 00 $fpr"
  exit "${STUB_GPG_RC:-0}"
fi
EOF

  printf '#!/usr/bin/env bash\n%s\n' 'echo "${STUB_SHA:-$GOOD_SHA}  $1"' >"$bin/sha256sum"
  printf '#!/usr/bin/env bash\n%s\n' 'if [[ ${1:-} == -m ]]; then echo "${STUB_ARCH:-x86_64}"; else exec /usr/bin/uname "$@"; fi' >"$bin/uname"
  printf '#!/usr/bin/env bash\n%s\n' 'if [[ ${1:-} == -u ]]; then echo "${STUB_UID:-1000}"; else exec /usr/bin/id "$@"; fi' >"$bin/id"
  printf '#!/usr/bin/env bash\n%s\n' 'echo "2.1.236 (Claude Code)"' >"$bin/claude"

  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

installed_version_file() {
  mkdir -p "$HOME/.local/share/claude/versions"
  echo "binary" >"$HOME/.local/share/claude/versions/2.1.236"
}

@test "fails with usage when no command is given" {
  run "$SCRIPT"
  assert_failure 2
  assert_output --partial "usage"
}

@test "install verifies the signed manifest and checksum, then runs claude install stable" {
  run "$SCRIPT" install
  assert_success
  run calls
  assert_line --partial "--verify"
  assert_line "downloaded-claude install stable"
}

@test "install downloads only over HTTPS" {
  run "$SCRIPT" install
  assert_success
  run grep -c '^curl ' "$STUB_LOG"
  refute_output "0"
  # Every curl call carries --proto =https, so redirects can't downgrade to http.
  run grep -vc -- '--proto =https' <(grep '^curl ' "$STUB_LOG")
  assert_output "0"
}

@test "install refuses a manifest signed by a different key" {
  export STUB_SIG_FPR=0000000000000000000000000000000000000000
  run "$SCRIPT" install
  assert_failure
  assert_output --partial "signature"
  run calls
  refute_line "downloaded-claude install stable"
}

@test "install refuses a manifest whose signature does not verify" {
  export STUB_GPG_RC=1
  run "$SCRIPT" install
  assert_failure
  assert_output --partial "signature"
  run calls
  refute_line "downloaded-claude install stable"
}

@test "install refuses a binary whose checksum does not match the manifest" {
  export STUB_SHA
  STUB_SHA=$(printf 'c%.0s' $(seq 64))
  run "$SCRIPT" install
  assert_failure
  assert_output --partial "checksum"
  run calls
  refute_line "downloaded-claude install stable"
}

@test "install rejects a stable pointer that is not a version number" {
  export STUB_STABLE="<html>error</html>"
  run "$SCRIPT" install
  assert_failure
  assert_output --partial "version"
}

@test "install picks the arm64 binary on aarch64 machines" {
  # The curl stub only serves the x64 binary, so this run stops at the download;
  # the point is which URL it asked for.
  export STUB_ARCH=aarch64
  run "$SCRIPT" install
  assert_failure
  run calls
  assert_line --partial "linux-arm64/claude"
}

@test "install refuses to run as root" {
  export STUB_UID=0
  run "$SCRIPT" install
  assert_failure
  assert_output --partial "root"
  run calls
  refute_output --partial "curl"
}

@test "verify passes when the installed binary matches its signed manifest" {
  installed_version_file
  run "$SCRIPT" verify
  assert_success
  assert_output --partial "2.1.236"
}

@test "verify fails when the installed binary does not match its manifest" {
  installed_version_file
  export STUB_SHA
  STUB_SHA=$(printf 'd%.0s' $(seq 64))
  run "$SCRIPT" verify
  assert_failure
  assert_output --partial "checksum"
}

@test "verify fails when the installed version file is missing" {
  run "$SCRIPT" verify
  assert_failure
  assert_output --partial "2.1.236"
}
