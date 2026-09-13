#!/usr/bin/env bats
# Phase 2 acceptance tests: agent handoff and developer bootstrap.
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01.bats:
#   bats tests/acceptance
# Red run: before the runbook, where they must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

readonly SETTINGS="$HOME/.claude/settings.json"

# --- tooling ------------------------------------------------------------------

@test "tooling: development tools are installed" {
  local tool
  for tool in shellcheck shfmt stow tmux jq bats git gh; do
    run command -v "$tool"
    assert_success
  done
}

@test "tooling: static checks and unit tests pass on this machine" {
  run "$REPO_ROOT/scripts/check"
  assert_success
}

# --- config deployment ----------------------------------------------------------

@test "system config: installed files match system/files.txt" {
  run as_root "$REPO_ROOT/install/sync-system" check
  assert_success
}

@test "home config: every file under home/ is linked into the home directory" {
  run "$REPO_ROOT/install/link-home" check
  assert_success
}

@test "home config: ~/.claude is a real directory, so credentials never land in the repo" {
  assert [ -d "$HOME/.claude" ]
  assert [ ! -L "$HOME/.claude" ]
}

# --- claude code --------------------------------------------------------------

@test "claude code: the claude command runs" {
  run claude --version
  assert_success
  assert_output --partial "Claude Code"
}

@test "claude code: the installed binary matches its GPG-signed release manifest" {
  run "$REPO_ROOT/install/claude-code" verify
  assert_success
}

@test "claude code: diagnostics pass with auto-updates enabled" {
  run claude doctor
  assert_success
  assert_output --regexp 'Auto-updates.*enabled'
}

@test "claude code: settings pin the stable channel and turn off telemetry" {
  run jq -r '.autoUpdatesChannel' "$SETTINGS"
  assert_output "stable"
  run jq -r '.env.DISABLE_TELEMETRY, .env.DISABLE_ERROR_REPORTING' "$SETTINGS"
  assert_output "$(printf '1\n1')"
}

@test "claude code: settings deny sudo and reading credential files" {
  local rule
  for rule in 'Bash(sudo *)' 'Read(~/.claude/.credentials.json)' 'Read(~/.config/gh/**)'; do
    run jq -e --arg rule "$rule" '.permissions.deny | index($rule)' "$SETTINGS"
    assert_success
  done
}

@test "claude code: logged in and able to answer" {
  run claude -p "Reply with only the word ready."
  assert_success
  assert_output --regexp '[Rr]eady'
}

# --- github -------------------------------------------------------------------

@test "github: gh is authenticated and the remote is reachable" {
  run gh auth status
  assert_success
  run git -C "$REPO_ROOT" ls-remote --heads origin
  assert_success
}

@test "github: the latest CI run for this branch succeeded" {
  local branch
  branch=$(git -C "$REPO_ROOT" branch --show-current)
  cd "$REPO_ROOT"
  run gh run list --workflow check.yml --branch "$branch" --limit 1 --json conclusion --jq '.[0].conclusion'
  assert_output "success"
}

@test "github: no login relay gists are left behind" {
  run gh api gists --jq '[.[] | select(.description == "autarchy-relay")] | length'
  assert_success
  assert_output "0"
}
