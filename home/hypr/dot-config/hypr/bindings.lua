-- Target: ~/.config/hypr/bindings.lua
--
-- Phase 4 kept this to just enough to open a terminal, close a window, lock, and
-- exit. Phase 5 adds the real keybinding scheme: launcher, power menu, clipboard
-- history, screenshots/recording, and workspace navigation.
--
-- Modifier convention (recorded from Phase 3's Omarchy research,
-- docs/omarchy-influences.md): SUPER = primary actions, SUPER+SHIFT =
-- move/secondary, SUPER+CTRL = panels/toggles, SUPER+ALT = secondary window
-- actions. PRINT family = capture, matching that same research.
--
-- Every action calls a role (a script under ~/.local/bin, or the $terminal role
-- via xdg-terminal-exec) -- never a hardcoded executable (CLAUDE.md's
-- dependency-inversion principle).

local mainMod = "SUPER"

-- Core (Phase 4)
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("xdg-terminal-exec"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())

-- Launcher, menu, clipboard (Phase 5)
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("power-menu"))
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("clipboard-menu"))

-- Capture (Phase 5) -- PRINT family, matching the convention already recorded
-- from Phase 3's research
hl.bind("PRINT", hl.dsp.exec_cmd("screenshot"))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("screen-record"))
hl.bind(mainMod .. " + CTRL + PRINT", hl.dsp.exec_cmd("qr-capture"))

-- Wallpaper (Phase 6) -- SUPER+CTRL, same "panels/toggles" category as clipboard
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("wallpaper-random"))

-- Workspace navigation (Phase 5)
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
