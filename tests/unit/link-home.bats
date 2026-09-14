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
  mkdir -p "$REPO_COPY/install" "$REPO_COPY/home/shell" "$REPO_COPY/home/app/dot-config/app"
  cp "$REPO_ROOT/install/link-home" "$REPO_COPY/install/"
  echo "# fixture" >"$REPO_COPY/home/shell/dot-profile"
  echo "# fixture" >"$REPO_COPY/home/app/dot-config/app/config.toml"
  SCRIPT="$REPO_COPY/install/link-home"

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
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
