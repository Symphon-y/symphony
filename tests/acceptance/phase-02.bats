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

# Claude Code's policy lives in root-owned managed settings, which outrank user settings.
readonly MANAGED_SETTINGS=/etc/claude-code/managed-settings.json

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

# --- ssh (on demand, from a trusted jump host) ---------------------------------

# Firewall rules that open SSH without restricting the source address.
unrestricted_ssh_rules() {
  as_root nft list chain inet filter input | grep -E 'dport (22|ssh)\b' | grep -v 'saddr' || true
}

@test "ssh: the server accepts keys only, never root, and forwards nothing" {
  run as_root sshd -T
  assert_success
  assert_line "passwordauthentication no"
  assert_line "kbdinteractiveauthentication no"
  assert_line "permitrootlogin no"
  assert_line "authenticationmethods publickey"
  assert_line "allowagentforwarding no"
  assert_line "allowtcpforwarding no"
  assert_line "x11forwarding no"
  assert_line "permittunnel no"
}

@test "ssh: authorized keys are root-owned system config, not user-editable files" {
  run as_root sshd -T
  assert_line "authorizedkeysfile /etc/ssh/authorized_keys/%u"
  local keys
  keys="/etc/ssh/authorized_keys/$(id -un)"
  run as_root find "$keys" -user 0 ! -perm -g=w ! -perm -o=w
  assert_output "$keys"
}

@test "ssh: every authorized key is restricted to a source address" {
  local keys
  keys="/etc/ssh/authorized_keys/$(id -un)"
  # No key line without a from= restriction...
  run as_root grep -Evc '^[[:space:]]*(#|$)|^from="[^"]+",' "$keys"
  assert_output "0"
  # ...and at least one restricted key.
  run as_root grep -Ec '^from="[^"]+",' "$keys"
  refute_output "0"
}

@test "ssh: the server is not started at boot" {
  run systemctl is-enabled sshd
  refute_output "enabled"
}

@test "ssh: the firewall opens port 22 only to specific source addresses" {
  run as_root nft list chain inet filter input
  assert_success
  assert_output --regexp 'saddr .* dport (22|ssh)'
  run unrestricted_ssh_rules
  assert_output ""
}

# --- shell --------------------------------------------------------------------

@test "shell: login shells put ~/.local/bin on PATH, after the system directories" {
  # A clean environment, so a PATH exported by hand can't make this pass.
  # shellcheck disable=SC2016 # $PATH must expand inside the login shell, not here
  run env -i HOME="$HOME" USER="$USER" bash -lc 'printf "%s" "$PATH"'
  assert_success
  assert_output --regexp "(^|:)/usr/bin:(.*:)?$HOME/\.local/bin(:|$)"
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

@test "claude code: managed settings pin the stable channel and turn off telemetry" {
  run jq -r '.autoUpdatesChannel' "$MANAGED_SETTINGS"
  assert_output "stable"
  run jq -r '.env.DISABLE_TELEMETRY, .env.DISABLE_ERROR_REPORTING' "$MANAGED_SETTINGS"
  assert_output "$(printf '1\n1')"
}

@test "claude code: managed settings deny sudo and reading credential files" {
  local rule
  for rule in 'Bash(sudo *)' 'Read(~/.claude/.credentials.json)' 'Read(~/.config/gh/**)'; do
    run jq -e --arg rule "$rule" '.permissions.deny | index($rule)' "$MANAGED_SETTINGS"
    assert_success
  done
}

@test "claude code: managed settings are root-owned, so Claude can't loosen its own rules" {
  run find "$MANAGED_SETTINGS" -user 0 -perm 0644
  assert_output "$MANAGED_SETTINGS"
}

@test "claude code: personal settings are Claude's own file, not a link into the repo" {
  assert [ ! -L "$HOME/.claude/settings.json" ]
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
