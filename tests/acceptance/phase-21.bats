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

@test "nothing but the unit runs the AlienFX painter" {
  # The bug this pins: wallpaper-set and keyboard-backlight each ran alienfx-theme
  # directly, in the caller's cgroup. Nothing owned the process lifetime, a repeating
  # key spawned one per press, and 25 of them wedged the controller -- the keys flashed
  # and no colour landed. Callers ask systemd; systemd owns exactly one painter.
  run bash -c "grep -rn --include='*' -E '(^|[^-])\\balienfx-theme\\b' \
    '$REPO_ROOT/home' '$REPO_ROOT/install' '$REPO_ROOT/scripts' \
    | grep -v 'dot-local/bin/alienfx-theme:' \
    | grep -v 'systemd/user/alienfx-theme.service' \
    | grep -v 'alienfx-theme.service' \
    | grep -v 'scripts/lib/lighting.bash' \
    | grep -v '^[^:]*:[0-9]*: *#'"
  assert_failure
}

@test "the painter's unit is bounded, so a wedged run is reaped" {
  run cat "$REPO_ROOT/home/hardware/dot-config/systemd/user/alienfx-theme.service"
  assert_success
  assert_output --partial "TimeoutStartSec="
}

@test "brightness never scales the colour" {
  # The bug this pins: dimming used to multiply the RGB channels, and with 16 levels
  # per channel the smallest lit channel rounds away first -- #cabeff's violet became
  # pure blue as it dimmed. Brightness is a hardware state (alienfx 0x1C) instead.
  run grep -nE '\$\(\(.*(r|g|b) \* |\* level|level / 100' \
    "$REPO_ROOT/home/hardware/dot-local/bin/alienfx-theme"
  assert_failure
}

@test "the installed alienfx understands --dim" {
  # Our patch adds the hardware dim command the library documents but never
  # implemented. A machine whose package predates it fails here.
  run bash -c "alienfx --help 2>&1 | grep -q -- '--dim'"
  assert_success
}

@test "the installed alienfx sends the dim inside the theme's transaction" {
  # The bug this pins: a dim of its own dies in _wait_controller_ready, because this
  # controller answers STATUS_READY only just after a reset -- so `--theme X --dim on`
  # painted the theme and then silently failed, leaving the keys at full. The dim is a
  # parameter of set_theme, sent while the controller is ready.
  run python -c "import inspect
from alienfx.core.controller import AlienFXController
print('dim' in inspect.signature(AlienFXController.set_theme).parameters)"
  assert_success
  assert_output "True"
}

@test "the stretch leaves every lit channel room to be dimmed" {
  # The hardware dim is multiplicative in the controller's 4 bits, so the saturation
  # stretch (D-0084) must stop short of a channel that rounds away when halved -- that
  # is what turned the violet blue. Pins the rule, not a colour.
  run grep -q 'DIM_FLOOR' "$REPO_ROOT/home/hardware/dot-local/bin/alienfx-theme"
  assert_success
}

@test "the installed alienfx cannot spin forever waiting for the controller" {
  # Upstream counts failures only inside `except TypeError`, which `bool(resp) and`
  # made unreachable -- so a contended controller loops without end. Our patch counts
  # every failed read. A machine whose package predates it fails here.
  # Asserting the patched *shape*: the count sits under `if not ready`, outside the
  # try/except. Grepping for `errcount += 1` near the read matches the unpatched form
  # too, since that is exactly where upstream's unreachable increment lives.
  run bash -c "grep -A1 'if not ready:' /usr/lib/python3*/site-packages/alienfx/core/controller.py | grep -q 'errcount += 1'"
  assert_success
}

# --- the keymap's own invariants (#21) ------------------------------------------------

