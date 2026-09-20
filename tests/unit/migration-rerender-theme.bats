#!/usr/bin/env bats
# Unit tests for the Phase 17 migration that re-renders the matugen palette so
# ~/.config/waybar/colors.css gains @error. matugen is stubbed; HOME is a temp dir.

setup() {
  load '../helpers/common'
  SCRIPT=$(ls "$REPO_ROOT"/migrations/*-rerender-theme-for-waybar-error-color.sh)
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  mkdir -p "$HOME/.config/waybar" "$BATS_TEST_TMPDIR/bin"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "matugen $*" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/matugen"
  chmod +x "$BATS_TEST_TMPDIR/bin/matugen"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "re-renders from the current wallpaper when colors.css predates @error" {
  printf '@define-color background #000000;\n' >"$HOME/.config/waybar/colors.css"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output "matugen --config $HOME/.config/matugen/config.toml image $HOME/.local/share/backgrounds/current.png --source-color-index 0"
}

@test "does nothing when colors.css already defines @error" {
  printf '@define-color error #ff0000;\n' >"$HOME/.config/waybar/colors.css"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}

@test "does nothing on a machine that was never themed (first-login renders it)" {
  rm -rf "$HOME/.config/waybar"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}
