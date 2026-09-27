#!/usr/bin/env bats
# Unit tests for home/hypr/dot-config/hypr/keymap/cheatsheet.lua (Task F, #17): the rows
# behind SUPER+K.
#
# The cheatsheet is a *view* of the merged keymap, not a second list: it reads the same
# defaults, the same user overrides and the same action registry the binder does, so a
# rebound key shows what it is bound to now and a list that has gone stale is impossible.
#
# Pure Lua under /usr/bin/lua -- no compositor.

setup() {
  load '../helpers/common'
  HYPR="$REPO_ROOT/home/hypr/dot-config/hypr"
}

# Print the rows as "chord|desc" lines. $1 defaults, $2 user, $3 registry.
rows() {
  local registry=${3:-'{
    ["app.terminal"] = { desc = "Terminal", kind = "exec", cmd = "x" },
    ["window.close"] = { desc = "Close window", kind = "dispatch", dsp = "window.close" },
    ["volume.up"] = { desc = "Volume up", kind = "exec", cmd = "v" },
    ["volume.mute"] = { desc = "Mute", kind = "exec", cmd = "m", exits = true },
    ["group.leave"] = { desc = "Close this group", kind = "leave", exits = true },
  }'}
  lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local cheatsheet = require('keymap.cheatsheet')
    local list, skipped = cheatsheet.rows($1, $2, $registry)
    for _, row in ipairs(list) do
      print(row.chord .. '|' .. row.desc)
    end
    if skipped > 0 then
      print('skipped ' .. skipped)
    end"
}

# --- what it shows --------------------------------------------------------------------

@test "a row per binding, with what it does" {
  run rows '{ global = { ["SUPER + Return"] = "app.terminal" } }' '{}'
  assert_output "SUPER + Return|Terminal"
}

@test "the hardware keys are listed too: what a key does is the question being asked" {
  run rows '{ always = { ["XF86AudioRaiseVolume"] = "volume.up" } }' '{}'
  assert_output "XF86AudioRaiseVolume|Volume up"
}

@test "a rebound key shows the binding it has now, not the one it shipped with" {
  run rows '{ global = { ["SUPER + Return"] = "app.terminal" } }' \
    '{ global = { ["SUPER + Return"] = "window.close" } }'
  assert_output "SUPER + Return|Close window"
}

@test "a key the user unbound is not listed: the list is what is bound" {
  run rows '{ global = { ["SUPER + Return"] = "app.terminal", ["SUPER + Q"] = "window.close" } }' \
    '{ global = { ["SUPER + Q"] = false } }'
  assert_output "SUPER + Return|Terminal"
}

# --- groups ---------------------------------------------------------------------------

@test "a group is its prefix followed by its members, each a full sequence" {
  # A filtered row has to read as a complete instruction on its own, so a member's chord
  # is the whole sequence rather than the bare key.
  run rows '{ global = { ["SUPER + v"] = { kind = "group", desc = "Volume", keys = {
    ["k"] = "volume.up", ["m"] = "volume.mute" } } } }' '{}'
  assert_line --index 0 "SUPER + v|Volume..."
  assert_line --index 1 "SUPER + v  Escape|Close this group"
  assert_line --index 2 "SUPER + v  k|Volume up"
  assert_line --index 3 "SUPER + v  m|Mute"
}

@test "a group sits with the category its members belong to" {
  # Escape is in every group and sorts before j/k/m, so taking the first row's category
  # would file the Volume group under nothing at all and drop it to the end of the list.
  # app sorts first and player last, so a group filed under `volume` has to land between
  # them rather than after everything.
  run rows '{ global = { ["SUPER + v"] = { kind = "group", desc = "Volume", keys = {
    ["k"] = "volume.up" } }, ["SUPER + Return"] = "app.terminal",
    ["XF86AudioRaiseVolume"] = "volume.up", ["XF86AudioNext"] = "player.next" } }' \
    '{ }' '{
      ["app.terminal"] = { desc = "Terminal", kind = "exec", cmd = "x" },
      ["volume.up"] = { desc = "Volume up", kind = "exec", cmd = "v" },
      ["player.next"] = { desc = "Next track", kind = "exec", cmd = "p" },
      ["group.leave"] = { desc = "Close this group", kind = "leave", exits = true },
    }'
  # Terminal, then the group's three rows, then the flat volume key, then player last.
  assert_line --index 0 "SUPER + Return|Terminal"
  assert_line --index 1 "SUPER + v|Volume..."
  assert_line --index 5 "XF86AudioNext|Next track"
}

