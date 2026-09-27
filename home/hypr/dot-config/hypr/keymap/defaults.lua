-- Target: ~/.config/hypr/keymap/defaults.lua (linked by install/link-home)
--
-- The keymap this system ships with. Copy a line into ~/.config/symphony/keymap.lua
-- to change it; that file wins, per key. `false` unbinds, `true` keeps it as shipped. This file is a read-only
-- symlink into the payload and is replaced by every symphony-update, so it is always
-- the current reference -- `symphony-keys defaults` opens it.
--
-- Scopes:
--   always   live everywhere, including the lock screen. Hardware keys belong here.
--   global   ordinary chords, live in a normal session.
--
-- A value is the name of an entry in keymap/actions.lua.
--
-- Phase 21 note: today's SUPER chords still live in bindings.lua and move here in
-- issue #23. The media keys are here because they were the first thing the keymap
-- had to prove.

return {
  always = {
    ["XF86AudioRaiseVolume"] = "volume.up",
    ["XF86AudioLowerVolume"] = "volume.down",
    ["XF86AudioMute"] = "volume.mute",

    ["XF86MonBrightnessUp"] = "screen.brighter",
    ["XF86MonBrightnessDown"] = "screen.dimmer",

    -- The keyboard lighting (#26), on PageUp/PageDown -- the same two physical keys
    -- as the screen brightness above, without the Fn layer.
    --
    -- It was SUPER + XF86MonBrightnessUp/Down, which never fired: measured on the
    -- Alienware, the firmware's Fn layer does not emit those keysyms while SUPER is
    -- held, so nothing arrived at all -- not the keyboard light, not the screen.
    -- Prior/Next are the keysyms PageUp/PageDown send unmodified, they exist on every
    -- keyboard, and no Fn layer is involved.
    ["SUPER + Prior"] = "keyboard.brighter",
    ["SUPER + Next"] = "keyboard.dimmer",

    -- Not on this chassis, but standard elsewhere and harmless where they never fire.
    ["XF86AudioPlay"] = "player.play-pause",
    ["XF86AudioNext"] = "player.next",
    ["XF86AudioPrev"] = "player.previous",
  },
}
