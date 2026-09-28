-- Target: ~/.config/hypr/keymap.lua (linked by install/link-home)
--
-- Turns the keymap into bindings: the shipped defaults, the user's file laid over
-- them per key, one hl.bind per surviving entry.
--
-- This is the only file here that touches `hl`; the rest are pure, which is what lets
-- them be unit-tested under /usr/bin/lua with no compositor.
--
-- Nothing in here may cost a session. A broken user file, an unknown action name, an
-- unknown scope: each is reported and skipped, because Hyprland coming up with zero
-- binds leaves no way to open a terminal and fix it.

local actions = require("keymap.actions")
local defaults = require("keymap.defaults")
local groups = require("keymap.groups")
local merge = require("keymap.merge")
local userconfig = require("keymap.userconfig")

-- What a scope means, in bind options. `always` is the lock screen too: adjusting
-- volume with the screen locked is the whole point of a hardware key.
local SCOPES = {
  always = { locked = true },
  global = { locked = false },
}

-- Even the complaint is wrapped: a failure to report a problem must not become a
-- second, worse problem.
local function notify(text)
  pcall(function()
    hl.notification.create({ text = "symphony: " .. text, timeout = 10000 })
  end)
end

-- --- an open prefix group ---------------------------------------------------------
--
-- One timer for the session, because only one group can be open at a time. Two things
-- about it were measured on 0.56.2 rather than read off the API's types:
--
--   * a "oneshot" timer cannot be re-armed. It fires once and set_timeout/set_enabled
--     do nothing after that, so an idle timeout built on one works for the first group
--     and never again. This is a "repeat" timer instead -- enabled only while a group
--     is open, and counting ticks of idleness, so the wait still measures from the last
--     keystroke rather than from when the group opened.
--   * a submap dispatched from inside a timer callback is *silently* ignored: the
--     dispatch returns ok, no submap event is emitted, the submap does not change. Only
--     the keybind and IPC paths are honoured. So a key that leaves dispatches directly,
--     and the timeout goes round through hyprctl, which is IPC.

local LEAVE_OVER_IPC = [[hyprctl dispatch 'hl.dsp.submap("reset")']]

local idle
local idle_ticks = 0

local function stop_idling()
  idle_ticks = 0
  if idle then
    idle:set_enabled(false)
  end
end

-- From a keybind: the submap can be dispatched directly, which is immediate.
local function close_group()
  hl.dispatch(hl.dsp.submap("reset"))
  stop_idling()
end

-- From the timer: the same thing, the long way round.
local function close_group_over_ipc()
  stop_idling()
  hl.dispatch(hl.dsp.exec_cmd(LEAVE_OVER_IPC))
end

local function on_tick()
  idle_ticks = idle_ticks + 1
  if idle_ticks * groups.TICK >= groups.TIMEOUT then
    close_group_over_ipc()
  end
end

local function hold_group_open()
  idle_ticks = 0
  if not idle then
    idle = hl.timer(on_tick, { timeout = groups.TICK, type = "repeat" })
  end
  idle:set_enabled(true)
end

-- A reload clears every bind and all of this Lua state but does *not* leave the current
-- submap, so a reload while a group was open would strand the session with no binds at
-- all. The event fires once this config has finished evaluating, which is exactly when
-- the stale submap needs dropping.
--
-- Only when a group is actually open, which is also what keeps `Hyprland --verify-config`
-- alive: verification fires this event with no compositor behind it, and dispatching a
-- submap from there segfaults -- measured, and not catchable, since the crash is at C
-- level and happens long after the pcall around the registration has returned.
-- get_current_submap is safe there and answers with an empty string.
pcall(function()
  hl.on("config.reloaded", function()
    local ok, submap = pcall(hl.get_current_submap)
    if ok and submap and submap ~= "" then
      close_group()
    end
  end)
end)

-- --- actions ----------------------------------------------------------------------
--
-- One place that turns an action into something bindable, so a verb reached from a
-- hardware key, a chord or a group's member is the same verb. Returns nil and a reason
-- rather than raising: an unbindable action costs its own key and nothing else.

