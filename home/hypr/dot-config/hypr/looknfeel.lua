-- Target: ~/.config/hypr/looknfeel.lua
--
-- Phase 6 adds the env vars that make GTK/Qt/cursor theming actually consistent:
-- XCURSOR_THEME/XCURSOR_SIZE (Bibata, verified against the real release asset list --
-- no native hyprcursor port for this package, so HYPRCURSOR_THEME is left unset and
-- Hyprland falls back to XCursor) and QT_QPA_PLATFORMTHEME=gtk3 (Qt apps read the GTK3
-- theme -- home/gtk/, Phase 3's already-adopted mechanism). Syntax confirmed against
-- Hyprland's own example config (hl.env("VAR", "VALUE")).

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    layout = "dwindle",
  },

  decoration = {
    rounding = 6,
    active_opacity = 1.0,
    inactive_opacity = 0.95,
  },

  animations = {
    enabled = true,
  },
})
