#!/usr/bin/env bats
# Unit tests for home/hypr/dot-config/hypr/keymap/groups.lua (Task D, #22): what a
# transient prefix group means as bindings.
#
# A prefix chord opens a short-lived submap that waits for one key: SUPER+v then k/j to
# move the volume, m to mute and leave, Escape or 1.5 s of idling to leave. A group is
# entered only by its explicit prefix, so nothing is ever swallowed while you type --
# which is why #16 dropped the modal layer and nvim is untouched.
#
# This module is the *pure* half: given a prefix and a spec it returns the plan -- the
# submap's name, its members in a stable order, and which of them leave the group. The
# live machinery (define_submap, the idle timer, dispatching submap reset) is keymap.lua's
# job, the one file here that touches `hl`.
#
# Pure Lua under /usr/bin/lua -- no compositor.

setup() {
  load '../helpers/common'
  HYPR="$REPO_ROOT/home/hypr/dot-config/hypr"
}

# Plan a group and print it as readable lines: the header, then one line per member.
# $1 prefix chord, $2 spec, $3 action registry (defaults to a small stand-in).
plan() {
  local registry=${3:-'{
    ["volume.up"] = { desc = "Volume up", repeating = true },
    ["volume.mute"] = { desc = "Mute", exits = true },
    ["group.leave"] = { desc = "Leave", exits = true },
  }'}
  lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local groups = require('keymap.groups')
    local plan, err = groups.plan($1, $2, $registry)
    if err then
      print('error: ' .. err)
      return
    end
    print(('name=%s prefix=%s desc=%s'):format(plan.name, plan.prefix, plan.desc))
    for _, m in ipairs(plan.members) do
      print(('%s|%s|%s'):format(m.chord, tostring(m.action), tostring(m.exits)))
    end"
}

# --- the shape of a group -------------------------------------------------------------

@test "a group plans one member per key, in a stable order" {
  run plan '"SUPER + v"' '{ desc = "Volume", keys = {
    ["k"] = "volume.up", ["m"] = "volume.mute" } }'
  assert_line --index 0 "name=volume prefix=SUPER + v desc=Volume"
  assert_line --index 1 "Escape|group.leave|true"
  assert_line --index 2 "k|volume.up|false"
  assert_line --index 3 "m|volume.mute|true"
}

@test "the submap name is a slug of the description, since waybar shows it" {
  run plan '"SUPER + w"' '{ desc = "Window management", keys = { ["k"] = "volume.up" } }'
  assert_line --index 0 --partial "name=window-management"
}

@test "an explicit name wins over the description" {
  run plan '"SUPER + v"' '{ name = "vol", desc = "Volume", keys = { ["k"] = "volume.up" } }'
  assert_line --index 0 --partial "name=vol"
}

@test "which members leave the group comes from the action, not the group" {
  # `k` repeats -- k k k keeps working -- and `m` acts once and leaves. That is the
  # distinction define_submap's own auto-reset parameter cannot express, since it
  # returns after any bind at all.
  run plan '"SUPER + v"' '{ desc = "Volume", keys = {
    ["k"] = "volume.up", ["m"] = "volume.mute" } }'
  assert_line "k|volume.up|false"
  assert_line "m|volume.mute|true"
}

# --- leaving ---------------------------------------------------------------------------

@test "Escape leaves every group without the group having to say so" {
  run plan '"SUPER + v"' '{ desc = "Volume", keys = { ["k"] = "volume.up" } }'
  assert_line "Escape|group.leave|true"
}

@test "a group that binds Escape itself keeps its own, rather than being bound twice" {
  run plan '"SUPER + v"' '{ desc = "Volume", keys = {
    ["Escape"] = "volume.mute", ["k"] = "volume.up" } }'
  assert_line "Escape|volume.mute|true"
  refute_line "Escape|group.leave|true"
}

# --- what it leaves to the binder -----------------------------------------------------

@test "a member written inline is passed through untouched, so resolution has one home" {
  run plan '"SUPER + v"' '{ desc = "Volume", keys = {
    ["k"] = { desc = "Louder", kind = "exec", cmd = "volume up" } } }'
  assert_line --index 2 --partial "k|table"
}

@test "an action the registry does not know is passed through for the binder to report" {
  # keymap.lua already says "no action named ..." and names the chord; a second error
  # path here would mean two ways to hear about one mistake.
  run plan '"SUPER + v"' '{ desc = "Volume", keys = { ["k"] = "volume.nope" } }'
  assert_line "k|volume.nope|false"
}

@test "a member keeps the spelling it was written with, since keysyms are case-sensitive" {
  run plan '"SUPER + v"' '{ desc = "Volume", keys = { ["SHIFT + k"] = "volume.up" } }'
  assert_line "SHIFT + k|volume.up|false"
}

# --- what is refused -------------------------------------------------------------------

@test "a group with no keys is an error that names the prefix" {
  run plan '"SUPER + v"' '{ desc = "Volume", keys = {} }'
  assert_output --partial "error:"
  assert_output --partial "SUPER + v"
}

@test "a group with no description is an error: the cheatsheet has nothing to show" {
  run plan '"SUPER + v"' '{ keys = { ["k"] = "volume.up" } }'
  assert_output --partial "error:"
}

@test "a group inside a group is refused rather than half-working" {
  run plan '"SUPER + v"' '{ desc = "Volume", keys = {
    ["g"] = { kind = "group", desc = "Deeper", keys = { ["k"] = "volume.up" } } } }'
  assert_output --partial "error:"
  assert_output --partial "SUPER + v"
}

# --- the idle timeout is one number, stated once ---------------------------------------

@test "the idle timeout is exposed as a number, so the binder and the docs agree" {
  run lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    print(require('keymap.groups').TIMEOUT)"
  assert_output "1500"
}
