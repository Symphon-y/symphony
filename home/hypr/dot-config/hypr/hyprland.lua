-- Target: ~/.config/hypr/hyprland.lua (linked by install/link-home)
--
-- Hyprland's own config, in Lua (Hyprland's native format since 0.55 -- hyprlang
-- .conf is the deprecated path now, not something this repo chose to move away from).
-- Split into small files by concern (D-0007), loaded with require().

require("monitors")
require("input")
require("looknfeel")
require("autostart")
require("bindings")
