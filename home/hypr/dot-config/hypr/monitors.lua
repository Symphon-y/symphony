-- Target: ~/.config/hypr/monitors.lua
--
-- `mode = "preferred"` / `scale = "auto"` don't work well on this VM's virtual
-- display: it reports no EDID physical size at all (`physical size (mm): 0x0`),
-- which led Hyprland to pick a 4:3 1024x768 mode at 2x scale -- badly zoomed in and
-- visibly wrong, found by actually looking at the running session. An explicit
-- resolution and scale (confirmed available via `hyprctl monitors`) is more correct
-- for a VM than trusting heuristics with no real physical size to reason from.
-- Revisit for real hardware (Phase 10), which will have actual EDID data.

hl.monitor({
  output = "",
  mode = "1920x1080@60",
  position = "auto",
  scale = 1,
})
