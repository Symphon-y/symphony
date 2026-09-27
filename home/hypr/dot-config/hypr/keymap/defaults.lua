-- Target: ~/.config/hypr/keymap/defaults.lua (linked by install/link-home)
--
-- The keymap this system ships with -- every binding, in one place. Copy a line into
-- ~/.config/symphony/keymap.lua to change it; that file wins, per key. `false` unbinds,
-- `true` keeps it as shipped. This file is a read-only symlink into the payload and is
-- replaced by every symphony-update, so it is always the current reference --
-- `symphony-keys defaults` opens it.
--
-- Scopes:
--   always   live everywhere, including the lock screen. Hardware keys belong here.
--   global   ordinary chords, live in a normal session.
--
-- A value is the name of an entry in keymap/actions.lua, or a prefix group written
-- inline. A group is one value: overriding it means writing the whole group, not one of
-- its keys.
--
-- Modifier convention (adapted from Omarchy's, D-0033): SUPER = primary actions,
-- SUPER+SHIFT = move/secondary, SUPER+CTRL = panels/toggles. The PRINT family is
-- capture. Prefix groups reach the same actions without a modifier to hold, and both
-- routes stay bound: a chord you already know never stops working.

return {
  always = {
    ["XF86AudioRaiseVolume"] = "volume.up",
    ["XF86AudioLowerVolume"] = "volume.down",
    ["XF86AudioMute"] = "volume.mute",

    ["XF86MonBrightnessUp"] = "screen.brighter",
    ["XF86MonBrightnessDown"] = "screen.dimmer",

    -- Not on this chassis, but standard elsewhere and harmless where they never fire.
    ["XF86AudioPlay"] = "player.play-pause",
    ["XF86AudioNext"] = "player.next",
    ["XF86AudioPrev"] = "player.previous",
  },

  global = {
    -- Core.
    ["SUPER + Return"] = "app.terminal",
    ["SUPER + Q"] = "window.close",
    ["SUPER + L"] = "session.lock",
    ["SUPER + SHIFT + Q"] = "session.exit",
    ["SUPER + SPACE"] = "app.launcher",
    ["SUPER + ESCAPE"] = "session.power-menu",

    -- What everything else is bound to (#17). The chord Omarchy uses, so muscle memory
    -- carries over.
    ["SUPER + K"] = "keys.cheatsheet",

    -- Panels and pickers.
    ["SUPER + CTRL + V"] = "menu.clipboard",
    ["SUPER + CTRL + N"] = "menu.network",
    ["SUPER + CTRL + W"] = "wallpaper.random",

    -- Capture.
    ["PRINT"] = "capture.screenshot",
    ["SUPER + PRINT"] = "capture.colour",
    ["ALT + PRINT"] = "capture.record",
    ["SUPER + CTRL + PRINT"] = "capture.qr",

    -- Focus.
    ["SUPER + left"] = "focus.left",
    ["SUPER + right"] = "focus.right",
    ["SUPER + up"] = "focus.up",
    ["SUPER + down"] = "focus.down",

    -- Workspaces. Spelled out rather than generated: this file is meant to be read and
    -- copied from, and "SUPER + 3" has to be findable in it. 0 is the tenth.
    ["SUPER + 1"] = "workspace.1",
    ["SUPER + 2"] = "workspace.2",
    ["SUPER + 3"] = "workspace.3",
    ["SUPER + 4"] = "workspace.4",
    ["SUPER + 5"] = "workspace.5",
    ["SUPER + 6"] = "workspace.6",
    ["SUPER + 7"] = "workspace.7",
    ["SUPER + 8"] = "workspace.8",
    ["SUPER + 9"] = "workspace.9",
    ["SUPER + 0"] = "workspace.10",

    ["SUPER + SHIFT + 1"] = "workspace.move.1",
    ["SUPER + SHIFT + 2"] = "workspace.move.2",
    ["SUPER + SHIFT + 3"] = "workspace.move.3",
    ["SUPER + SHIFT + 4"] = "workspace.move.4",
    ["SUPER + SHIFT + 5"] = "workspace.move.5",
    ["SUPER + SHIFT + 6"] = "workspace.move.6",
    ["SUPER + SHIFT + 7"] = "workspace.move.7",
    ["SUPER + SHIFT + 8"] = "workspace.move.8",
    ["SUPER + SHIFT + 9"] = "workspace.move.9",
    ["SUPER + SHIFT + 0"] = "workspace.move.10",

    -- Prefix groups (#22). The chord opens the group and it waits for one key; a key
    -- that acts once closes it, Escape closes it, and so does 1.5 s of nothing.
    ["SUPER + v"] = {
      kind = "group",
      desc = "Volume",
      keys = {
        ["k"] = "volume.up",
        ["j"] = "volume.down",
        ["m"] = "volume.mute",
      },
    },

    -- The hardware-independent route to both backlights: a keyboard with no
    -- XF86MonBrightness keys still reaches them, and nothing here assumes an Alienware.
    -- This machine's own Fn+PgUp/PgDn chords live in ~/.config/symphony/keymap.lua.
    ["SUPER + b"] = {
      kind = "group",
      desc = "Brightness",
      keys = {
        ["k"] = "screen.brighter",
        ["j"] = "screen.dimmer",
        ["SHIFT + k"] = "keyboard.brighter",
        ["SHIFT + j"] = "keyboard.dimmer",
        ["0"] = "keyboard.off",
      },
    },

    ["SUPER + s"] = {
      kind = "group",
      desc = "Capture",
      keys = {
        ["s"] = "capture.screenshot",
        ["r"] = "capture.record",
        ["c"] = "capture.colour",
        ["q"] = "capture.qr",
      },
    },

    ["SUPER + o"] = {
      kind = "group",
      desc = "Menus",
      keys = {
        ["c"] = "menu.clipboard",
        ["n"] = "menu.network",
        ["w"] = "wallpaper.random",
      },
    },
  },
}
