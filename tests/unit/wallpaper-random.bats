#!/usr/bin/env bats
# Unit tests for home/hyprpaper/dot-local/bin/wallpaper-random: pick an image from a
# directory and hand it to wallpaper-set (which is stubbed here).

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/hyprpaper/dot-local/bin/wallpaper-random"
  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_CONFIG_HOME
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  DIR="$BATS_TEST_TMPDIR/walls"
  LIBRARY="$HOME/Pictures/Wallpapers"
  POINTER="$HOME/.local/state/symphony/wallpaper"
  mkdir -p "$DIR" "$LIBRARY" "$(dirname "$POINTER")" "$BATS_TEST_TMPDIR/bin"
  # shellcheck disable=SC2016 # stub bodies expand when the stubs run
  printf '#!/usr/bin/env bash\nprintf "wallpaper-set %%s\\n" "$1" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/wallpaper-set"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\necho "notify-send $*" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/notify-send"
  chmod +x "$BATS_TEST_TMPDIR/bin/wallpaper-set" "$BATS_TEST_TMPDIR/bin/notify-send"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "hands one image from the given directory to wallpaper-set" {
  : >"$DIR/a.jpg"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/a.jpg"
}

@test "picks only images, not other files" {
  : >"$DIR/notes.txt"
  : >"$DIR/a.png"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/a.png"
}

@test "a filename with spaces reaches wallpaper-set whole" {
  : >"$DIR/The Frame 01.jpg"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/The Frame 01.jpg"
}

# shellcheck disable=SC2034 # the loop counter is the repetition, not a value
@test "never picks the wallpaper already showing, so a small directory still changes" {
  : >"$DIR/a.jpg"
  : >"$DIR/b.jpg"
  ln -sfn "$DIR/a.jpg" "$POINTER"
  local _attempt
  for _attempt in 1 2 3 4 5 6; do
    : >"$STUB_LOG"
    run "$SCRIPT" "$DIR"
    assert_success
    run calls
    assert_output "wallpaper-set $DIR/b.jpg"
  done
}

@test "a directory with only the current wallpaper in it sets it again rather than failing" {
  : >"$DIR/only.jpg"
  ln -sfn "$DIR/only.jpg" "$POINTER"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/only.jpg"
}

@test "with no wallpaper set yet, every image is a candidate" {
  : >"$DIR/a.jpg"
  rm -f "$POINTER"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/a.jpg"
}

@test "an image reachable through a symlink counts: the library is seeded with one" {
  # install/link-home seeds symphony-default.png as a link into the payload, and a user
  # may link rather than copy their own photos -- so `find -type f` found nothing and
  # SUPER+CTRL+W silently did nothing.
  : >"$BATS_TEST_TMPDIR/real.png"
  ln -s "$BATS_TEST_TMPDIR/real.png" "$DIR/default.png"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/default.png"
}

@test "a file called current.png is an ordinary wallpaper now: the pointer lives elsewhere" {
  # It used to be skipped by name, because the pointer sat in the same directory.
  : >"$DIR/current.png"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/current.png"
}

@test "a failure is shown, not swallowed: a keybinding has nowhere to print" {
  run "$SCRIPT" "$DIR"
  assert_failure
  run calls
  assert_output --partial "notify-send"
  assert_output --partial "No wallpapers"
}

@test "an empty directory is a clear error, and nothing is set" {
  run "$SCRIPT" "$DIR"
  assert_failure
  assert_output --partial "no images"
  run calls
  refute_output --partial "wallpaper-set"
}

@test "a directory that does not exist is a clear error" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/nope"
  assert_failure
  run calls
  refute_output --partial "wallpaper-set"
}

@test "with no argument it uses ~/Pictures/Wallpapers, as SUPER+CTRL+W does (D-0086)" {
  # Exactly the shipped shape on a fresh install: the library holds one link into the
  # payload and the pointer names it. The binding must still find something to set.
  : >"$BATS_TEST_TMPDIR/payload-default.png"
  ln -s "$BATS_TEST_TMPDIR/payload-default.png" "$LIBRARY/symphony-default.png"
  ln -s "$BATS_TEST_TMPDIR/payload-default.png" "$POINTER"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output "wallpaper-set $LIBRARY/symphony-default.png"
}

@test "with no argument and an empty library, the error names the library" {
  run "$SCRIPT"
  assert_failure
  assert_output --partial "$LIBRARY"
}
