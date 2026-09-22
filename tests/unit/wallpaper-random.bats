#!/usr/bin/env bats
# Unit tests for home/hyprpaper/dot-local/bin/wallpaper-random: pick an image from a
# directory and hand it to wallpaper-set (which is stubbed here).

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/hyprpaper/dot-local/bin/wallpaper-random"
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  DIR="$BATS_TEST_TMPDIR/walls"
  mkdir -p "$DIR" "$HOME/.local/share/backgrounds" "$BATS_TEST_TMPDIR/bin"
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\nprintf "wallpaper-set %%s\\n" "$1" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/wallpaper-set"
  chmod +x "$BATS_TEST_TMPDIR/bin/wallpaper-set"
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
  ln -sfn "$DIR/a.jpg" "$HOME/.local/share/backgrounds/current.png"
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
  ln -sfn "$DIR/only.jpg" "$HOME/.local/share/backgrounds/current.png"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/only.jpg"
}

@test "with no wallpaper set yet, every image is a candidate" {
  : >"$DIR/a.jpg"
  rm -f "$HOME/.local/share/backgrounds/current.png"
  run "$SCRIPT" "$DIR"
  assert_success
  run calls
  assert_output "wallpaper-set $DIR/a.jpg"
}

@test "an empty directory is a clear error, and nothing is set" {
  run "$SCRIPT" "$DIR"
  assert_failure
  assert_output --partial "no images"
  run calls
  assert_output ""
}

@test "a directory that does not exist is a clear error" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/nope"
  assert_failure
  run calls
  assert_output ""
}

@test "with no argument it uses ~/.local/share/backgrounds" {
  : >"$HOME/.local/share/backgrounds/default.png"
  ln -s "$HOME/.local/share/backgrounds/default.png" "$HOME/.local/share/backgrounds/current.png"
  run "$SCRIPT"
  assert_success
  run calls
  # current.png is a symlink, never a candidate
  assert_output "wallpaper-set $HOME/.local/share/backgrounds/default.png"
}
