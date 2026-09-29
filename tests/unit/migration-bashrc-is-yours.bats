#!/usr/bin/env bats
# Unit tests for the migration that hands ~/.bashrc back to the user (D-0095, #31).
#
# It was a stow link into the root-owned payload, so editing it needed sudo -- and a sudo
# edit lives inside the payload, which the next deploy replaces wholesale. symphony's
# shell config is ~/.config/bash/symphony.bash now; ~/.bashrc is a real file that sources
# it. stow cannot tidy the old link: `--restow` unlinks what is *in* the package, so a
# file deleted from the payload leaves its symlink behind.

# For `run --separate-stderr`, which the advisory-on-stderr tests below rely on.
bats_require_minimum_version 1.5.0

setup() {
  load '../helpers/common'
  SCRIPT=$(ls "$REPO_ROOT"/migrations/*-bashrc-is-yours.sh)
  export HOME="$BATS_TEST_TMPDIR/home"
  BASHRC="$HOME/.bashrc"
  mkdir -p "$HOME"
}

@test "replaces the link left dangling by the deleted payload file" {
  ln -s "$BATS_TEST_TMPDIR/payload/home/bash/dot-bashrc" "$BASHRC"
  run "$SCRIPT"
  assert_success
  assert [ -f "$BASHRC" ]
  assert [ ! -L "$BASHRC" ]
  assert_output --partial "yours"
  run cat "$BASHRC"
  assert_output --partial ".config/bash/symphony.bash"
  assert_output --partial '[[ $- != *i* ]] && return'
}

@test "a link that still resolves is replaced too: it must stop being a link" {
  # Deliberately unlike the hypr-bindings migration, where a resolving link meant "the
  # payload has not swapped, do not guess". Here the target is symphony's own former
  # dot-bashrc in either payload, and the whole point of D-0095 is that this path stops
  # being a link -- so the guard is `-L` alone, which converges on a machine whose
  # ordering was unusual.
  mkdir -p "$BATS_TEST_TMPDIR/payload"
  echo "# the old payload copy" >"$BATS_TEST_TMPDIR/payload/dot-bashrc"
  ln -s "$BATS_TEST_TMPDIR/payload/dot-bashrc" "$BASHRC"
  run "$SCRIPT"
  assert_success
  assert [ -f "$BASHRC" ]
  assert [ ! -L "$BASHRC" ]
  run cat "$BASHRC"
  assert_output --partial ".config/bash/symphony.bash"
}

@test "writes the real file rather than through the link, which would land in the payload" {
  local payload="$BATS_TEST_TMPDIR/payload/home/bash"
  mkdir -p "$payload"
  ln -s "$payload/dot-bashrc" "$BASHRC"
  run "$SCRIPT"
  assert_success
  assert [ ! -e "$payload/dot-bashrc" ]
}

@test "a .bashrc that already sources symphony's config is left alone, and says nothing" {
  # A fresh install runs every historical migration on its first update: nothing marks
  # them as done, and install/link-home has already seeded this file.
  cat >"$BASHRC" <<'SEEDED'
[[ $- != *i* ]] && return
[[ -r ~/.config/bash/symphony.bash ]] && source ~/.config/bash/symphony.bash
SEEDED
  run --separate-stderr "$SCRIPT"
  assert_success
  assert_output ""
  [[ -z $stderr ]]
  run cat "$BASHRC"
  assert_output --partial "symphony.bash"
}

@test "a .bashrc of the user's own is kept, and they are told how to pick symphony's config up" {
  echo "# my own shell" >"$BASHRC"
  run --separate-stderr "$SCRIPT"
  assert_success
  # Before the next `run`, which would reset $stderr.
  [[ $stderr == *"left alone"* ]]
  [[ $stderr == *".config/bash/symphony.bash"* ]]
  run cat "$BASHRC"
  assert_output "# my own shell"
}

@test "is a no-op with nothing there, and on a second run" {
  # Creating it from nothing is install/link-home's job, which has already run.
  run "$SCRIPT"
  assert_success
  assert [ ! -e "$BASHRC" ]

  ln -s "$BATS_TEST_TMPDIR/gone" "$BASHRC"
  run "$SCRIPT"
  assert_success
  run "$SCRIPT"
  assert_success
  assert_output ""
  assert [ -f "$BASHRC" ]
  assert [ ! -L "$BASHRC" ]
}

@test "the text it writes agrees with install/seed/bashrc where it matters" {
  # The migration spells the file out instead of reading the payload's template, because
  # a migration records what was true when it ran (see the wallpaper-library migration).
  # Byte equality is not the contract -- the seed may grow commentary, the migration must
  # not change at all -- so pin the two lines that decide whether a shell works.
  local seed="$REPO_ROOT/install/seed/bashrc"
  local line
  for line in '.config/bash/symphony.bash' '[[ $- != *i* ]] && return'; do
    run grep -qF "$line" "$seed"
    assert_success
    run grep -qF "$line" "$SCRIPT"
    assert_success
  done
}
