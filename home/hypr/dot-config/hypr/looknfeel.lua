-- Target: ~/.config/hypr/looknfeel.lua
--
-- Static defaults for now: the full theme system (single palette source -> every
-- component, D-0025) is Phase 6. Phase 4 only wires matugen into mako/hyprlock/ghostty
-- to prove the pipeline works.

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