@test "every action the defaults name actually exists in the registry" {
  # A typo here binds nothing and says nothing at runtime beyond one toast, so it is
  # worth failing the build over.
  run lua_eval "
    local actions = require('keymap.actions')
    local defaults = require('keymap.defaults')
    local missing = {}
    local function check(where, action)
      if type(action) == 'string' and not actions[action] then
        missing[#missing + 1] = where .. ' -> ' .. action
      end
    end
    for scope, keys in pairs(defaults) do
      for chord, action in pairs(keys) do
        check(scope .. ' ' .. chord, action)
        -- A group's members are named the same way, and are just as easy to typo.
        if type(action) == 'table' and action.kind == 'group' then
          for key, member in pairs(action.keys or {}) do
            check(scope .. ' ' .. chord .. ' ' .. key, member)
          end
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
  for module in notation merge actions defaults userconfig groups cheatsheet; do
    run lua_eval "require('keymap.$module')"
    assert_success
  done
}

@test "only keymap.lua reaches for hl, which is what keeps the rest testable" {
  # Comments stripped first: these modules talk *about* hl.bind without calling it.
  run bash -c "sed 's/--.*//' '$REPO_ROOT'/home/hypr/dot-config/hypr/keymap/*.lua | grep -n 'hl\\.'"
  assert_failure
}

# --- every chord is the user's now (#23) ----------------------------------------------

@test "every chord that used to be hardcoded is a keymap entry" {
  # These were raw hl.bind calls in bindings.lua, which is a read-only symlink into the
  # payload -- so none of them could be changed by the person using them. Spelling is
  # asserted exactly as it must reach hl.bind: for a letter, Q and q are distinct
  # keysyms, and the shipped spelling is the one known to work.
  local pair expected=(
    "SUPER + Return|app.terminal"
    "SUPER + Q|window.close"
    "SUPER + L|session.lock"
    "SUPER + SHIFT + Q|session.exit"
    "SUPER + SPACE|app.launcher"
    "SUPER + ESCAPE|session.power-menu"
    "SUPER + CTRL + V|menu.clipboard"
    "SUPER + CTRL + N|menu.network"
    "SUPER + CTRL + W|wallpaper.random"
    "PRINT|capture.screenshot"
    "SUPER + PRINT|capture.colour"
    "ALT + PRINT|capture.record"
    "SUPER + CTRL + PRINT|capture.qr"
    "SUPER + left|focus.left"
    "SUPER + right|focus.right"
    "SUPER + up|focus.up"
    "SUPER + down|focus.down"
    "SUPER + 1|workspace.1"
    "SUPER + 9|workspace.9"
    "SUPER + 0|workspace.10"
    "SUPER + SHIFT + 1|workspace.move.1"
    "SUPER + SHIFT + 0|workspace.move.10"
  )
  run lua_eval "
    local merge = require('keymap.merge')
    local defaults = require('keymap.defaults')
    for _, entry in ipairs(merge.entries(merge.merge(defaults, {}))) do
      print(entry.chord .. '|' .. tostring(entry.action))
    end"
  assert_success
  for pair in "${expected[@]}"; do
    assert_line "$pair"
  done
}

@test "all twenty workspace chords are there, switching and moving" {
  run lua_eval "
    local merge = require('keymap.merge')
    local defaults = require('keymap.defaults')
    local seen = 0
    for _, entry in ipairs(merge.entries(merge.merge(defaults, {}))) do
      if tostring(entry.action):match('^workspace%.') then
        seen = seen + 1
      end
    end
    print(seen)"
  assert_output "20"
}

@test "nothing hardcodes a binding any more: bindings.lua is gone" {
  assert [ ! -e "$REPO_ROOT/home/hypr/dot-config/hypr/bindings.lua" ]
  run grep -rn 'require("bindings")' "$REPO_ROOT/home/hypr"
  assert_failure
}

@test "an installed machine has its stale bindings.lua link removed" {
  # stow --restow unlinks what is *in* the package, so a file deleted from the payload
  # leaves its symlink behind pointing at nothing. Only a migration can clear that.
  run bash -c "grep -rl 'hypr/bindings.lua' '$REPO_ROOT/migrations/'"
  assert_success
}

@test "live-session: no binding is nameless" {
  # The whole point of #23. Every Lua bind reports dispatcher \"__lua\", so a bind with
  # no description cannot be identified at all -- not by a test, not by the cheatsheet,
  # not by a person. Before the migration this listed all 37 hardcoded chords.
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.description==\"\")|\"\(.modmask) \(.key)\"'"
  assert_success
  assert_output ""
}

@test "live-session: the migrated chords are bound where they always were" {
  local spec
  for spec in "64 Return" "64 Q" "64 L" "65 Q" "64 SPACE" "64 ESCAPE" "68 V" "68 N" \
    "68 W" "0 PRINT" "64 PRINT" "8 PRINT" "68 PRINT" "64 left" "64 1" "64 0" "65 0"; do
    run bash -c "hyprctl binds -j | jq -e --argjson m ${spec% *} --arg k '${spec#* }' \
      '.[]|select(.modmask==\$m and .key==\$k)'"
    assert_success
  done
}

# --- the cheatsheet (#17) -------------------------------------------------------------

@test "the cheatsheet ships, beside the keymap it reads" {
  assert [ -x "$REPO_ROOT/home/hypr/dot-local/bin/symphony-keys" ]
  # It runs `lua` itself, so lua is declared rather than relied on as hyprland's
  # dependency.
  run "$REPO_ROOT/scripts/pkglist" "$REPO_ROOT/packages/desktop.txt"
  assert_line "lua"
  assert_line "fuzzel"
}

@test "SUPER+K is the cheatsheet, and it is a view of the registry" {
  run grep -E '\["SUPER \+ K"\][[:space:]]*=[[:space:]]*"keys\.cheatsheet"' \
    "$REPO_ROOT/home/hypr/dot-config/hypr/keymap/defaults.lua"
  assert_success
  run grep -E '\["keys\.cheatsheet"\].*cmd = "symphony-keys"' \
    "$REPO_ROOT/home/hypr/dot-config/hypr/keymap/actions.lua"
  assert_success
}

@test "the cheatsheet lists every binding there is" {
  # A cheatsheet that quietly omits a binding is worse than none: it teaches you the
  # keymap is smaller than it is. Every entry must produce a row, and the group prefixes
  # must bring their members with them.
  run lua_eval "
    local cheatsheet = require('keymap.cheatsheet')
    local groups = require('keymap.groups')
    local merge = require('keymap.merge')
    local actions = require('keymap.actions')
    local defaults = require('keymap.defaults')

    local expected = 0
    for _, entry in ipairs(merge.entries(merge.merge(defaults, {}))) do
      expected = expected + 1
      if type(entry.action) == 'table' and entry.action.kind == 'group' then
        expected = expected + #groups.plan(entry.chord, entry.action, actions).members
      end
    end

    local rows, skipped = cheatsheet.rows(defaults, {}, actions)
    print(('%d rows, %d expected, %d skipped'):format(#rows, expected, skipped))"
  assert_success
  run bash -c "echo '$output' | awk -F'[ ,]+' '{ exit !(\$1 == \$3 && \$5 == 0) }'"
  assert_success
}

@test "the promise the keymap makes about symphony-keys is true" {
  # defaults.lua and the seeded keymap both tell the reader to run `symphony-keys
  # defaults`; that was a lie until this task.
  run grep -q "symphony-keys defaults" "$REPO_ROOT/home/hypr/dot-config/hypr/keymap/defaults.lua"
  assert_success
  run grep -qE '^ *defaults\)' "$REPO_ROOT/home/hypr/dot-local/bin/symphony-keys"
  assert_success
}

@test "live-session: SUPER+K is bound and says what it is" {
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.modmask==64 and .key==\"K\").description'"
  assert_output "Keybindings"
}

# --- transient prefix groups (#22) ----------------------------------------------------

@test "every group the defaults ship plans without complaint" {
  # A group with no desc, no keys, or a group nested inside it is reported at runtime as
  # a toast and then silently does nothing. Worth failing the build over instead.
  run lua_eval "
    local actions = require('keymap.actions')
    local defaults = require('keymap.defaults')
    local groups = require('keymap.groups')
    local problems = {}
    for scope, keys in pairs(defaults) do
      for chord, action in pairs(keys) do
        if type(action) == 'table' and action.kind == 'group' then
          local plan, err = groups.plan(chord, action, actions)
          if not plan then
            problems[#problems + 1] = scope .. ' ' .. chord .. ': ' .. err
          end
        end
      end
    end
    print(table.concat(problems, ', '))"
  assert_success
  assert_output ""
}

@test "every group can be left by Escape, whatever its author wrote" {
  # The timeout is the backstop; Escape is the one a person reaches for. A group that
  # could only be left by waiting would be a trap.
  run lua_eval "
    local actions = require('keymap.actions')
    local defaults = require('keymap.defaults')
    local groups = require('keymap.groups')
    local stuck = {}
    for scope, keys in pairs(defaults) do
      for chord, action in pairs(keys) do
        if type(action) == 'table' and action.kind == 'group' then
          local escapable = false
          for _, member in ipairs(groups.plan(chord, action, actions).members) do
            if member.chord == 'Escape' and member.exits then
              escapable = true
            end
          end
          if not escapable then
            stuck[#stuck + 1] = scope .. ' ' .. chord
          end
        end
      end
    end
    print(table.concat(stuck, ', '))"
  assert_success
  assert_output ""
}

@test "a reload cannot strand the session inside an open group" {
  # Hyprland clears every bind and all of this Lua state on a reload but does NOT leave
  # the current submap, so without this the keyboard would answer to nothing at all.
  run grep -q 'config.reloaded' "$REPO_ROOT/home/hypr/dot-config/hypr/keymap.lua"
  assert_success
}

@test "an open group is shown by waybar's own module, with no script behind it" {
  run bash -c "jq -e '.\"modules-left\"|index(\"hyprland/submap\")' \
    <(sed 's://.*::' '$REPO_ROOT/home/waybar/dot-config/waybar/config.jsonc')"
  assert_success
  run bash -c "jq -e '.\"hyprland/submap\".\"hide-empty-text\"' \
    <(sed 's://.*::' '$REPO_ROOT/home/waybar/dot-config/waybar/config.jsonc')"
  assert_success
}

@test "live-session: the prefix opens a group, and the group's keys are bound in it" {
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.modmask==64 and .key==\"v\").description'"
  assert_output "Volume..."
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.submap==\"volume\")|.key' | sort | tr '\n' ' '"
  assert_output "Escape j k m "
}

@test "live-session: the group's keys keep it open or leave it, as the action says" {
  # k repeats -- k k k works -- and m acts once and leaves. Asserted through `repeat`,
  # the only part of that distinction hyprctl can see.
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.submap==\"volume\" and .key==\"k\")|.repeat'"
  assert_output "true"
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.submap==\"volume\" and .key==\"m\")|.repeat'"
  assert_output "false"
}

@test "the keyboard-light default does not sit on an Fn-layer keysym" {
  # Measured on the Alienware: XF86MonBrightnessUp/Down are emitted by the firmware's
  # Fn layer and do NOT arrive when SUPER is also held -- SUPER+Fn+PgUp fired nothing
  # at all, neither the keyboard light nor the screen. So a modified XF86* chord is
  # not a binding a default can rely on.
  run lua_eval "
    local defaults = require('keymap.defaults')
    local bad = {}
    for scope, keys in pairs(defaults) do
      for chord, action in pairs(keys) do
        if type(action) == 'string' and action:match('^keyboard%.')
          and chord:match('XF86') and chord:match('%+') then
          bad[#bad + 1] = chord
        end
      end
    end
    print(table.concat(bad, ', '))"
  assert_success
  assert_output ""
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

@test "live-session: the keyboard light is on a chord that actually fires" {
  local key
  for key in Prior Next; do
    run bash -c "hyprctl binds -j | jq -e --arg k '$key' '.[]|select(.key==\$k and .modmask==64)'"
    assert_success
  done
}

@test "live-session: every bind the keymap generated carries its description" {
  run bash -c "hyprctl binds -j | jq -r '.[]|select(.key==\"XF86AudioRaiseVolume\").description'"
  assert_output "Volume up"
}
