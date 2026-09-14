-- Target: ~/.config/hypr/bindings.lua
--
-- Deliberately minimal for Phase 4: just enough to open a terminal, close a window,
-- lock the session, and exit. The real keybinding scheme (launcher, menus, workspace
-- switching, screenshots, clipboard) is Phase 5's scope.
--
-- The terminal bind calls the $terminal role (xdg-terminal-exec), never a hardcoded
-- executable (CLAUDE.md's dependency-inversion principle).

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("xdg-terminal-exec"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
