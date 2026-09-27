#!/usr/bin/env bats
# Unit tests for home/hypr/dot-config/hypr/keymap.lua (Task D, #22): the binder, driven
# against a stubbed `hl`.
#
# keymap.lua is the one file here that touches the compositor, and the part of it worth
# proving is precisely the part `hyprctl binds -j` cannot see: that a member which
# `exits` closes the group, that one which does not re-arms the idle timer instead, and
# that there is one timer rather than one per keystroke. So `hl` is a recording stub and
# the bind callbacks are then called by hand.
#
# Lua under /usr/bin/lua -- no compositor.

setup() {
  load '../helpers/common'
  HYPR="$REPO_ROOT/home/hypr/dot-config/hypr"
  STUB="$BATS_TEST_DIRNAME/../helpers/hl-stub.lua"
  # No user keymap: these tests are about the shipped defaults.
  export SYMPHONY_CONFIG_DIR="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$SYMPHONY_CONFIG_DIR"
}

# A user keymap, the real override surface -- written before the binder loads.
user_keymap() {
  printf 'return %s\n' "$1" >"$SYMPHONY_CONFIG_DIR/keymap.lua"
}

# Load keymap.lua against the stub and run $1 as a trailing script. `stub` gives the
# recorded binds, the call log and a way to press a key.
binder() {
  lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local stub = loadfile('$STUB')()
    dofile('$HYPR/keymap.lua')
    $1"
}

# --- the prefix and its members --------------------------------------------------------

@test "the prefix opens the group, and every member is bound inside the submap" {
  run binder "
    print(stub.bind_description('SUPER + v'))
    print(stub.submap_of('k'), stub.submap_of('m'), stub.submap_of('Escape'))"
  assert_line --index 0 "Volume..."
  assert_line --index 1 "volume	volume	volume"
}

@test "the submap is defined before anything is bound into it" {
  # hl.define_submap takes the function that does the binding, so a bind that escaped it
  # would land in the global map and fire while you type.
  # In the order merge emits them, which is sorted so it is the same on every run.
  run binder "print(stub.defined_submaps())"
  assert_output "brightness menus capture volume"
}

@test "a member that does not exit keeps the group open and restarts the idle wait" {
  run binder "
    stub.press('SUPER + v')
    stub.idle_for(1000)
    stub.reset()
    stub.press('k')
    stub.idle_for(1000)
    print(stub.log())"
  assert_output --partial "exec_cmd volume up"
  # 1 s of idling, a keystroke, 1 s more: the wait measures from the keystroke, so the
  # group is still open. A timer that only counted from when the group opened would have
  # closed it here.
  refute_output --partial "submap reset"
}

@test "a member that exits closes the group and stops the timer" {
  run binder "
    stub.press('SUPER + v')
    stub.reset()
    stub.press('m')
    print(stub.log())"
  assert_output --partial "exec_cmd volume mute"
  assert_output --partial "submap reset"
  assert_output --partial "timer disabled"
}

@test "Escape closes the group without running a command" {
  run binder "
    stub.reset()
    stub.press('Escape')
    print(stub.log())"
  assert_output --partial "submap reset"
  refute_output --partial "exec_cmd"
}

@test "the prefix starts the idle clock, so a group opened and forgotten closes itself" {
  run binder "
    stub.reset()
    stub.press('SUPER + v')
    print(stub.log())
    print(stub.timer_kind(), stub.timer_running())"
  assert_output --partial "submap volume"
  assert_line --index 3 "repeat	true"
}

@test "there is one timer however many keys are pressed" {
  # The bug this forbids: a timer per keystroke leaves several racing to close a group
  # that a later keystroke has already reopened.
  run binder "
    stub.press('SUPER + v')
    stub.press('k')
    stub.press('k')
    stub.press('k')
    print(stub.timers_created())"
  assert_output "1"
}

@test "idling out closes the group, and over IPC because a timer cannot do it directly" {
  # Measured on 0.56.2: a submap dispatched from a timer callback returns ok and is
  # silently ignored. Only the keybind and IPC paths change the submap, so the timeout
  # goes round through hyprctl.
  run binder "
    stub.press('SUPER + v')
    stub.reset()
    stub.idle_for(1500)
    print(stub.log())"
  assert_output --partial "hyprctl dispatch"
  refute_output --partial "(ignored: dispatched from a timer)"
}

