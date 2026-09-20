#!/usr/bin/env bats
# Unit tests for scripts/pkg-audit. pacman is stubbed so the tests control what
# "installed" means, independent of whatever's really on this machine; the real
# scripts/pkglist runs against fixture package lists via --packages-dir.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/pkg-audit"
  PKGS="$BATS_TEST_TMPDIR/packages"
  mkdir -p "$PKGS"
  : >"$PKGS/desktop.txt"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\n%s\n' '
    case "$1" in
      -Qqe) printf "%s\n" ${STUB_EXPLICIT:-} ;;
      -Qq) printf "%s\n" ${STUB_PRESENT:-${STUB_EXPLICIT:-}} ;;
      -Qqm) printf "%s\n" ${STUB_FOREIGN:-}; exit "${STUB_FOREIGN_RC:-1}" ;;
    esac
  ' >"$bin/pacman"
  chmod +x "$bin/pacman"
  PATH="$bin:$PATH"
}

fixture() {
  local path="$PKGS/$1"
  shift
  printf '%s\n' "$@" >"$path"
}

@test "reports no drift when installed matches declared exactly" {
  fixture base.txt "git" "neovim"
  STUB_EXPLICIT="git neovim" run "$SCRIPT" --packages-dir "$PKGS"
  assert_success
  assert_output --partial "no drift"
}

@test "reports a package installed but not declared" {
  fixture base.txt "git"
  STUB_EXPLICIT="git neovim" run "$SCRIPT" --packages-dir "$PKGS"
  assert_failure
  assert_output --partial "installed but not declared"
  assert_output --partial "neovim"
}

@test "reports a package declared but not installed at all" {
  fixture base.txt "git" "neovim"
  STUB_EXPLICIT="git" run "$SCRIPT" --packages-dir "$PKGS"
  assert_failure
  assert_output --partial "not installed at all"
  assert_output --partial "neovim"
}

@test "a declared package present only as someone else's dependency is not flagged" {
  fixture base.txt "git" "diffutils"
  STUB_EXPLICIT="git" STUB_PRESENT="git diffutils" run "$SCRIPT" --packages-dir "$PKGS"
  assert_success
  assert_output --partial "no drift"
}

@test "reports a foreign package not declared in desktop.txt" {
  fixture base.txt "git"
  STUB_EXPLICIT="git yay" STUB_FOREIGN="yay" STUB_FOREIGN_RC=0 run "$SCRIPT" --packages-dir "$PKGS"
  assert_failure
  assert_output --partial "not declared in $PKGS/desktop.txt"
  assert_output --partial "yay"
}

@test "a foreign package declared in desktop.txt is not flagged" {
  fixture base.txt "git"
  fixture desktop.txt "yay"
  STUB_EXPLICIT="git yay" STUB_FOREIGN="yay" STUB_FOREIGN_RC=0 run "$SCRIPT" --packages-dir "$PKGS"
  assert_success
  assert_output --partial "no drift"
}

@test "no foreign packages at all is not an error" {
  fixture base.txt "git"
  STUB_EXPLICIT="git" STUB_FOREIGN="" STUB_FOREIGN_RC=1 run "$SCRIPT" --packages-dir "$PKGS"
  assert_success
  assert_output --partial "no drift"
}

@test "a hardware-specific package (packages/hardware/) that is installed is not reported as undeclared" {
  fixture base.txt "git"
  mkdir -p "$PKGS/hardware"
  printf '%s\n' "broadcom-wl-dkms" >"$PKGS/hardware/broadcom-wl.txt"
  STUB_EXPLICIT="git broadcom-wl-dkms" run "$SCRIPT" --packages-dir "$PKGS"
  assert_success
  assert_output --partial "no drift"
}

@test "a hardware-specific package that is not installed is not reported as missing (it only applies to some machines)" {
  fixture base.txt "git"
  mkdir -p "$PKGS/hardware"
  printf '%s\n' "broadcom-wl-dkms" >"$PKGS/hardware/broadcom-wl.txt"
  STUB_EXPLICIT="git" run "$SCRIPT" --packages-dir "$PKGS"
  assert_success
  assert_output --partial "no drift"
}
