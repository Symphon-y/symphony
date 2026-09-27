-- Target: ~/.config/hypr/keymap/notation.lua (linked by install/link-home)
--
-- One way to write a chord, so two spellings of the same key compare equal.
--
-- A user writing `super+return` has to *override* a default written `SUPER + Return`,
-- not add a second binding for the same key. Comparison therefore happens on a
-- canonical form -- modifier aliases resolved, ordered, everything upper-cased --
-- while what reaches hl.bind keeps the key exactly as written, because keysyms are
-- not upper case: XF86AudioRaiseVolume and code:20 both have to survive intact.
--
-- Pure: no `hl`, so it runs under /usr/bin/lua in a unit test with no compositor.

local M = {}

-- The spellings Hyprland accepts for each modifier, mapped to the one we emit.
local MODIFIERS = {
  SUPER = "SUPER",
  WIN = "SUPER",
  MOD = "SUPER",
  LOGO = "SUPER",
  CTRL = "CTRL",
  CONTROL = "CTRL",
  ALT = "ALT",
  SHIFT = "SHIFT",
}

-- The order modifiers are emitted in, so two orderings of the same chord match.
local ORDER = { SUPER = 1, CTRL = 2, ALT = 3, SHIFT = 4 }

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The modifiers (canonical, ordered) and the key (as written).
function M.parse(chord)
  local seen, key = {}, ""
  for part in tostring(chord):gmatch("[^+]+") do
    local token = trim(part)
    if token ~= "" then
      local modifier = MODIFIERS[token:upper()]
      if modifier then
        seen[modifier] = true
      else
        key = token
      end
    end
  end

  local mods = {}
  for modifier in pairs(seen) do
    mods[#mods + 1] = modifier
  end
  table.sort(mods, function(a, b)
    return ORDER[a] < ORDER[b]
  end)
  return mods, key
end

-- What two spellings of the same key share. Only ever compared, never displayed.
function M.canonical(chord)
  local mods, key = M.parse(chord)
  return table.concat(mods, "+") .. "+" .. key:upper()
end

-- What hl.bind is given.
function M.format(chord)
  local mods, key = M.parse(chord)
  if #mods == 0 then
    return key
  end
  return table.concat(mods, " + ") .. " + " .. key
end

return M
