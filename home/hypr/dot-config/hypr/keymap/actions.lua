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
--   repeating  holding the key repeats the action (volume, yes; mute, no)
--   exits      leaves a prefix group after acting (Phase 21 Task D)
--
-- Pure: no `hl`.

return {
  ["volume.up"] = { desc = "Volume up", kind = "exec", cmd = "volume up", repeating = true },
  ["volume.down"] = { desc = "Volume down", kind = "exec", cmd = "volume down", repeating = true },
  ["volume.mute"] = { desc = "Mute", kind = "exec", cmd = "volume mute", exits = true },

  ["screen.brighter"] = { desc = "Brightness up", kind = "exec", cmd = "brightness up", repeating = true },
  ["screen.dimmer"] = { desc = "Brightness down", kind = "exec", cmd = "brightness down", repeating = true },

  ["keyboard.brighter"] = { desc = "Keyboard light up", kind = "exec", cmd = "keyboard-backlight up", repeating = true },
  ["keyboard.dimmer"] = { desc = "Keyboard light down", kind = "exec", cmd = "keyboard-backlight down", repeating = true },
  ["keyboard.off"] = { desc = "Keyboard light off", kind = "exec", cmd = "keyboard-backlight off", exits = true },

  ["player.play-pause"] = { desc = "Play/pause", kind = "exec", cmd = "player play-pause" },
  ["player.next"] = { desc = "Next track", kind = "exec", cmd = "player next" },
  ["player.previous"] = { desc = "Previous track", kind = "exec", cmd = "player previous" },
}
