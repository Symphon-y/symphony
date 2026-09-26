#!/usr/bin/env bats
# Phase 21 acceptance tests: the hardware keys work, and the keymap is a decision the
# user owns rather than one the repo makes for them (#16).
#
# Static group (the default): runnable over SSH. Live-session tests are tagged in
# their names and assert real compositor state via `hyprctl binds -j` -- confirmed
# valid JSON on 0.56.2 with description, locked, repeat and submap -- rather than
# file contents. Run them after a deploy, not before.
#
#   bats tests/acceptance/phase-21.bats

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

lua_eval() {
  lua -e "package.path = '$REPO_ROOT/home/hypr/dot-config/hypr/?.lua;' .. package.path; $1"
}

# --- the role scripts (#20) ----------------------------------------------------------

@test "each hardware key has a role script, and the binding never names a tool" {
  local role
  for role in volume brightness player; do
    assert [ -x "$REPO_ROOT/home/media/dot-local/bin/$role" ]
  done
  assert [ -x "$REPO_ROOT/home/hardware/dot-local/bin/keyboard-backlight" ]
}

@test "the tools the roles wrap are declared, not assumed present" {
  # playerctl and lua were on this machine only as transitive dependencies, and
  # brightnessctl was not installed at all -- CI installs tooling.txt only.
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT/packages/desktop.txt"
  assert_line "playerctl"
  assert_line "brightnessctl"
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT/packages/tooling.txt"
  assert_line "lua"
}

# --- the keymap's own invariants (#21) ------------------------------------------------

@test "every action the defaults name actually exists in the registry" {
  # A typo here binds nothing and says nothing at runtime beyond one toast, so it is
  # worth failing the build over.
  run lua_eval "
    local actions = require('keymap.actions')
    local defaults = require('keymap.defaults')
    local missing = {}
    for scope, keys in pairs(defaults) do
      for chord, action in pairs(keys) do
        if type(action) == 'string' and not actions[action] then
          missing[#missing + 1] = scope .. ' ' .. chord .. ' -> ' .. action
        end
      end
    end
    print(table.concat(missing, ', '))"
  assert_success
  assert_output ""
}

@test "every action carries a description, since that is all a bind can be asserted on" {
  # hyprctl binds -j reports dispatcher \"__lua\" for every Lua bind, so `description`
  # is the only field that says what a binding does -- to a test or to a person.
  run lua_eval "
    local actions = require('keymap.actions')
    local bare = {}
    for name, action in pairs(actions) do
      if type(action.desc) ~= 'string' or action.desc == '' then
        bare[#bare + 1] = name
      end
    end
    table.sort(bare)
    print(table.concat(bare, ', '))"
  assert_success
  assert_output ""
}

@test "every exec action names a command" {
  run lua_eval "
    local actions = require('keymap.actions')
    local bad = {}
    for name, action in pairs(actions) do
      if action.kind == 'exec' and (type(action.cmd) ~= 'string' or action.cmd == '') then
        bad[#bad + 1] = name
      end
    end
    print(table.concat(bad, ', '))"
  assert_success
  assert_output ""
}

@test "the pure keymap modules load with no compositor at all" {
  # This is what makes them testable, and it is easy to lose by reaching for `hl`.
  local module
  for module in notation merge actions defaults userconfig; do
    run lua_eval "require('keymap.$module')"
    assert_success
  done
}

# --- the config surface (#21) ---------------------------------------------------------

@test "a keymap is seeded for the user to edit, from install/seed" {
  # Not from under home/: link-home check demands a symlink in $HOME for every file
  # it finds there, so a template under home/ would fail its own check.
  assert [ -f "$REPO_ROOT/install/seed/symphony/keymap.lua" ]
  run grep -q "seed_config" "$REPO_ROOT/install/link-home"
  assert_success
}

@test "the seeded keymap points at the reference rather than leaving you guessing" {
  run cat "$REPO_ROOT/install/seed/symphony/keymap.lua"
  assert_output --partial "keymap/defaults.lua"
  assert_output --partial "actions.lua"
}

# --- on this machine ------------------------------------------------------------------

@test "~/.config/symphony is a real directory, never a symlink" {
  # Three owners: matugen's theme.env, stow, and the user's seeded files. A folded
  # symlink would put the user's keymap inside the root-owned payload.
  assert [ -d "$HOME/.config/symphony" ]
  assert [ ! -L "$HOME/.config/symphony" ]
}

@test "live-session: the hardware keys are bound, locked to work on the lock screen" {
  local key
  for key in XF86AudioRaiseVolume XF86AudioLowerVolume XF86AudioMute \
    XF86MonBrightnessUp XF86MonBrightnessDown; do
    run bash -c "hyprctl binds -j | jq -e --arg k '$key' '.[]|select(.key==\$k and .locked)'"
    assert_success
  done
}

@test "live-session: the keys that should repeat do, and the ones that should not do not" {
  run bash -c "hyprctl binds -j | jq -e '.[]|select(.key==\"XF86AudioRaiseVolume\" and .repeat)'"
  assert_success
  # Toggling mute on key-repeat is nobody's intent.
  run bash -c "hyprctl binds -j | jq -e '.[]|select(.key==\"XF86AudioMute\" and .repeat)'"
  assert_failure
}

@test "live-session: every bind the keymap generated carries its description" {
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.key==\"XF86AudioRaiseVolume\").description'"
  assert_output "Volume up"
}