@test "a broken group is skipped rather than listed as an empty prefix" {
  run rows '{ global = { ["SUPER + z"] = { kind = "group", desc = "Broken", keys = {} },
    ["SUPER + Return"] = "app.terminal" } }' '{}'
  assert_line "SUPER + Return|Terminal"
  refute_output --partial "Broken"
  assert_output --partial "skipped 1"
}

# --- order ----------------------------------------------------------------------------

@test "rows come out in category order, so the list can be browsed as well as filtered" {
  # Not alphabetical by chord, which would scatter the workspace keys among the rest.
  run rows '{ global = { ["SUPER + Q"] = "window.close", ["XF86AudioRaiseVolume"] = "volume.up",
    ["SUPER + Return"] = "app.terminal" } }' '{}'
  assert_line --index 0 "SUPER + Return|Terminal"
  assert_line --index 1 "SUPER + Q|Close window"
  assert_line --index 2 "XF86AudioRaiseVolume|Volume up"
}

@test "the order is the same on every run, whatever order the tables were written in" {
  local first second
  first=$(rows '{ global = { ["SUPER + Q"] = "window.close", ["SUPER + Return"] = "app.terminal" } }' '{}')
  second=$(rows '{ global = { ["SUPER + Return"] = "app.terminal", ["SUPER + Q"] = "window.close" } }' '{}')
  assert_equal "$first" "$second"
}

# --- mistakes -------------------------------------------------------------------------

@test "an action the registry does not have is skipped and counted, never a blank row" {
  run rows '{ global = { ["SUPER + Z"] = "app.nonesuch", ["SUPER + Return"] = "app.terminal" } }' '{}'
  assert_line "SUPER + Return|Terminal"
  refute_output --partial "SUPER + Z|"
  assert_output --partial "skipped 1"
}

@test "nothing bound at all is an empty list rather than an error" {
  run rows '{}' '{}'
  assert_success
  assert_output ""
}

# --- how it reads ---------------------------------------------------------------------

@test "the text is two columns: every description starts at the same place" {
  # fuzzel is themed monospace, so padding is what makes the list scannable. The column
  # is set by the longest chord -- with a short one and a long one, both descriptions
  # still line up.
  run lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local cheatsheet = require('keymap.cheatsheet')
    local lines = cheatsheet.text({
      { chord = 'PRINT', desc = 'Screenshot' },
      { chord = 'SUPER + SHIFT + 0', desc = 'Move window to workspace 10' },
    })
    for _, line in ipairs(lines) do
      print((line:find('%S', #'SUPER + SHIFT + 0' + 1)))
    end"
  # Two spaces after the longest chord, so both descriptions begin at column 20.
  assert_line --index 0 "20"
  assert_line --index 1 "20"
}

# --- the shipped keymap ---------------------------------------------------------------

@test "every shipped binding makes it onto the cheatsheet" {
  # The anti-drift assertion: a cheatsheet that quietly omits a binding is worse than
  # none at all, so nothing in the real defaults may be skipped.
  run lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local cheatsheet = require('keymap.cheatsheet')
    local list, skipped = cheatsheet.rows(
      require('keymap.defaults'), {}, require('keymap.actions'))
    print(#list .. ' rows, ' .. skipped .. ' skipped')"
  assert_output --partial "0 skipped"
  refute_output --partial "^0 rows"
}