local function resolve(action, chord)
  local spec = action
  if type(action) == "string" then
    spec = actions[action]
    if not spec then
      return nil, ("no action named %q, from %s"):format(action, chord)
    end
  end

  if type(spec) == "function" then
    return { run = spec, desc = chord }
  end
  if type(spec) == "table" and spec.kind == "exec" and spec.cmd then
    return { run = hl.dsp.exec_cmd(spec.cmd), desc = spec.desc, repeating = spec.repeating }
  end
  if type(spec) == "table" and spec.kind == "dispatch" and spec.dsp then
    -- The registry names a dispatcher as a dotted path, so adding one is a line in
    -- actions.lua rather than another branch here.
    local factory = hl.dsp
    for part in spec.dsp:gmatch("[^.]+") do
      factory = type(factory) == "table" and factory[part] or nil
    end
    if factory == nil then
      return nil, ("%s wants the dispatcher %q, which this Hyprland does not have"):format(chord, spec.dsp)
    end
    -- With no args, called with no argument at all: hl.dsp.focus(nil) raises "expected a
    -- table" while hl.dsp.no_op(nil) is fine, so the two are not interchangeable. And
    -- pcall, because a registry entry with the wrong shape for its dispatcher must cost
    -- its own key and not the session.
    local ok, dispatcher = pcall(function()
      if spec.args == nil then
        return factory()
      end
      return factory(spec.args)
    end)
    if not ok then
      return nil, ("%s cannot use %s: %s"):format(chord, spec.dsp, tostring(dispatcher))
    end
    return { run = dispatcher, desc = spec.desc, repeating = spec.repeating }
  end
  if type(spec) == "table" and spec.kind == "leave" then
    -- Leaving is what `exits` does below; this action exists so the cheatsheet lists
    -- Escape like any other key.
    return { run = function() end, desc = spec.desc }
  end

  -- Say what was written and what is valid. The old wording, "no command for it", named
  -- neither and left you guessing at your own config.
  local written = type(action) == "string" and ("%q"):format(action) or type(action)
  return nil,
    ("cannot bind %s: %s is not an action -- name one from actions.lua, or use "):format(chord, written)
      .. "false to unbind, true to keep the shipped binding."
end

local function bind_group(chord, spec, scope)
  local plan, problem = groups.plan(chord, spec, actions)
  if not plan then
    return notify(problem)
  end

  hl.define_submap(plan.name, function()
    for _, member in ipairs(plan.members) do
      local resolved, err = resolve(member.action, member.chord)
      if not resolved then
        notify(err)
      else
        hl.bind(member.chord, function()
          hl.dispatch(resolved.run)
          if member.exits then
            close_group()
          else
            hold_group_open()
          end
        end, {
          description = resolved.desc,
          locked = scope.locked,
          repeating = resolved.repeating,
        })
      end
    end
  end)

  hl.bind(plan.prefix, function()
    hl.dispatch(hl.dsp.submap(plan.name))
    hold_group_open()
  end, { description = plan.desc .. "...", locked = scope.locked })
end

-- --- the binding pass -------------------------------------------------------------

local user, err = userconfig.load("keymap")
if err then
  notify("your keymap was not loaded, using defaults -- " .. err)
end

for _, entry in ipairs(merge.entries(merge.merge(defaults, user or {}))) do
  local scope = SCOPES[entry.scope]

  if not scope then
    notify(("unknown scope %q, from %s"):format(entry.scope, entry.chord))
  elseif type(entry.action) == "table" and entry.action.kind == "group" then
    bind_group(entry.chord, entry.action, scope)
  else
    local resolved, problem = resolve(entry.action, entry.chord)
    if not resolved then
      notify(problem)
    else
      hl.bind(entry.chord, resolved.run, {
        description = resolved.desc,
        locked = scope.locked,
        repeating = resolved.repeating,
      })
    end
  end
end
