-- Target: ~/.config/hypr/autostart.lua
--
-- Each process launched through `uwsm app --`, so it gets its own systemd scope
-- under the session (uwsm's whole point), instead of living in the compositor's
-- own cgroup.

hl.on("hyprland.start", function()
  hl.exec_cmd("uwsm app -- mako")
  hl.exec_cmd("uwsm app -- hypridle")
  hl.exec_cmd("uwsm app -- hyprpaper")
  hl.exec_cmd("uwsm app -- hyprpolkitagent")
end)
