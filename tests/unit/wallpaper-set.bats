#!/usr/bin/env bats
# Unit tests for home/hyprpaper/dot-local/bin/wallpaper-set: set the wallpaper, and make
# the picture actually change (D-0085). hyprpaper 0.8.4 renders only what its config
# declares, resolved once at startup -- its runtime IPC is gone -- so wallpaper-set
# writes the config and restarts the service. matugen, systemctl, hyprctl and
# alienfx-theme are stubs on PATH; HOME is a temp dir.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/hyprpaper/dot-local/bin/wallpaper-set"
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  unset XDG_CONFIG_HOME
  mkdir -p "$HOME/.config/hypr" "$BATS_TEST_TMPDIR/bin"
  IMAGE="$BATS_TEST_TMPDIR/photo.jpg"
  : >"$IMAGE"
  CONF="$HOME/.config/hypr/hyprpaper.conf"
  POINTER="$HOME/.local/state/symphony/wallpaper"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin" tool
  for tool in matugen hyprctl alienfx-theme; do
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$STUB_LOG"\n' "$tool" >"$bin/$tool"
  done
  cat >"$bin/systemctl" <<'STUB'
#!/usr/bin/env bash
echo "systemctl $*" >>"$STUB_LOG"
[[ $* == *is-active* ]] && exit "${STUB_HYPRPAPER_INACTIVE:-0}"
exit 0
STUB
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "usage: exactly one path" {
  run "$SCRIPT"
  assert_failure
  assert_output --partial "usage"
}

@test "a path that is not a file fails before anything is written" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/nope.jpg"
  assert_failure
  assert_output --partial "no such file"
  assert [ ! -e "$CONF" ]
  run calls
  assert_output ""
}

@test "writes hyprpaper's config with the resolved path, so hyprpaper renders that image" {
  run "$SCRIPT" "$IMAGE"
  assert_success
  run cat "$CONF"
  assert_output --partial "wallpaper {"
  assert_output --partial "path = $IMAGE"
  assert_output --partial "fit_mode = cover"
  assert_output --partial "ipc = on"
}

@test "the config names the image, never the pointer symlink (one answer everywhere)" {
  run "$SCRIPT" "$IMAGE"
  assert_success
  run cat "$CONF"
  refute_output --partial "state/symphony/wallpaper"
}

@test "repoints the wallpaper pointer at the same image (the palette's stable input)" {
  run "$SCRIPT" "$IMAGE"
  assert_success
  assert [ -L "$POINTER" ]
  assert_equal "$(readlink -f "$POINTER")" "$IMAGE"
}

@test "creates the pointer's directory on a home that has never had one (D-0086)" {
  assert [ ! -d "$HOME/.local/state/symphony" ]
  run "$SCRIPT" "$IMAGE"
  assert_success
  assert [ -L "$POINTER" ]
}

@test "nothing is written to the old backgrounds directory any more (D-0086)" {
  run "$SCRIPT" "$IMAGE"
  assert_success
  assert [ ! -e "$HOME/.local/share/backgrounds" ]
}

@test "restarts hyprpaper when it is running, so the picture changes now" {
  run "$SCRIPT" "$IMAGE"
  assert_success
  run calls
  assert_line "systemctl --user restart hyprpaper.service"
}

@test "does not restart hyprpaper when it is not running (a TTY login), but still writes the config" {
  STUB_HYPRPAPER_INACTIVE=3 run "$SCRIPT" "$IMAGE"
  assert_success
  run cat "$CONF"
  assert_output --partial "path = $IMAGE"
  run calls
  refute_output --partial "restart"
}

@test "never uses hyprpaper's runtime IPC: 0.8.4 accepts the request and ignores it (D-0085)" {
  run "$SCRIPT" "$IMAGE"
  assert_success
  run calls
  refute_output --partial "hyprctl"
}

@test "re-renders the palette and repaints themed hardware, after the picture is up" {
  run "$SCRIPT" "$IMAGE"
  assert_success
  run calls
  assert_output --partial "matugen --config $HOME/.config/matugen/config.toml image $IMAGE --source-color-index 0"
  assert_output --partial "alienfx-theme"
  local restart matugen
  restart=$(grep -n 'restart hyprpaper' "$STUB_LOG" | cut -d: -f1 | head -1)
  matugen=$(grep -n '^matugen' "$STUB_LOG" | cut -d: -f1 | head -1)
  assert [ "$restart" -lt "$matugen" ]
}

@test "a path with spaces (an SMB share of photos) round-trips into the config and the symlink" {
  local spaced="$BATS_TEST_TMPDIR/Photography Exports/The Frame/DSC06220.jpg"
  mkdir -p "$(dirname "$spaced")"
  : >"$spaced"
  run "$SCRIPT" "$spaced"
  assert_success
  run cat "$CONF"
  assert_output --partial "path = $spaced"
  assert_equal "$(readlink -f "$POINTER")" "$spaced"
}

@test "re-running with another image replaces the config rather than appending a second block" {
  local second="$BATS_TEST_TMPDIR/other.jpg"
  : >"$second"
  "$SCRIPT" "$IMAGE" >/dev/null
  run "$SCRIPT" "$second"
  assert_success
  run grep -c 'wallpaper {' "$CONF"
  assert_output "1"
  run cat "$CONF"
  assert_output --partial "path = $second"
  refute_output --partial "path = $IMAGE"
}
