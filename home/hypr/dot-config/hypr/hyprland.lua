-- Target: ~/.config/hypr/hyprland.lua (linked by install/link-home)
--
-- Hyprland's own config, in Lua (Hyprland's native format since 0.55 -- hyprlang
-- .conf is the deprecated path now, not something this repo chose to move away from).
-- Split into small files by concern (D-0007), loaded with require().
--
-- keymap.lua owns every binding (#23): keymap/defaults.lua merged with the user's own
-- ~/.config/symphony/keymap.lua, per key. There is no second place a chord can come
-- from -- bindings.lua held the hardcoded ones and is gone.

require("monitors")
require("input")
require("looknfeel")
require("autostart")
require("keymap")
require("windows")
