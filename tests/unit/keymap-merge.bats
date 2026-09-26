#!/usr/bin/env bats
# Unit tests for home/hypr/dot-config/hypr/keymap/merge.lua (Task C, #21): the user's
# keymap laid over the shipped defaults, per key.
#
# The semantics are the whole point of the config surface, so they are pinned here:
# whole-value replace (never a deep merge, or a stale user `desc` outlives the action
# it described), `false` unbinds, a scope the user adds is created, and the result is
# emitted in a stable order so `hyprctl binds -j` can be asserted against.
#
# Pure Lua under /usr/bin/lua -- no compositor.

setup() {
  load '../helpers/common'
  # The same package.path Hyprland gives a config, so `require` resolves exactly
  # as it will in production.
  HYPR="$REPO_ROOT/home/hypr/dot-config/hypr"
}

# Merge two Lua table literals and print the result as sorted "scope|chord|action"
# lines, which is both readable and order-stable.
merge() {
  lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local merge = require('keymap.merge')
    local defaults = $1
    local user = $2
    for _, e in ipairs(merge.entries(merge.merge(defaults, user))) do
      print(e.scope .. '|' .. e.chord .. '|' .. tostring(e.action))
    end"
}

@test "with no user config the defaults come through unchanged" {
  run merge '{ global = { ["SUPER + Q"] = "window.close" } }' '{}'
  assert_output "global|SUPER + Q|window.close"
}

@test "a user value replaces the default for that key" {
  run merge '{ global = { ["SUPER + Q"] = "window.close" } }' \
    '{ global = { ["SUPER + Q"] = "window.kill" } }'
  assert_output "global|SUPER + Q|window.kill"
}

@test "the match is on the key, not the spelling" {
  run merge '{ global = { ["SUPER + Q"] = "window.close" } }' \
    '{ global = { ["super+q"] = "window.kill" } }'
  assert_output "global|SUPER + Q|window.kill"
}

@test "false unbinds a key entirely rather than leaving the default" {
  run merge '{ global = { ["SUPER + Q"] = "window.close", ["SUPER + W"] = "web" } }' \
    '{ global = { ["SUPER + Q"] = false } }'
  assert_output "global|SUPER + W|web"
}

@test "a key the user adds is kept alongside the defaults" {
  run merge '{ global = { ["SUPER + Q"] = "window.close" } }' \
    '{ global = { ["SUPER + T"] = "terminal" } }'
  assert_line "global|SUPER + Q|window.close"
  assert_line "global|SUPER + T|terminal"
}

@test "a scope the user adds is created" {
  run merge '{ global = { ["SUPER + Q"] = "window.close" } }' \
    '{ always = { ["XF86AudioMute"] = "volume.mute" } }'
  assert_line "always|XF86AudioMute|volume.mute"
  assert_line "global|SUPER + Q|window.close"
}

@test "a scope set to false drops the whole scope" {
  run merge '{ global = { ["SUPER + Q"] = "x" }, always = { ["XF86AudioMute"] = "m" } }' \
    '{ always = false }'
  assert_output "global|SUPER + Q|x"
}

@test "replacement is whole-value: a stale desc cannot outlive the action" {
  # A table value is replaced outright, not merged field by field -- otherwise a user
  # who once overrode `desc` would keep that label after the default action changed
  # underneath them, and the cheatsheet would lie.
  run lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local merge = require('keymap.merge')
    local m = merge.merge(
      { global = { ['SUPER + Q'] = { action = 'new', desc = 'New' } } },
      { global = { ['SUPER + Q'] = { action = 'mine' } } })
    local v = m.global[merge.key('SUPER + Q')].action
    print(tostring(v.action) .. ',' .. tostring(v.desc))"
  assert_output "mine,nil"
}

@test "the order is stable, so a test can assert against hyprctl binds" {
  run merge '{ global = { ["SUPER + W"] = "b", ["SUPER + A"] = "a", ["SUPER + Z"] = "c" } }' '{}'
  local first="$output"
  run merge '{ global = { ["SUPER + Z"] = "c", ["SUPER + A"] = "a", ["SUPER + W"] = "b" } }' '{}'
  assert_output "$first"
}

@test "scopes come out in a fixed order too" {
  run merge '{ global = { ["SUPER + Q"] = "g" }, always = { ["XF86AudioMute"] = "a" } }' '{}'
  assert_line --index 0 "always|XF86AudioMute|a"
  assert_line --index 1 "global|SUPER + Q|g"
}

@test "an empty user table changes nothing" {
  run merge '{ always = { ["XF86AudioMute"] = "volume.mute" } }' '{ always = {} }'
  assert_output "always|XF86AudioMute|volume.mute"
}

@test "the chord that comes out is the display form, ready for hl.bind" {
  run merge '{ global = {} }' '{ global = { ["super+shift+q"] = "x" } }'
  assert_output "global|SUPER + SHIFT + q|x"
}
