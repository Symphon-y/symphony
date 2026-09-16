#!/usr/bin/env bats
# Unit tests for install/install-packages. yay is stubbed so the tests control
# what "installed" means without touching real system state.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/install-packages"
  PKGS="$BATS_TEST_TMPDIR/packages"
  mkdir -p "$PKGS"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
}

fixture() {
  local path="$PKGS/$1"
  shift
  printf '%s\n' "$@" >"$path"
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
with_yay_stub() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\n%s\n' 'echo "yay $*" >>"$STUB_LOG"; exit 0' >"$bin/yay"
  chmod +x "$bin/yay"
  PATH="$bin:$PATH"
}

@test "fails clearly when yay isn't installed" {
  fixture base.txt "git"
  # A PATH with just enough to run the script's own #!/usr/bin/env bash shebang
  # (env, bash) but genuinely no yay -- the real system PATH always has yay
  # already installed on this VM, so excluding it takes a curated PATH, not an
  # empty one (which breaks even `env` finding `bash`).
  local no_yay_bin="$BATS_TEST_TMPDIR/no-yay-bin"
  mkdir -p "$no_yay_bin"
  ln -s "$(command -v env)" "$no_yay_bin/env"
  ln -s "$(command -v bash)" "$no_yay_bin/bash"
  PATH="$no_yay_bin" run "$SCRIPT" --packages-dir "$PKGS"
  assert_failure 1
  assert_output --partial "yay not found"
}

@test "installs every declared package via yay -S --needed" {
  fixture base.txt "git" "neovim"
  with_yay_stub
  run "$SCRIPT" --packages-dir "$PKGS"
  assert_success
  run cat "$STUB_LOG"
  assert_output "yay -S --needed git neovim"
}

@test "passes extra arguments through to yay" {
  fixture base.txt "git"
  with_yay_stub
  run "$SCRIPT" --packages-dir "$PKGS" --noconfirm
  assert_success
  run cat "$STUB_LOG"
  assert_output "yay -S --needed --noconfirm git"
}
