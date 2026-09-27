#!/usr/bin/env bats
# Unit tests for the migration that clears ~/.config/hypr/bindings.lua (#23).
#
# Every chord is a keymap entry now, so the file is gone from the payload -- and stow
# cannot tidy up after it: `--restow` unlinks what is *in* the package, so a file deleted
# from the payload leaves a dangling symlink in the home directory.

setup() {
  load '../helpers/common'
  SCRIPT=$(ls "$REPO_ROOT"/migrations/*-hypr-bindings-into-keymap.sh)
  export HOME="$BATS_TEST_TMPDIR/home"
  BINDINGS="$HOME/.config/hypr/bindings.lua"
  mkdir -p "$HOME/.config/hypr"
}

@test "removes the link left dangling by the deleted payload file" {
  ln -s "$BATS_TEST_TMPDIR/payload/home/hypr/dot-config/hypr/bindings.lua" "$BINDINGS"
  run "$SCRIPT"
  assert_success
  assert [ ! -e "$BINDINGS" ]
  assert [ ! -L "$BINDINGS" ]
  assert_output --partial "keymap/defaults.lua"
}

@test "a link that still resolves is left alone: it is not ours to judge" {
  # Belt and braces for a machine mid-deploy, where the payload has not been swapped yet.
  mkdir -p "$BATS_TEST_TMPDIR/payload"
  : >"$BATS_TEST_TMPDIR/payload/bindings.lua"
  ln -s "$BATS_TEST_TMPDIR/payload/bindings.lua" "$BINDINGS"
  run "$SCRIPT"
  assert_success
  assert [ -L "$BINDINGS" ]
}

@test "a real file is kept, and the person is told nothing loads it any more" {
  echo "-- my own bindings" >"$BINDINGS"
  run --separate-stderr "$SCRIPT"
  assert_success
  # Before the next `run`, which would reset $stderr.
  [[ $stderr == *"left alone"* ]]
  [[ $stderr == *"keymap.lua"* ]]
  run cat "$BINDINGS"
  assert_output "-- my own bindings"
}

@test "is a no-op with nothing there, and on a second run" {
  run "$SCRIPT"
  assert_success
  ln -s "$BATS_TEST_TMPDIR/gone" "$BINDINGS"
  run "$SCRIPT"
  assert_success
  run "$SCRIPT"
  assert_success
  assert [ ! -e "$BINDINGS" ]
}
