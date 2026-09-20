# Shared setup for every bats suite: locate the repo and load assertion libraries.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
export REPO_ROOT

# Arch installs bats libraries under /usr/lib/bats; Homebrew under its prefix's lib.
# Append rather than default: bats itself pre-sets BATS_LIB_PATH before tests load.
export BATS_LIB_PATH="${BATS_LIB_PATH:+$BATS_LIB_PATH:}/usr/lib/bats:/opt/homebrew/lib:/usr/local/lib"

bats_load_library bats-support
bats_load_library bats-assert

# True if $1 is a symlink in the repo. Falls back to the git index (mode 120000)
# because a Windows checkout flattens symlinks to plain files; on Linux, and in CI,
# the -L test alone answers it.
is_symlink() {
  [[ -L $1 ]] || git -C "$REPO_ROOT" ls-files -s -- "$1" | grep -q '^120000'
}