@test "the clock keeps running, so a second group also closes itself" {
  # The bug this forbids: a oneshot timer, which cannot be re-armed once it has fired --
  # the first group would time out and every one after it would stay open for ever.
  run binder "
    stub.press('SUPER + v')
    stub.idle_for(1500)
    stub.press('SUPER + v')
    stub.reset()
    stub.idle_for(1500)
    print(stub.log())"
  assert_output --partial "hyprctl dispatch"
}

@test "the clock stops once the group is closed, rather than ticking all session" {
  run binder "
    stub.press('SUPER + v')
    stub.press('m')
    print(stub.timer_running())"
  assert_output "false"
}

# --- not costing a session -------------------------------------------------------------

@test "a reload is made to leave any open group" {
  run binder "print(stub.subscribed())"
  assert_output "config.reloaded"
}

@test "a group with no keys is reported and skipped, and the rest of the keymap survives" {
  user_keymap '{ global = { ["SUPER + z"] = { kind = "group", desc = "Broken", keys = {} } } }'
  run binder "
    print(stub.notifications())
    print(stub.bind_description('XF86AudioRaiseVolume'))"
  assert_output --partial "has no keys"
  assert_line --index 1 "Volume up"
}

@test "an unknown action inside a group costs that key alone" {
  user_keymap '{ global = { ["SUPER + z"] = { kind = "group", desc = "Typo", keys = {
    ["k"] = "volume.louder", ["j"] = "volume.down" } } } }'
  run binder "
    print(stub.notifications())
    print(stub.submap_of('j'))"
  assert_output --partial "no action named"
  assert_line --index 1 "typo"
}

@test "a user group replaces the shipped one whole, rather than merging into it" {
  # Per-key whole-value replace (#21) extends to groups: a group is one value, so a
  # user group is theirs entirely -- no half-inherited member list to reason about.
  user_keymap '{ global = { ["SUPER + v"] = { kind = "group", desc = "Sound", keys = {
    ["u"] = "volume.up" } } } }'
  run binder "
    print(stub.bind_description('SUPER + v'))
    print(stub.submap_of('u'))
    print(stub.defined_submaps())"
  assert_line --index 0 "Sound..."
  assert_line --index 1 "sound"
  # The shipped group is gone entirely -- not merged into, so its keys did not survive.
  refute_line --partial "volume"
}

# --- Hyprland's own dispatchers, named by the registry (#23) ---------------------------
#
# Most of the migrated chords are not `exec`: they close a window, exit, focus a
# direction, switch a workspace. The registry names the dispatcher as data -- `dsp` plus
# optional `args` -- so a new one is a line in actions.lua rather than a branch here.

@test "a dispatch action binds the dispatcher the registry names" {
  user_keymap '{ global = { ["SUPER + z"] = "window.close" } }'
  run binder "
    stub.press('SUPER + z')
    print(stub.log())
    print(stub.bind_description('SUPER + z'))"
  assert_output --partial "dispatch window.close"
  assert_output --partial "Close window"
}

@test "a dispatch action passes its args through, so one action serves ten workspaces" {
  user_keymap '{ global = { ["SUPER + z"] = "workspace.3" } }'
  run binder "
    stub.press('SUPER + z')
    print(stub.log())"
  assert_output --partial "dispatch focus {workspace=3}"
}

@test "an action with no args calls the dispatcher with no argument at all" {
  # Not the same thing as nil: hl.dsp.focus(nil) raises \"expected a table\", measured on
  # 0.56.2, so a dispatcher that takes nothing must be called with nothing.
  user_keymap '{ global = { ["SUPER + z"] = "window.close" } }'
  run binder "
    stub.press('SUPER + z')
    print(stub.log())"
  assert_output --partial "(argc 0)"
}

@test "a dispatcher name the compositor does not have costs that key alone" {
  user_keymap '{ global = { ["SUPER + z"] = { desc = "Nope", kind = "dispatch", dsp = "window.explode" } } }'
  run binder "
    print(stub.notifications())
    print(stub.bind_description('SUPER + Return'))"
  assert_output --partial "window.explode"
  assert_line --index 1 "Terminal"
}

# --- the flat keymap is untouched by all this ------------------------------------------

@test "the hardware keys are still bound flat, outside any submap" {
  run binder "
    print('[' .. stub.submap_of('XF86AudioRaiseVolume') .. ']')
    print(stub.bind_locked('XF86AudioRaiseVolume'))"
  assert_line --index 0 "[]"
  assert_line --index 1 "true"
}
