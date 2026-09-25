#!/usr/bin/env bats
# Unit tests for the migration that moves wallpapers to ~/Pictures/Wallpapers and the
# pointer to ~/.local/state/symphony/wallpaper (D-0086). An installed machine has its
# library, its pointer and a shipped asset all in ~/.local/share/backgrounds; afterwards
# that directory is gone.
#
# wallpaper-set is stubbed: it is the one thing that knows how to write the new pointer,
# the hyprpaper config and the palette, and the migration must go through it rather than
# repeat any of that.

setup() {
  load '../helpers/common'
  SCRIPT=$(ls "$REPO_ROOT"/migrations/*-wallpaper-library.sh)
  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_CONFIG_HOME
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"

  OLD="$HOME/.local/share/backgrounds"
  LIBRARY="$HOME/Pictures/Wallpapers"
  DEFAULT="$HOME/.local/share/symphony/default-wallpaper.png"
  mkdir -p "$OLD" "$HOME/.local/bin" "$(dirname "$DEFAULT")"
  : >"$DEFAULT"

  # shellcheck disable=SC2016 # the stub body expands when the stub runs
  printf '#!/usr/bin/env bash\nprintf "wallpaper-set %%s\\n" "$1" >>"$STUB_LOG"\n' \
    >"$HOME/.local/bin/wallpaper-set"
  chmod +x "$HOME/.local/bin/wallpaper-set"

  CHOSEN="$BATS_TEST_TMPDIR/chosen.jpg"
  : >"$CHOSEN"
}

# The shape an installed machine is in before this runs.
installed() {
  ln -sfn "${1:-$CHOSEN}" "$OLD/current.png"
}

calls() {
  cat "$STUB_LOG"
}

@test "hands the wallpaper that was showing to wallpaper-set, which writes the new pointer" {
  installed
  run "$SCRIPT"
  assert_success
  run calls
  assert_output "wallpaper-set $CHOSEN"
}

@test "moves the user's own images into the library" {
  installed
  : >"$OLD/sunset.jpg"
  : >"$OLD/mountains.PNG"
  run "$SCRIPT"
  assert_success
  assert [ -f "$LIBRARY/sunset.jpg" ]
  assert [ -f "$LIBRARY/mountains.PNG" ]
}

@test "a name already taken in the library is kept, not silently overwritten" {
  installed
  mkdir -p "$LIBRARY"
  echo "the one I want" >"$LIBRARY/sunset.jpg"
  echo "the old one" >"$OLD/sunset.jpg"
  run "$SCRIPT"
  assert_success
  run cat "$LIBRARY/sunset.jpg"
  assert_output "the one I want"
}

@test "falls back to the shipped default when the old choice no longer resolves" {
  # Exactly the live state while the SMB share holding the photos is unmounted.
  installed "$BATS_TEST_TMPDIR/gone-with-the-nas.png"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output "wallpaper-set $DEFAULT"
}

@test "the old directory is gone afterwards, including the stale payload link" {
  installed
  ln -s "$BATS_TEST_TMPDIR/payload-default.png" "$OLD/default.png"
  run "$SCRIPT"
  assert_success
  assert [ ! -e "$OLD" ]
}

@test "anything unrecognised is left in place and reported, never thrown away" {
  installed
  echo "notes" >"$OLD/notes.txt"
  run "$SCRIPT"
  assert_success
  assert [ -f "$OLD/notes.txt" ]
  assert_output --partial "$OLD"
}

@test "is a no-op on a machine that has already moved, and on a second run" {
  installed
  run "$SCRIPT"
  assert_success
  : >"$STUB_LOG"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}

@test "is a no-op on a fresh install, which never had the old directory" {
  rm -rf "$OLD"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}
