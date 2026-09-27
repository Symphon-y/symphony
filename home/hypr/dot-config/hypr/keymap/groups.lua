-- Target: ~/.config/hypr/keymap/groups.lua (linked by install/link-home)
--
-- A transient prefix group: one chord opens a submap that waits for one key.
--
--   SUPER + v    opens the volume group
--      k / j     up / down -- the group stays open, so k k k works
--      m         mute, then leaves
--      Escape    leaves, and so does 1.5 s of not pressing anything
--
-- A group is entered *only* by its explicit prefix and leaves on its own, so nothing is
-- ever swallowed while you type: nvim, less, fzf and bash's vi-mode keep every key they
-- claim. That is why #16 dropped the modal layer it started with.
--
-- This file is the pure half -- it turns a group's spec into the plan of binds it means.
-- keymap.lua performs that plan, being the one file here that touches `hl`.
--
-- Deliberately no `catchall`: a key the group does not bind reaches the focused window
-- instead of vanishing. With a 1.5 s window that is the safer failure, and it avoids the
-- additive-catchall trap -- `catchall` fires *in addition to* a matching explicit bind,
-- and every Lua bind carries handler "__lua", so the engine's own short-circuits never
-- apply to a Lua config.

local notation = require("keymap.notation")

local M = {}

-- How long a group waits before closing itself. The backstop that makes an open group
-- harmless: Escape is also bound, but this is what saves a group left open by accident.
M.TIMEOUT = 1500

-- The action every group falls back to for Escape. Named rather than inlined so the
-- cheatsheet lists leaving like any other binding.
M.LEAVE = "group.leave"

-- Submap names reach waybar's hyprland/submap module as they are, so they are slugs: a
-- description reads "Window management", the submap reads "window-management".
local function slug(text)
  return (tostring(text):lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

-- Turn one group spec into { name, prefix, desc, members }, or nil plus a reason.
--
-- `registry` is keymap/actions.lua: consulted only for `exits`, so an action it does not
-- know is passed through for keymap.lua to complain about once, in the one place that
-- already complains about unknown action names.
function M.plan(prefix, spec, registry)
  local where = notation.format(prefix)
  if type(spec.desc) ~= "string" or spec.desc == "" then
    return nil, ("the group on %s needs a desc: the cheatsheet has nothing to show without one"):format(where)
  end
  if type(spec.keys) ~= "table" or next(spec.keys) == nil then
    return nil, ("the group on %s has no keys, so the prefix would open nothing"):format(where)
  end

  local members, order = {}, {}
  for chord, action in pairs(spec.keys) do
    if type(action) == "table" and action.kind == "group" then
      return nil, ("the group on %s cannot contain another group (%s): a prefix opens one group, not a tree"):format(
        where, notation.format(chord))
    end
    local key = notation.canonical(chord)
    local named = type(action) == "string" and registry[action] or nil
    members[key] = {
      chord = notation.format(chord),
      action = action,
      exits = (named and named.exits) == true,
    }
    order[#order + 1] = key
  end

  -- Escape leaves, unless the group wanted that key for something else.
  local escape = notation.canonical("Escape")
  if not members[escape] then
    local leave = registry[M.LEAVE]
    members[escape] = {
      chord = notation.format("Escape"),
      action = M.LEAVE,
      exits = (leave and leave.exits) == true,
    }
    order[#order + 1] = escape
  end

  -- Sorted, so the binds a group produces are the same on every run and a test can
  -- assert against them.
  table.sort(order)
  local list = {}
  for _, key in ipairs(order) do
    list[#list + 1] = members[key]
  end

  return {
    name = spec.name or slug(spec.desc),
    prefix = where,
    desc = spec.desc,
    members = list,
  }
end

return M
