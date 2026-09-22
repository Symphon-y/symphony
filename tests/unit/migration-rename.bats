#!/usr/bin/env bats
# Unit tests for the Phase 18 migration that moves an installed machine from the old
# project name to the new one (D-0081): the payload root, /etc/<name>, the user's
# state dir, the four root-owned drop-ins, then a restow from the new payload path.
# Everything root goes through a sudo stub that runs the command; paths are temp dirs.
#
# The migration ships inside the renamed payload, so it is run here from a payload
# laid out under the NEW name, with the OLD-name locations still on "the machine".
# rename: keep

setup() {
  load '../helpers/common'
  SCRIPT=$(ls "$REPO_ROOT"/migrations/*-rename-autarchy-to-symphony.sh)
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  ROOT="$BATS_TEST_TMPDIR/root" # fake / for /usr/local/share and /etc
  export HOME="$BATS_TEST_TMPDIR/home"
  export MIGRATION_ROOT="$ROOT"
  mkdir -p "$ROOT/usr/local/share/autarchy/current/install" "$ROOT/etc/autarchy" \
    "$HOME/.local/state/autarchy/migrations" "$HOME/.local/bin"
  echo "local-abc" >"$ROOT/usr/local/share/autarchy/current/VERSION"
  echo "key" >"$ROOT/etc/autarchy/release.pub"
  touch "$HOME/.local/state/autarchy/first-login-done" "$HOME/.local/state/autarchy/migrations/1-old.sh"
  local d
  for d in systemd/journald.conf.d mkinitcpio.conf.d systemd/resolved.conf.d ssh/sshd_config.d; do
    mkdir -p "$ROOT/etc/$d"
    echo "old" >"$ROOT/etc/$d/10-autarchy.conf"
  done
  # link-home is called from the NEW payload path; it must exist there after the move.
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\necho "link-home $* from $PWD" >>"$STUB_LOG"\n' \
    >"$ROOT/usr/local/share/autarchy/current/install/link-home"
  chmod +x "$ROOT/usr/local/share/autarchy/current/install/link-home"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\necho "sudo $*" >>"$STUB_LOG"\nexec "$@"\n' >"$bin/sudo"
  printf '#!/usr/bin/env bash\necho "mkinitcpio $*" >>"$STUB_LOG"\n' >"$bin/mkinitcpio"
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "moves the payload root, /etc/<name> and the user's state dir to the new name, keeping their contents" {
  run "$SCRIPT"
  assert_success
  assert_equal "$(cat "$ROOT/usr/local/share/symphony/current/VERSION")" "local-abc"
  assert_equal "$(cat "$ROOT/etc/symphony/release.pub")" "key"
  assert [ -e "$HOME/.local/state/symphony/first-login-done" ]
  assert [ -e "$HOME/.local/state/symphony/migrations/1-old.sh" ]
  assert [ ! -e "$ROOT/usr/local/share/autarchy" ]
  assert [ ! -e "$ROOT/etc/autarchy" ]
  assert [ ! -e "$HOME/.local/state/autarchy" ]
}

@test "the moves that need root go through sudo; the state dir does not" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "sudo mv $ROOT/usr/local/share/autarchy $ROOT/usr/local/share/symphony"
  assert_line "sudo cp -a $ROOT/etc/autarchy/. $ROOT/etc/symphony/"
  assert_line "sudo rm -rf $ROOT/etc/autarchy"
  refute_output --partial "sudo cp -a $HOME"
  refute_output --partial "sudo rm -rf $HOME"
}

@test "removes the four old-name drop-ins, so the renamed ones sync-system installs are not doubled" {
  run "$SCRIPT"
  assert_success
  local d
  for d in systemd/journald.conf.d mkinitcpio.conf.d systemd/resolved.conf.d ssh/sshd_config.d; do
    assert [ ! -e "$ROOT/etc/$d/10-autarchy.conf" ]
  done
  run calls
  assert_line --partial "mkinitcpio -P"
}

@test "restows the home from the payload's NEW path, so every link resolves there" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "link-home apply from $ROOT/usr/local/share/symphony/current"
}

@test "merges into a new-name dir the appliers already created (sync-system, migrate run first), keeping the old contents" {
  # sync-system has installed the renamed key; migrate has mkdir'd its new state dir.
  mkdir -p "$ROOT/etc/symphony" "$HOME/.local/state/symphony/migrations"
  echo "key" >"$ROOT/etc/symphony/release.pub"
  run "$SCRIPT"
  assert_success
  assert [ -e "$HOME/.local/state/symphony/first-login-done" ]
  assert [ -e "$HOME/.local/state/symphony/migrations/1-old.sh" ]
  assert [ ! -e "$ROOT/etc/autarchy" ]
  assert [ ! -e "$HOME/.local/state/autarchy" ]
}

@test "drops the home's links into the old payload root before restowing, so they are relinked rather than skipped as conflicts" {
  ln -s "$ROOT/usr/local/share/autarchy/current/home/x/dot-config/thing" "$HOME/.local/bin/thing"
  ln -s "/somewhere/else" "$HOME/.local/bin/other"
  run "$SCRIPT"
  assert_success
  assert [ ! -L "$HOME/.local/bin/thing" ]
  assert [ -L "$HOME/.local/bin/other" ]
}

@test "an interrupted run finishes on the next: root already moved, links still stale -> relinked" {
  mv "$ROOT/usr/local/share/autarchy" "$ROOT/usr/local/share/symphony"
  ln -s "$ROOT/usr/local/share/autarchy/current/home/x/dot-config/thing" "$HOME/.local/bin/thing"
  run "$SCRIPT"
  assert_success
  assert [ ! -L "$HOME/.local/bin/thing" ]
  run calls
  assert_line "link-home apply from $ROOT/usr/local/share/symphony/current"
}

@test "is a no-op on a machine already on the new name" {
  "$SCRIPT" >/dev/null
  : >"$STUB_LOG"
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "mv "
  refute_output --partial "mkinitcpio"
}

@test "moves what exists and skips what does not (a machine that never had /etc/<old>)" {
  rm -rf "$ROOT/etc/autarchy"
  run "$SCRIPT"
  assert_success
  assert [ -e "$ROOT/usr/local/share/symphony/current/VERSION" ]
  assert [ ! -e "$ROOT/etc/symphony" ]
}

@test "refuses if both old and new payload roots exist (nothing is guessed about which is live)" {
  mkdir -p "$ROOT/usr/local/share/symphony"
  run "$SCRIPT"
  assert_failure
  assert_output --partial "both"
  assert [ -e "$ROOT/usr/local/share/autarchy/current/VERSION" ]
}
