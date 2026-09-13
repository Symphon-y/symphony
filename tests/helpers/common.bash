# Shared setup for every bats suite: locate the repo and load assertion libraries.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
export REPO_ROOT

# Arch installs bats libraries under /usr/lib/bats; Homebrew under its prefix's lib.
# Append rather than default: bats itself pre-sets BATS_LIB_PATH before tests load.
export BATS_LIB_PATH="${BATS_LIB_PATH:+$BATS_LIB_PATH:}/usr/lib/bats:/opt/homebrew/lib:/usr/local/lib"

bats_load_library bats-support
bats_load_library bats-assert
