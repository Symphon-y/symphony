-- Target: ~/.config/hypr/hyprland.lua (linked by install/link-home)
--
-- Hyprland's own config, in Lua (Hyprland's native format since 0.55 -- hyprlang
-- .conf is the deprecated path now, not something this repo chose to move away from).
-- Split into small files by concern (D-0007), loaded with require().
--
-- bindings.lua holds the chords this repo fixes; keymap.lua builds the configurable
-- ones from keymap/defaults.lua merged with ~/.config/symphony/keymap.lua (Phase 21).
-- Everything moves into the keymap in issue #23.

require("monitors")
require("input")
require("looknfeel")
require("autostart")
require("bindings")
require("keymap")
require("windows")
