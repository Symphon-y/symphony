-- Target: ~/.config/hypr/keymap/cheatsheet.lua (linked by install/link-home)
--
-- The rows behind SUPER+K (#17): every binding, and what it does.
--
-- A *view* of the keymap, not a second list. It reads the same defaults, the same user
-- overrides and the same action registry that keymap.lua binds from, so a rebound key
-- shows the binding it has now and a list that has gone stale is not possible. That is
-- also why the descriptions live in actions.lua and not here.
--
-- Pure: no `hl`, so `symphony-keys` can print the list with no compositor running.

local groups = require("keymap.groups")
local merge = require("keymap.merge")

local M = {}

-- Rows come out grouped by what they are for, because a cheatsheet is browsed as well as
-- filtered -- and sorting by chord would scatter the workspace keys through the rest.
-- Categories are the first segment of an action name, so this list is the only ordering
-- knowledge in the project; anything new sorts after it, by name.
local CATEGORY_ORDER = {
  "app",
  "window",
  "workspace",
  "focus",
  "session",
  "capture",
  "menu",
  "wallpaper",
  "volume",
  "screen",
  "keyboard",
  "player",
  "keys",
}

local RANK = {}
for i, category in ipairs(CATEGORY_ORDER) do
  RANK[category] = i
end

local function category_of(action)
  return tostring(action):match("^([^.]+)") or ""
end

local function rank(category)
  return RANK[category] or (#CATEGORY_ORDER + 1)
end

-- A group's rows: the prefix, then each member as the whole sequence to press. A member
-- chord reads as a complete instruction on its own, because filtering shows rows without
-- the prefix above them.
--
-- The group sits with the category its members belong to -- the Capture group beside the
-- PRINT chords -- so the first member decides, skipping the leave action that every group
-- has and that would otherwise decide for the ones whose keys sort after Escape.
local function group_rows(entry, registry)
  local plan = groups.plan(entry.chord, entry.action, registry)
  if not plan then
    return nil
  end

  local out = {
    category = "group",
    { chord = plan.prefix, desc = plan.desc .. "...", action = plan.name },
  }
  for _, member in ipairs(plan.members) do
    local named = type(member.action) == "string" and registry[member.action] or member.action
    if type(named) == "table" and named.desc then
      out[#out + 1] = {
        chord = plan.prefix .. "  " .. member.chord,
        desc = named.desc,
        action = member.action,
      }
      if out.category == "group" and member.action ~= groups.LEAVE then
        out.category = category_of(member.action)
      end
    end
  end
  return out
end

-- The rows, in order, and how many bindings were skipped -- a typo in a keymap should be
-- visible rather than a blank line in the list.
function M.rows(defaults, user, registry)
  local rows, skipped = {}, 0

  for _, entry in ipairs(merge.entries(merge.merge(defaults, user))) do
    if type(entry.action) == "table" and entry.action.kind == "group" then
      local block = group_rows(entry, registry)
      if not block then
        skipped = skipped + 1
      else
        -- Sorted as a block so a group's members stay under their prefix.
        block.sort_key = ("%02d %s"):format(rank(block.category), entry.chord)
        rows[#rows + 1] = block
      end
    else
      local named = type(entry.action) == "string" and registry[entry.action] or entry.action
      if type(named) ~= "table" or type(named.desc) ~= "string" or named.desc == "" then
        skipped = skipped + 1
      else
        local category = category_of(entry.action)
        rows[#rows + 1] = {
          sort_key = ("%02d %s"):format(rank(category), entry.chord),
          {
            chord = entry.chord,
            desc = named.desc,
            action = entry.action,
            category = category,
          },
        }
      end
    end
  end

  table.sort(rows, function(a, b)
    return a.sort_key < b.sort_key
  end)

  local flat = {}
  for _, block in ipairs(rows) do
    for _, row in ipairs(block) do
      flat[#flat + 1] = row
    end
  end
  return flat, skipped
end

-- The rows as aligned text, one per line: the chord padded to a common width, then what
-- it does. What fuzzel shows and what `symphony-keys text` prints, so the two cannot
-- disagree about the list.
function M.text(rows)
  local width = 0
  for _, row in ipairs(rows) do
    width = math.max(width, #row.chord)
  end

  local lines = {}
  for _, row in ipairs(rows) do
    lines[#lines + 1] = ("%-" .. width .. "s  %s"):format(row.chord, row.desc)
  end
  return lines
end

return M
