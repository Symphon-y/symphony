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

# --- our own PKGBUILDs (packages/aur/<name>/PKGBUILD, Phase 19) ------------------------

# makepkg and pacman stubs: makepkg logs where it ran and "installs"; pacman -Q answers
# what is installed.
# shellcheck disable=SC2016 # stub bodies expand when the stub runs
with_build_stubs() {
  with_yay_stub
  local bin="$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\necho "makepkg $* in $(basename "$PWD") with $(ls PKGBUILD *.patch 2>/dev/null | tr "\\n" " ")" >>"$STUB_LOG"\n' >"$bin/makepkg"
  printf '#!/usr/bin/env bash\ncase "$*" in -Q*) grep -qx "${*##* }" <<<"${STUB_INSTALLED:-}" && echo "${*##* } 1.0-1";; esac\n' >"$bin/pacman"
  chmod +x "$bin/makepkg" "$bin/pacman"
  mkdir -p "$PKGS/aur/alienfx"
  printf 'pkgname=alienfx\npkgver=2.5.0\npkgrel=1\n' >"$PKGS/aur/alienfx/PKGBUILD"
  printf 'patch\n' >"$PKGS/aur/alienfx/0001-fix.patch"
}

@test "a package with our own PKGBUILD is built with makepkg from a copy of its directory, not fetched from the AUR" {
  fixture base.txt "git"
  mkdir -p "$PKGS/hardware"
  fixture hardware/alienfx.txt "alienfx"
  with_build_stubs
  run "$SCRIPT" --packages-dir "$PKGS" alienfx
  assert_success
  run cat "$STUB_LOG"
  assert_line "yay -S --needed git"
  assert_line --regexp "^makepkg -si --needed --noconfirm in tmp\..* with (PKGBUILD 0001-fix.patch|0001-fix.patch PKGBUILD)"
  refute_line --partial "yay -S --needed git alienfx"
}

@test "the copy is made outside the repo (makepkg writes build artefacts) and removed afterwards" {
  fixture base.txt "git"
  with_build_stubs
  run "$SCRIPT" --packages-dir "$PKGS" alienfx
  assert_success
  run find "$PKGS/aur/alienfx" -name '*.pkg.tar.zst' -o -name src -o -name pkg
  assert_output ""
}

@test "an own package already installed at the PKGBUILD's version is not rebuilt" {
  fixture base.txt "git"
  with_build_stubs
  printf '#!/usr/bin/env bash\ncase "$*" in -Q*) echo "alienfx 2.5.0-1";; esac\n' >"$BATS_TEST_TMPDIR/bin/pacman"
  run "$SCRIPT" --packages-dir "$PKGS" alienfx
  assert_success
  run cat "$STUB_LOG"
  refute_line --partial "makepkg"
}

@test "an own package installed at an older version is rebuilt" {
  fixture base.txt "git"
  with_build_stubs
  printf '#!/usr/bin/env bash\ncase "$*" in -Q*) echo "alienfx 2.4.3-4";; esac\n' >"$BATS_TEST_TMPDIR/bin/pacman"
  run "$SCRIPT" --packages-dir "$PKGS" alienfx
  assert_success
  run cat "$STUB_LOG"
  assert_line --partial "makepkg"
}
