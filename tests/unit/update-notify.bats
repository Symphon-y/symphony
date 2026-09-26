#!/usr/bin/env bats
# Unit tests for home/update/dot-local/bin/update-notify: the toast (Phase 9 D-0059 for
# packages, Phase 18 for releases, made actionable in Phase 20).
#
# Since Phase 20 it only reads the state file update-check wrote -- it makes no network
# call of its own -- and the toast carries an "Update now" action. notify-send,
# systemd-run and xdg-terminal-exec are stubs on PATH.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/update/dot-local/bin/update-notify"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export SYMPHONY_STATE="$BATS_TEST_TMPDIR/state"
  STATE="$SYMPHONY_STATE/updates"
  mkdir -p "$SYMPHONY_STATE"
  export STUB_ACTION=""
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin" tool
  mkdir -p "$bin"
  # notify-send with --action prints the chosen action's name on stdout; nothing
  # chosen (dismissed or expired) prints nothing.
  cat >"$bin/notify-send" <<'EOF'
#!/usr/bin/env bash
echo "notify-send $*" >>"$STUB_LOG"
printf '%s' "${STUB_ACTION:-}"
EOF
  for tool in systemd-run xdg-terminal-exec curl checkupdates; do
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$STUB_LOG"\n' "$tool" >"$bin/$tool"
  done
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

state() {
  printf '%s\n' "$@" >"$STATE"
}

calls() {
  cat "$STUB_LOG"
}

@test "nothing pending: silent, exit 0" {
  state "packages=0" "pkglist=" "release=" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "no state file at all: silent, and not a failure" {
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "it never checks anything itself: that is update-check's job" {
  state "packages=2" "pkglist=linux vim" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "curl"
  refute_output --partial "checkupdates"
}

@test "pending packages: one toast naming the count (D-0059, unchanged)" {
  state "packages=2" "pkglist=linux vim" "release=" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "2 updates available"
}

@test "a pending release: one toast naming the tag" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "symphony 2026.09.25 available"
}

@test "the action is named 'default', the only one a mako click can invoke" {
  # mako draws no buttons for actions at all. Its left click runs
  # invoke-default-action, which invokes the action literally named `default`;
  # any other name is unreachable by clicking. Naming it `update` shipped a toast
  # that looked right and did nothing.
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "notify-send .*(-A|--action)[= ]?default="
}

@test "choosing it opens a terminal running update-now" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  STUB_ACTION=default run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "update-now"
}

@test "the terminal is launched detached, or the oneshot service kills it on exit" {
  # A Type=oneshot unit takes its whole cgroup down when ExecStart returns.
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  STUB_ACTION=default run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "systemd-run .*--scope"
}

@test "dismissing it launches nothing" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  STUB_ACTION="" run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "update-now"
}

@test "no second action is offered: mako cannot reach one" {
  # A "Later" action would never be invocable, so it would be a lie on screen.
  # Dismissing is Later, and mako's right click already dismisses.
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "later"
}

@test "the same release tomorrow: no second toast" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  "$SCRIPT"
  : >"$STUB_LOG"
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "the same pending packages tomorrow: no second toast" {
  state "packages=2" "pkglist=linux vim" "release=" "installed=2026.09.24" "checked=1790000000"
  "$SCRIPT"
  : >"$STUB_LOG"
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "a different set of pending packages is worth saying again" {
  state "packages=2" "pkglist=linux vim" "release=" "installed=2026.09.24" "checked=1790000000"
  "$SCRIPT"
  : >"$STUB_LOG"
  state "packages=3" "pkglist=linux vim git" "release=" "installed=2026.09.24" "checked=1790000001"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "3 updates available"
}

@test "a newer release than the one already announced is worth saying again" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  "$SCRIPT"
  : >"$STUB_LOG"
  state "packages=0" "pkglist=" "release=2026.09.26" "installed=2026.09.24" "checked=1790000001"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "2026.09.26"
}

@test "a long package list is cut short in the toast, not dumped into it" {
  state "packages=37" "pkglist=$(printf 'pkg%02d ' $(seq 1 37))" "release=" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "more"
  refute_output --partial "pkg37"
}

@test "both pending: one toast, not two" {
  state "packages=2" "pkglist=linux vim" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run bash -c "grep -c '^notify-send' '$STUB_LOG'"
  assert_output "1"
}

@test "the toast is given a lifetime, so --wait cannot hold the unit open forever" {
  state "packages=0" "pkglist=" "release=2026.09.25" "installed=2026.09.24" "checked=1790000000"
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --regexp "notify-send .*(-t|--expire-time)[= ][0-9]+"
}
