-- Target: ~/.config/hypr/windows.lua
--
-- Smart gaps (no border/gap clutter with a single window on a workspace) and
-- picture-in-picture auto-float+pin -- common Hyprland-community patterns, not
-- copied from Omarchy. Field names checked against this system's own installed
-- Lua API stub (/usr/share/hypr/stubs/hl.meta.lua) where it documents them;
-- window_rule's action keys aren't fully enumerated there (only enabled/match/name
-- are statically typed -- the official example config uses additional dynamic
-- keys like no_focus the same way), so this mirrors the pre-Lua windowrulev2
-- keyword names. Confirmed against --verify-config; confirm the PIP rule actually
-- floats+pins a real picture-in-picture window during live-session testing.

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

hl.window_rule({
  name = "no-gaps-when-only-window-tiled",
  match = { float = false, workspace = "w[tv1]" },
  border_size = 0,
  rounding = 0,
})

hl.window_rule({
  name = "no-gaps-when-only-window-single-ws",
  match = { float = false, workspace = "f[1]" },
  border_size = 0,
  rounding = 0,
})

hl.window_rule({
  name = "picture-in-picture",
  match = { title = "^(Picture-in-Picture)$" },
  float = true,
  pin = true,
})
