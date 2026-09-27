-- Target: ~/.config/hypr/keymap/actions.lua (linked by install/link-home)
--
-- Every verb the keymap can bind, once. A keymap entry names one of these, so the
-- same verb reached from a hardware key, a chord or (later) a prefix group is the
-- same thing -- and the cheatsheet is a view of this table rather than a second list
-- to keep in sync.
--
-- `kind` is a declarative spec, not a live hl.dsp.* object. That is the one choice
-- that lets this file be read by /usr/bin/lua in a unit test with no compositor.
--
--   desc       what the cheatsheet shows; every generated bind carries one, because
--              `hyprctl binds -j` reports dispatcher "__lua" for every Lua bind and
--              `description` is the only field a test can asserted against
--   kind/cmd   "exec" plus a command line
--   kind/dsp   "dispatch" plus one of Hyprland's own dispatchers, named as a dotted
--              path under hl.dsp, with `args` when it takes a table. A new dispatcher
--              is a line here, never a branch in keymap.lua
--   repeating  holding the key repeats the action (volume, yes; mute, no)
--   exits      leaves a prefix group after acting (Phase 21 Task D)
--
-- Pure: no `hl`.

local M = {
  ["volume.up"] = { desc = "Volume up", kind = "exec", cmd = "volume up", repeating = true },
  ["volume.down"] = { desc = "Volume down", kind = "exec", cmd = "volume down", repeating = true },
  ["volume.mute"] = { desc = "Mute", kind = "exec", cmd = "volume mute", exits = true },

  ["screen.brighter"] = { desc = "Brightness up", kind = "exec", cmd = "brightness up", repeating = true },
  ["screen.dimmer"] = { desc = "Brightness down", kind = "exec", cmd = "brightness down", repeating = true },

  -- Not `repeating`: each press is a USB transaction, and holding the key made several
  -- alienfx processes fight over the controller. Three presses cover the whole range --
  -- off, dim, full is everything the hardware has.
  ["keyboard.brighter"] = { desc = "Keyboard light up", kind = "exec", cmd = "keyboard-backlight up" },
  ["keyboard.dimmer"] = { desc = "Keyboard light down", kind = "exec", cmd = "keyboard-backlight down" },
  ["keyboard.off"] = { desc = "Keyboard light off", kind = "exec", cmd = "keyboard-backlight off", exits = true },

  -- Leaving a prefix group. The exit itself comes from `exits`, the same field every
  -- other action uses; this entry exists so Escape is listed on the cheatsheet rather
  -- than being invisible machinery.
  ["group.leave"] = { desc = "Close this group", kind = "leave", exits = true },

  ["player.play-pause"] = { desc = "Play/pause", kind = "exec", cmd = "player play-pause" },
  ["player.next"] = { desc = "Next track", kind = "exec", cmd = "player next" },
  ["player.previous"] = { desc = "Previous track", kind = "exec", cmd = "player previous" },

  -- Apps and the session. Every one of these calls a role -- a script on PATH or the
  -- terminal role through xdg-terminal-exec -- never a program by name, so replacing
  -- the terminal or the launcher is a change to the role and not to the keymap.
  ["app.terminal"] = { desc = "Terminal", kind = "exec", cmd = "xdg-terminal-exec" },
  ["app.launcher"] = { desc = "Launcher", kind = "exec", cmd = "fuzzel" },
  ["session.lock"] = { desc = "Lock the screen", kind = "exec", cmd = "hyprlock" },
  ["session.power-menu"] = { desc = "Power menu", kind = "exec", cmd = "power-menu", exits = true },
  ["session.exit"] = { desc = "Exit Hyprland", kind = "dispatch", dsp = "exit" },
  ["keys.cheatsheet"] = { desc = "Keybindings", kind = "exec", cmd = "symphony-keys", exits = true },
  ["window.close"] = { desc = "Close window", kind = "dispatch", dsp = "window.close" },

  -- Menus: the same pickers the bar's icons open, on a key too, because a small icon
  -- is hard to hit.
  ["menu.clipboard"] = { desc = "Clipboard history", kind = "exec", cmd = "clipboard-menu", exits = true },
  ["menu.network"] = { desc = "Wi-Fi networks", kind = "exec", cmd = "network-menu", exits = true },
  ["wallpaper.random"] = { desc = "Random wallpaper", kind = "exec", cmd = "wallpaper-random", exits = true },

  -- Capture.
  ["capture.screenshot"] = { desc = "Screenshot", kind = "exec", cmd = "screenshot", exits = true },
  ["capture.colour"] = { desc = "Pick a colour", kind = "exec", cmd = "hyprpicker -a", exits = true },
  ["capture.record"] = { desc = "Record the screen", kind = "exec", cmd = "screen-record", exits = true },
  ["capture.qr"] = { desc = "Scan a QR code", kind = "exec", cmd = "qr-capture", exits = true },

  -- Focus, by direction.
  ["focus.left"] = { desc = "Focus left", kind = "dispatch", dsp = "focus", args = { direction = "left" } },
  ["focus.right"] = { desc = "Focus right", kind = "dispatch", dsp = "focus", args = { direction = "right" } },
  ["focus.up"] = { desc = "Focus up", kind = "dispatch", dsp = "focus", args = { direction = "up" } },
  ["focus.down"] = { desc = "Focus down", kind = "dispatch", dsp = "focus", args = { direction = "down" } },
}

-- Ten workspaces, switched and moved to. One piece of knowledge repeated twenty times,
-- so a loop -- unlike keymap/defaults.lua, which spells every chord out because it is
-- the reference a person copies lines from.
for i = 1, 10 do
  M["workspace." .. i] =
    { desc = "Workspace " .. i, kind = "dispatch", dsp = "focus", args = { workspace = i } }
  M["workspace.move." .. i] = {
    desc = "Move window to workspace " .. i,
    kind = "dispatch",
    dsp = "window.move",
    args = { workspace = i },
  }
end

return M
