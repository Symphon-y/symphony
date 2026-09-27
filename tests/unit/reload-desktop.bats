#!/usr/bin/env bats
# Unit tests for install/reload-desktop (#25): making the running desktop match the
# payload that just landed.
#
# The bug behind it: every applier can run, every file can be correct, and the screen
# keeps the old configuration. `enable --now` is a no-op on a unit that is already enabled
# and running, and matugen -- which generates mako's config, waybar's colours and the rest
# -- runs on a wallpaper change, which a deploy is not.
#
# hyprctl, matugen and the sibling applier are stubs on PATH or in a fake payload.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export HOME="$BATS_TEST_TMPDIR/home"
  export HYPRLAND_INSTANCE_SIGNATURE=abc123
  mkdir -p "$HOME/.local/state/symphony" "$HOME/Pictures" "$BATS_TEST_TMPDIR/bin"
  : >"$HOME/Pictures/wall.png"
  ln -sfn "$HOME/Pictures/wall.png" "$HOME/.local/state/symphony/wallpaper"

  # A payload holding this applier, its siblings and its libs -- which is how it runs in
  # production: from /usr/local/share/symphony/current.
  PAYLOAD="$BATS_TEST_TMPDIR/current"
  make_payload "$PAYLOAD"
  SCRIPT="$PAYLOAD/install/reload-desktop"
  PREVIOUS="$BATS_TEST_TMPDIR/previous"
  make_payload "$PREVIOUS"

  local tool
  for tool in hyprctl matugen; do
    # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$STUB_LOG"\n[[ $* == *version* && -n ${STUB_NO_SESSION:-} ]] && exit 1\n[[ $* == *reload* && -n ${STUB_HYPRCTL_FAIL:-} ]] && exit 1\nexit 0\n' \
      "$tool" >"$BATS_TEST_TMPDIR/bin/$tool"
  done
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

make_payload() {
  local dir=$1
  mkdir -p "$dir/install" "$dir/scripts/lib" "$dir/home/matugen/dot-config/matugen/templates"
  cp "$REPO_ROOT/install/reload-desktop" "$dir/install/reload-desktop"
  cp "$REPO_ROOT/scripts/lib/wallpaper.bash" "$dir/scripts/lib/wallpaper.bash"
  echo "# mako template" >"$dir/home/matugen/dot-config/matugen/templates/mako.ini"
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "enable-user-services $*" >>"$STUB_LOG"\nexit "${STUB_RESTART_RC:-0}"\n' \
    >"$dir/install/enable-user-services"
  chmod +x "$dir/install/reload-desktop" "$dir/install/enable-user-services"
}

calls() {
  cat "$STUB_LOG"
}

# --- what a deploy has to do ----------------------------------------------------------

@test "reloads Hyprland: the swap replaces its config underneath it" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "hyprctl reload"
}

@test "restarts the user services, which is what a changed config needs" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "enable-user-services restart"
}

@test "asks the payload's own applier, not whatever is on PATH" {
  # The point of being an applier: everything runs from the payload that just landed.
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "enable-user-services restart"
  assert [ -x "$PAYLOAD/install/enable-user-services" ]
}

# --- the generated half ---------------------------------------------------------------

@test "re-renders the palette when the templates differ from the previous payload" {
  echo "# changed" >>"$PREVIOUS/home/matugen/dot-config/matugen/templates/mako.ini"
  run "$SCRIPT" --since "$PREVIOUS"
  assert_success
  run calls
  assert_output --partial "matugen --config"
  assert_output --partial "--source-color-index 0"
}

@test "does not re-render when the templates are untouched" {
  run "$SCRIPT" --since "$PREVIOUS"
  assert_success
  run calls
  refute_output --partial "matugen"
}

@test "with no previous payload to compare, it re-renders rather than guessing" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "matugen"
}

@test "no wallpaper yet (before first-login) means no re-render, and no error" {
  rm "$HOME/.local/state/symphony/wallpaper"
  run "$SCRIPT"
  assert_success
  run calls
  refute_output --partial "matugen"
}

@test "the palette is rendered from the image the pointer resolves to" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output --partial "image $HOME/Pictures/wall.png"
}

# --- no session -----------------------------------------------------------------------

@test "no session (a TTY, or over SSH) leaves everything alone and says so" {
  unset HYPRLAND_INSTANCE_SIGNATURE
  STUB_NO_SESSION=1 run "$SCRIPT"
  assert_success
  assert_output --partial "no session"
  run calls
  refute_output --partial "hyprctl reload"
  refute_output --partial "enable-user-services"
  refute_output --partial "matugen"
}

@test "a session detected only by hyprctl, with no env var, still reloads" {
  unset HYPRLAND_INSTANCE_SIGNATURE
  run "$SCRIPT"
  assert_success
  run calls
  assert_line "hyprctl reload"
}

# --- never fatal ----------------------------------------------------------------------

@test "a failed Hyprland reload is reported and the rest still happens" {
  # By the time this runs the update has succeeded: a step that fails is a message, not a
  # reason to leave the desktop half-reloaded.
  STUB_HYPRCTL_FAIL=1 run --separate-stderr "$SCRIPT"
  assert_success
  [[ $stderr == *"hyprctl reload failed"* ]]
  run calls
  assert_line "enable-user-services restart"
}

@test "a service that will not restart is named, and the exit code stays zero" {
  STUB_RESTART_RC=1 run --separate-stderr "$SCRIPT"
  assert_success
  [[ $stderr == *"did not restart"* ]]
}

# --- usage ----------------------------------------------------------------------------

@test "an unknown argument is a usage error" {
  run "$SCRIPT" --everything
  assert_failure 2
  assert_output --partial "usage"
}

@test "--since with no directory is a usage error" {
  run "$SCRIPT" --since
  assert_failure 2
  assert_output --partial "usage"
}
