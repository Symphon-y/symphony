-- Target: ~/.config/hypr/keymap.lua (linked by install/link-home)
--
-- Turns the keymap into bindings: the shipped defaults, the user's file laid over
-- them per key, one hl.bind per surviving entry.
--
-- This and keymap/groups.lua are the only files here that touch `hl`; the rest are
-- pure, which is what lets them be unit-tested under /usr/bin/lua with no compositor.
--
-- Nothing in here may cost a session. A broken user file, an unknown action name, an
-- unknown scope: each is reported and skipped, because Hyprland coming up with zero
-- binds leaves no way to open a terminal and fix it.

local actions = require("keymap.actions")
local defaults = require("keymap.defaults")
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

local user, err = userconfig.load("keymap")
if err then
  notify("your keymap was not loaded, using defaults -- " .. err)
end

for _, entry in ipairs(merge.entries(merge.merge(defaults, user or {}))) do
  local scope = SCOPES[entry.scope]
  local action = entry.action

  -- A string names an entry in the registry; a table is one written inline; a
  -- function is anything the registry does not cover.
  if type(action) == "string" then
    local named = actions[action]
    if not named then
      notify(("no action named %q, from %s"):format(action, entry.chord))
    end
    action = named
  end

  if not scope then
    notify(("unknown scope %q, from %s"):format(entry.scope, entry.chord))
  elseif type(action) == "function" then
    hl.bind(entry.chord, action, { locked = scope.locked, description = entry.chord })
  elseif type(action) == "table" and action.kind == "exec" and action.cmd then
    hl.bind(entry.chord, hl.dsp.exec_cmd(action.cmd), {
      description = action.desc,
      locked = scope.locked,
      repeating = action.repeating,
    })
  elseif action ~= nil then
    notify(("cannot bind %s: no command for it"):format(entry.chord))
  end
end
