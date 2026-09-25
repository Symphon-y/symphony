#!/usr/bin/env bats
# Unit tests for scripts/lib/wallpaper.bash: the one home for where a wallpaper lives
# (D-0086) and for hyprpaper's config shape (D-0085). Four callers source it -- both
# wallpaper-* scripts, install/link-home and install/first-login -- so the paths are
# stated once here and nowhere else.
#
# XDG_CONFIG_HOME is unset in setup: this session exports the real one, and a test that
# read the developer's own user-dirs.dirs would pass or fail by accident.

setup() {
  load '../helpers/common'
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config"
  unset XDG_CONFIG_HOME
  # shellcheck source-path=SCRIPTDIR source=../../scripts/lib/wallpaper.bash
  source "$REPO_ROOT/scripts/lib/wallpaper.bash"
}

# --- where things live --------------------------------------------------------------

@test "the library is a Wallpapers folder inside XDG's pictures directory" {
  run wallpaper_library
  assert_output "$HOME/Pictures/Wallpapers"
}

@test "a relocated pictures directory takes the library with it" {
  # xdg-user-dir is stubbed, not exercised: the contract under test is that we ask it
  # and honour the answer. CI has no xdg-user-dirs installed, which is what the
  # fallback tests below cover.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\necho "%s/Photos"\n' "$HOME" >"$BATS_TEST_TMPDIR/bin/xdg-user-dir"
  chmod +x "$BATS_TEST_TMPDIR/bin/xdg-user-dir"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run wallpaper_library
  assert_output "$HOME/Photos/Wallpapers"
}

@test "a fresh account with no user-dirs.dirs yet still gets ~/Pictures/Wallpapers" {
  # What the real xdg-user-dir prints for a key it has no answer for, which would
  # otherwise put the library straight in the home directory.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$HOME" >"$BATS_TEST_TMPDIR/bin/xdg-user-dir"
  chmod +x "$BATS_TEST_TMPDIR/bin/xdg-user-dir"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run wallpaper_library
  assert_output "$HOME/Pictures/Wallpapers"
}

@test "without xdg-user-dir installed at all, the library is still ~/Pictures/Wallpapers" {
  mkdir -p "$BATS_TEST_TMPDIR/empty-bin"
  PATH="$BATS_TEST_TMPDIR/empty-bin" run wallpaper_library
  assert_output "$HOME/Pictures/Wallpapers"
}

@test "the pointer at what is showing is state, beside the other symphony state" {
  run wallpaper_pointer
  assert_output "$HOME/.local/state/symphony/wallpaper"
}

@test "the pointer has no extension: matugen reads the image, not the name" {
  run basename "$(wallpaper_pointer)"
  assert_output "wallpaper"
}

@test "the shipped default is a payload asset under ~/.local/share/symphony" {
  run wallpaper_default
  assert_output "$HOME/.local/share/symphony/default-wallpaper.png"
}

# --- hyprpaper's config shape ---------------------------------------------------------

@test "hyprpaper_config emits the block syntax naming the given image" {
  run hyprpaper_config /photos/dune.jpg
  assert_success
  assert_line "wallpaper {"
  assert_line "  monitor = *"
  assert_line "  path = /photos/dune.jpg"
  assert_line "  fit_mode = cover"
  assert_line "ipc = on"
  assert_line "splash = false"
}

@test "hyprpaper_config says the file is generated, so nobody edits it by hand" {
  run hyprpaper_config /photos/dune.jpg
  assert_output --partial "Generated"
  assert_output --partial "wallpaper-set"
}

@test "a path with spaces reaches the config whole" {
  run hyprpaper_config "/mnt/Photography Exports/The Frame/DSC06258.png"
  assert_line "  path = /mnt/Photography Exports/The Frame/DSC06258.png"
}
