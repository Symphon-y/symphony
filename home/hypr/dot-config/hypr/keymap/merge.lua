-- Target: ~/.config/hypr/keymap/merge.lua (linked by install/link-home)
--
-- The user's keymap laid over the shipped defaults, per key.
--
-- Semantics, which are the substance of the config surface:
--   * whole-value replace, never a field-by-field merge -- otherwise a `desc` the
--     user once set would outlive the action it described, and the cheatsheet lies
--   * `false` unbinds a key; a scope set to `false` is dropped whole
--   * `true` keeps the shipped binding -- the readable counterpart to `false`, and
--     a way to say "I know about this key and I want it as it comes"
--   * a key or scope the user adds is created
--   * the result is emitted in a fixed order, so `hyprctl binds -j` is stable enough
--     for a test to assert against
--
-- Pure: no `hl`, so it runs under /usr/bin/lua with no compositor.

local notation = require("keymap.notation")

local M = {}

-- Exposed so callers and tests can look an entry up the way this module stores it.
M.key = notation.canonical

-- Scopes come out in this order; anything unrecognised sorts after, by name.
local SCOPE_ORDER = { always = 1, global = 2 }

local function index(scope)
  local out = {}
  for chord, action in pairs(scope or {}) do
    out[notation.canonical(chord)] = { chord = notation.format(chord), action = action }
  end
  return out
end

function M.merge(defaults, user)
  local merged = {}
  for name, scope in pairs(defaults or {}) do
    merged[name] = index(scope)
  end

  for name, scope in pairs(user or {}) do
    if scope == false then
      merged[name] = nil
    else
      merged[name] = merged[name] or {}
      for chord, action in pairs(scope) do
        local key = notation.canonical(chord)
        if action == false then
          merged[name][key] = nil
        elseif action == true then
          -- Keep whatever the defaults said. A key with no default stays unbound,
          -- which is what "as shipped" means for a key that ships unbound.
          merged[name][key] = merged[name][key] or nil
        else
          -- Overriding an existing key keeps the default's spelling of the chord and
          -- changes only the action: for letters `Q` and `q` are distinct keysyms, and
          -- the shipped spelling is the one known to work. A key the user *adds* is
          -- bound as they wrote it, since there is nothing else to go on.
          local existing = merged[name][key]
          merged[name][key] = {
            chord = existing and existing.chord or notation.format(chord),
            action = action,
          }
        end
      end
    end
  end

  return merged
end

-- A flat, ordered list of { scope, chord, action } -- what the binder walks.
function M.entries(merged)
  local names = {}
  for name in pairs(merged) do
    names[#names + 1] = name
  end
  table.sort(names, function(a, b)
    local ra, rb = SCOPE_ORDER[a] or 99, SCOPE_ORDER[b] or 99
    if ra ~= rb then
      return ra < rb
    end
    return a < b
  end)

  local out = {}
  for _, name in ipairs(names) do
    local keys = {}
    for key in pairs(merged[name]) do
      keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      local entry = merged[name][key]
      out[#out + 1] = { scope = name, chord = entry.chord, action = entry.action }
    end
  end
  return out
end

return M
