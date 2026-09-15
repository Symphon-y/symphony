#!/usr/bin/env bats
# Phase 7 acceptance tests: developer environment (shell, prompt, version manager,
# containers, git identity). Everything in this phase is headless-testable -- unlike
# Phases 4-6, nothing here needs a live Hyprland session.
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01..06:
#   bats tests/acceptance
# Red run: before this phase's implementation, where this whole file must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

# --- packages -------------------------------------------------------------------

@test "packages: the developer-environment tools are installed" {
  local pkg
  for pkg in starship mise eza zoxide fzf bat podman podman-compose podman-docker; do
    run pacman -Qi "$pkg"
    assert_success
  done
}

# --- shell ------------------------------------------------------------------------

@test "shell: bashrc is valid syntax and activates starship/mise/zoxide" {
  run bash -n "$HOME/.bashrc"
  assert_success
  run cat "$HOME/.bashrc"
  assert_success
  assert_output --partial "starship init bash"
  assert_output --partial "mise activate bash"
  assert_output --partial "zoxide init bash"
}

# --- prompt -------------------------------------------------------------------------

@test "prompt: starship is installed and the config renders" {
  run starship --version
  assert_success
  run cat "$HOME/.config/starship.toml"
  assert_success
  assert_output --partial "format"
  assert_output --partial "git_branch"
}

# --- git --------------------------------------------------------------------------

@test "git: global identity and config defaults are set" {
  # Identity lives in ~/.gitconfig.local (untracked, D-0022 -- no personal
  # identifiers in git), pulled in via [include]; --global alone doesn't follow
  # includes, so --includes is required to see the resolved value.
  run git config --global --includes user.name
  assert_output "Symphon-y"
  run git config --global --includes user.email
  assert_output --regexp '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$'
  run git config --global init.defaultBranch
  assert_output "main"
  run git config --global pull.rebase
  assert_output "true"
}

# --- neovim (config only -- the package itself is Phase 1's job) ------------------

@test "neovim: the user's own config is cloned and points at the right remote" {
  run git -C "$HOME/.config/nvim" remote get-url origin
  assert_success
  assert_output --partial "Symphon-y/config.nvim"
}

@test "neovim: starts headless with no errors" {
  run nvim --headless "+qa"
  assert_success
}

# --- containers (rootless podman) --------------------------------------------------

@test "containers: podman runs rootless with no group membership needed" {
  run podman info --format '{{.Host.Security.Rootless}}'
  assert_success
  assert_output "true"
  run groups
  refute_output --partial "docker"
}

@test "containers: podman can actually run a container" {
  run podman run --rm docker.io/library/hello-world
  assert_success
}
