#!/usr/bin/env bats
# Unit tests for install/link-home, which links the stow packages under home/ into
# the home directory.
#
# Runs a copy of the script against a throwaway repo with fixture packages (a plain
# dotfile and a nested config directory), so the tests don't depend on which real
# packages exist. HOME is a temp directory. stow is stubbed for apply; check inspects
# real links that each test creates.

setup() {
  load '../helpers/common'
  REPO_COPY="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_COPY/install" "$REPO_COPY/scripts" "$REPO_COPY/home/shell" "$REPO_COPY/home/app/dot-config/app"
  cp "$REPO_ROOT/install/link-home" "$REPO_COPY/install/"
  cp -R "$REPO_ROOT/scripts/lib" "$REPO_COPY/scripts/"
  echo "# fixture" >"$REPO_COPY/home/shell/dot-profile"
  echo "# fixture" >"$REPO_COPY/home/app/dot-config/app/config.toml"
  SCRIPT="$REPO_COPY/install/link-home"

  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_CONFIG_HOME
  mkdir -p "$HOME"
  DEFAULT="$REPO_COPY/home/hyprpaper/dot-local/share/symphony/default-wallpaper.png"
  LIBRARY="$HOME/Pictures/Wallpapers"
  POINTER="$HOME/.local/state/symphony/wallpaper"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"

  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\n%s\n' 'echo "stow $*" >>"$STUB_LOG"; exit "${STUB_STOW_RC:-0}"' >"$bin/stow"
  chmod +x "$bin/stow"
  PATH="$bin:$PATH"
}

# Link every fixture file the way stow --dotfiles would: dot-x path parts become .x.
link_all() {
  local file rel path target
  while IFS= read -r file; do
    rel=${file#"$REPO_COPY/home/"}
    path=${rel#*/}
    target="$HOME/$(sed -E 's#(^|/)dot-#\1.#g' <<<"$path")"
    mkdir -p "$(dirname "$target")"
    ln -s "$file" "$target"
  done < <(find "$REPO_COPY/home" -type f)
}

# --- seeding (a fresh home has no wallpaper, no library and no hyprpaper config) -----

# The shipped default, where the stow package keeps it (D-0086).
seed_default() {
  mkdir -p "$(dirname "$DEFAULT")"
  : >"$DEFAULT"
}

@test "apply seeds the wallpaper library so SUPER+CTRL+W has something to choose" {
  seed_default
  run "$SCRIPT" apply
  assert_success
  assert [ -d "$LIBRARY" ]
  assert_equal "$(readlink -f "$LIBRARY/symphony-default.png")" "$DEFAULT"
}

@test "apply seeds the pointer and hyprpaper.conf so the first login has a wallpaper" {
  seed_default
  run "$SCRIPT" apply
  assert_success
  assert [ -L "$POINTER" ]
  assert_equal "$(readlink -f "$POINTER")" "$DEFAULT"
  run cat "$HOME/.config/hypr/hyprpaper.conf"
  assert_output --partial "wallpaper {"
  assert_output --partial "path = $POINTER"
}

@test "apply never overwrites a wallpaper, a library entry or a config the user already has" {
  seed_default
  mkdir -p "$(dirname "$POINTER")" "$LIBRARY" "$HOME/.config/hypr"
  : >"$BATS_TEST_TMPDIR/chosen.jpg"
  ln -s "$BATS_TEST_TMPDIR/chosen.jpg" "$POINTER"
  echo "# not a link" >"$LIBRARY/symphony-default.png"
  echo "# mine" >"$HOME/.config/hypr/hyprpaper.conf"
  run "$SCRIPT" apply
  assert_success
  assert_equal "$(readlink -f "$POINTER")" "$BATS_TEST_TMPDIR/chosen.jpg"
  run cat "$LIBRARY/symphony-default.png"
  assert_output "# not a link"
  run cat "$HOME/.config/hypr/hyprpaper.conf"
  assert_output "# mine"
}

@test "apply leaves the old backgrounds directory uncreated (D-0086)" {
  seed_default
  run "$SCRIPT" apply
  assert_success
  assert [ ! -e "$HOME/.local/share/backgrounds" ]
}

@test "fails with usage when no command is given" {
  run "$SCRIPT"
  assert_failure 2
  assert_output --partial "usage"
}

@test "apply stows every package under home/ with dotfiles and no folding" {
  run "$SCRIPT" apply
  assert_success
  run cat "$STUB_LOG"
  assert_line "stow --dir=$REPO_COPY/home --target=$HOME --dotfiles --no-folding --restow app shell"
}

@test "apply fails when stow reports a conflict" {
  export STUB_STOW_RC=1
  run "$SCRIPT" apply
  assert_failure
}

@test "check lists files that are not linked" {
  run "$SCRIPT" check
  assert_failure 1
  assert_line "not linked: .profile"
  assert_line "not linked: .config/app/config.toml"
}

@test "check passes when every file is linked" {
  link_all
  run "$SCRIPT" check
  assert_success
}

@test "check fails when a linked file was replaced by a regular file" {
  link_all
  rm "$HOME/.profile"
  echo "# edited by hand" >"$HOME/.profile"
  run "$SCRIPT" check
  assert_failure 1
  assert_line "not linked: .profile"
}

@test "check fails when a directory is folded into a link to the repo" {
  ln -s "$REPO_COPY/home/app/dot-config" "$HOME/.config"
  ln -s "$REPO_COPY/home/shell/dot-profile" "$HOME/.profile"
  run "$SCRIPT" check
  assert_failure 1
  assert_line "folded: .config"
}
