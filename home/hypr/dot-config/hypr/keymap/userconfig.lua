-- Target: ~/.config/hypr/keymap/userconfig.lua (linked by install/link-home)
--
-- Reads ~/.config/symphony/<name>.lua -- the files that are the user's, seeded once
-- by install/link-home and never overwritten.
--
-- The rule this module exists to keep: a broken user file must never cost a session.
-- Each file is loaded on its own with pcall, so a bad options.lua does not take
-- keymap.lua with it, and a failure comes back as an error to report rather than
-- being raised. Hyprland with zero binds is the outcome being avoided.
--
-- Pure: reporting is the caller's job (keymap.lua raises the notification), which is
-- what lets this run under /usr/bin/lua with no compositor.

local M = {}

-- SYMPHONY_CONFIG_DIR exists for the tests; everything else uses the real path.
function M.dir()
  return os.getenv("SYMPHONY_CONFIG_DIR") or (os.getenv("HOME") .. "/.config/symphony")
end

-- Returns the table the file returned, or nil. A second return value is an error
-- string, and only when something is actually wrong: a file that is simply absent is
-- the normal case on a machine with no overrides, and a file that returns nothing is
-- a legitimately empty one -- the seeded files start as comments.
function M.load(name)
  local path = M.dir() .. "/" .. name .. ".lua"

  local chunk, syntax_error = loadfile(path)
  if not chunk then
    -- loadfile cannot tell "no such file" from "unreadable" without a stat, so ask.
    local handle = io.open(path, "r")
    if not handle then
      return nil, nil
    end
    handle:close()
    return nil, syntax_error
  end

  local ok, value = pcall(chunk)
  if not ok then
    return nil, string.format("%s.lua: %s", name, tostring(value))
  end
  if value == nil then
    return nil, nil
  end
  if type(value) ~= "table" then
    return nil, string.format("%s.lua: expected it to return a table, got %s", name, type(value))
  end
  return value, nil
end

return M
