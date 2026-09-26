-- Target: ~/.config/hypr/bindings.lua
--
-- Phase 4 kept this to just enough to open a terminal, close a window, lock, and
-- exit. Phase 5 adds the real keybinding scheme: launcher, power menu, clipboard
-- history, screenshots/recording, and workspace navigation.
--
-- Modifier convention (adapted from Omarchy's, D-0033): SUPER = primary actions, SUPER+SHIFT =
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
-- Network picker (Phase 17): same as clicking the bar's Wi-Fi icon; a hotkey too,
-- because a small icon is hard to hit. network-menu edit is the icon's right-click.
hl.bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd("network-menu"))

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

-- Hardware media and brightness keys (Phase 21, issue #20). Probed with
-- `xkbcli interactive-wayland` on the Alienware: F6/F7 emit plain F6/F7, and the Fn
-- layer is resolved in firmware, arriving as real media keycodes from the AT keyboard
-- itself -- so these keysyms are all that is needed and no quirk is involved. They did
-- nothing before this only because nothing was bound.
--
-- Each calls a role script (home/media/), never a tool: the hardware difference lives
-- there, which is what will let the same verbs serve the SUPER+v group and a keyboard
-- with no media keys.
--
-- locked: they work on the lock screen, where adjusting volume is exactly what you
-- want. repeating: holding the key keeps moving, which is why the OSD replaces itself
-- rather than stacking.
local media = {
  { "XF86AudioRaiseVolume", "volume up", "Volume up", true },
  { "XF86AudioLowerVolume", "volume down", "Volume down", true },
  { "XF86AudioMute", "volume mute", "Mute", false },
  { "XF86MonBrightnessUp", "brightness up", "Brightness up", true },
  { "XF86MonBrightnessDown", "brightness down", "Brightness down", true },
  -- Keyboard lighting (#26), provisionally on SUPER + the same keys. The shipped
  -- default belongs in the keymap as a hardware-independent chord -- not every
  -- keyboard emits XF86MonBrightness at all -- with this machine's keys moving to
  -- ~/.config/symphony/keymap.lua when Task E migrates the lot.
  { mainMod .. " + XF86MonBrightnessUp", "keyboard-backlight up", "Keyboard light up", true },
  { mainMod .. " + XF86MonBrightnessDown", "keyboard-backlight down", "Keyboard light down", true },
  -- Not on this chassis, but standard elsewhere and harmless where the key never fires.
  { "XF86AudioPlay", "player play-pause", "Play/pause", false },
  { "XF86AudioNext", "player next", "Next track", false },
  { "XF86AudioPrev", "player previous", "Previous track", false },
}

for _, bind in ipairs(media) do
  local key, command, description, repeating = table.unpack(bind)
  hl.bind(key, hl.dsp.exec_cmd(command), {
    description = description,
    locked = true,
    repeating = repeating,
  })
end
