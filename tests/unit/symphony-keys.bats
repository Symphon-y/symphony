#!/usr/bin/env bats
# Unit tests for home/hypr/dot-local/bin/symphony-keys (Task F, #17): the cheatsheet on
# SUPER+K.
#
# The rows come from keymap/cheatsheet.lua, tested separately; what is tested here is the
# rendering -- that the list reaches fuzzel in a window wide enough to read, that nothing
# runs when a row is selected (that is #18, deliberately deferred), and that a keybinding
# with no terminal can still open the reference.
#
# fuzzel, xdg-terminal-exec and the pager are stubs on PATH. `lua` is real: the keymap
# modules are pure, so there is nothing to fake.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/hypr/dot-local/bin/symphony-keys"
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  # The keymap Hyprland would load, and a home with no overrides.
  export SYMPHONY_HYPR_DIR="$REPO_ROOT/home/hypr/dot-config/hypr"
  export SYMPHONY_CONFIG_DIR="$HOME/.config/symphony"
  mkdir -p "$SYMPHONY_CONFIG_DIR" "$BATS_TEST_TMPDIR/bin"
  : >"$STUB_LOG"
  # fuzzel records its arguments and what it was fed, and answers with a selection, so a
  # test can prove the selection is ignored.
  cat >"$BATS_TEST_TMPDIR/bin/fuzzel" <<'EOF'
#!/usr/bin/env bash
echo "fuzzel $*" >>"$STUB_LOG"
cat >"$STUB_LOG.stdin"
echo "SUPER + Q  Close window"
EOF
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "xdg-terminal-exec $*" >>"$STUB_LOG"\n' \
    >"$BATS_TEST_TMPDIR/bin/xdg-terminal-exec"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "pager $*" >>"$STUB_LOG"\n' \
    >"$BATS_TEST_TMPDIR/bin/fake-pager"
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export PAGER=fake-pager
}

calls() {
  cat "$STUB_LOG"
}

shown() {
  cat "$STUB_LOG.stdin"
}

# --- the list -------------------------------------------------------------------------

@test "text prints every binding with what it does" {
  run "$SCRIPT" text
  assert_success
  assert_output --partial "SUPER + Return"
  assert_output --partial "Terminal"
  assert_output --partial "Workspace 3"
  assert_output --partial "Keyboard light up"
}

@test "the list and the text are the same rows, so the two cannot disagree" {
  run bash -c "diff <(\"$SCRIPT\" text) <(\"$SCRIPT\" list >/dev/null; cat '$STUB_LOG.stdin')"
  assert_success
}

@test "list feeds the same rows to fuzzel" {
  run "$SCRIPT" list
  assert_success
  run calls
  assert_output --partial "fuzzel"
  assert_output --partial "--dmenu"
  run shown
  assert_output --partial "SUPER + Return"
}

@test "the window is wider than the launcher's, since these rows are long" {
  # The matugen template sizes fuzzel as a launcher: width=40, lines=8. A cheatsheet
  # needs more of both, passed at the call site rather than by changing the theme.
  run "$SCRIPT" list
  assert_success
  run calls
  assert_output --regexp "--width[= ]+(4[1-9]|[5-9][0-9]|[0-9]{3,})"
  assert_output --regexp "--lines[= ]+([9]|[1-9][0-9]+)"
}

@test "bare symphony-keys is the list, because that is what the keybinding calls" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "fuzzel"
}

@test "selecting a row runs nothing: this is a reference, not a launcher (#18)" {
  # The fuzzel stub answers with a row. Nothing may act on it -- making a row runnable is
  # a separate decision, deliberately left until the plain list has been lived with.
  run "$SCRIPT" list
  assert_success
  run bash -c "grep -cv '^fuzzel ' '$STUB_LOG' || true"
  assert_output "0"
}

# --- the user's own keymap ------------------------------------------------------------

@test "the list shows the user's overrides, not the shipped defaults" {
  printf 'return { global = { ["SUPER + Return"] = "window.close" } }\n' \
    >"$SYMPHONY_CONFIG_DIR/keymap.lua"
  run "$SCRIPT" text
  assert_success
  assert_line --regexp "^SUPER \+ Return +Close window$"
}

@test "a broken user keymap still gets you a list, and says what went wrong" {
  printf 'return { this is not lua\n' >"$SYMPHONY_CONFIG_DIR/keymap.lua"
  run --separate-stderr "$SCRIPT" text
  assert_success
  assert_output --partial "SUPER + Return"
  [[ $stderr == *"keymap.lua"* ]]
}

# --- the reference --------------------------------------------------------------------

@test "defaults opens the reference in a pager when there is a terminal" {
  run script -qec "'$SCRIPT' defaults" /dev/null
  assert_success
  run calls
  assert_output --partial "pager $SYMPHONY_HYPR_DIR/keymap/defaults.lua"
}

@test "defaults from a keybinding, with no terminal, opens one" {
  run "$SCRIPT" defaults
  assert_success
  run calls
  assert_output --partial "xdg-terminal-exec"
  assert_output --partial "keymap/defaults.lua"
}

# --- when things are missing ----------------------------------------------------------

@test "no fuzzel installed is reported, not silent: a keybinding shows nothing either way" {
  mkdir -p "$BATS_TEST_TMPDIR/nobin"
  local tool
  for tool in bash lua awk cat; do
    ln -s "$(command -v "$tool")" "$BATS_TEST_TMPDIR/nobin/$tool"
  done
  run --separate-stderr env PATH="$BATS_TEST_TMPDIR/nobin" "$SCRIPT" list
  assert_failure
  [[ $stderr == *"fuzzel"* ]]
}

@test "an unknown verb is a usage error" {
  run "$SCRIPT" explain
  assert_failure
  assert_output --partial "usage"
  run calls
  assert_output ""
}
