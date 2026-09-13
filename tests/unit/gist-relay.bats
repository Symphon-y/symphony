#!/usr/bin/env bats
# Unit tests for scripts/gist-relay, which moves short-lived text (a login URL out, a
# one-time code in) between the VM console and another machine using a secret gist.
#
# gh and tmux are stubbed.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/gist-relay"
  export RELAY_TMP="$BATS_TEST_TMPDIR"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export STUB_CONTENT="one-time-code-4f9a#state-7c21"

  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"

  cat >"$bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >>"$STUB_LOG"
if [[ $1 == gist && $2 == create ]]; then
  cat >"$RELAY_TMP/gist-body"
  echo "https://gist.github.com/travis/${STUB_GIST_ID-abc123}"
elif [[ $1 == gist && $2 == delete ]]; then
  :
elif [[ $1 == api && $2 == gists ]]; then
  echo "${STUB_GIST_ID-abc123}"
elif [[ $1 == api && $2 == gists/* ]]; then
  printf '%s\n' "$STUB_CONTENT"
else
  exit 1
fi
EOF

  cat >"$bin/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >>"$STUB_LOG"
case "$1" in
  capture-pane) printf '%s\n' "${STUB_PANE:-Open this URL: https://claude.ai/oauth/authorize?code=true}" ;;
  load-buffer) cat >"$RELAY_TMP/tmux-buffer"; exit "${STUB_TMUX_RC:-0}" ;;
esac
EOF

  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "fails with usage when no command is given" {
  run "$SCRIPT"
  assert_failure 2
  assert_output --partial "usage"
}

@test "send-pane uploads the pane text as a secret relay gist and prints its id" {
  run "$SCRIPT" send-pane 0
  assert_success
  assert_output --partial "abc123"
  run calls
  assert_line --partial "tmux capture-pane"
  assert_line "gh gist create --desc autarchy-relay -"
  refute_output --partial "--public"
  run cat "$RELAY_TMP/gist-body"
  assert_output --partial "https://claude.ai/oauth/authorize"
}

@test "receive loads the newest relay gist into the tmux paste buffer and deletes it" {
  run "$SCRIPT" receive
  assert_success
  run cat "$RELAY_TMP/tmux-buffer"
  assert_output "$STUB_CONTENT"
  run calls
  assert_line "gh gist delete abc123 --yes"
}

@test "receive never prints the relayed content" {
  run "$SCRIPT" receive
  assert_success
  refute_output --partial "$STUB_CONTENT"
  assert_output --partial "${#STUB_CONTENT}"
}

@test "receive deletes the gist even when loading into tmux fails" {
  export STUB_TMUX_RC=1
  run "$SCRIPT" receive
  assert_failure
  run calls
  assert_line "gh gist delete abc123 --yes"
}

@test "receive fails without deleting anything when there is no relay gist" {
  export STUB_GIST_ID=""
  run "$SCRIPT" receive
  assert_failure
  assert_output --partial "no relay gist"
  run calls
  refute_output --partial "gist delete"
}
