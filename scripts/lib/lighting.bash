# lighting: asking for a repaint of the themed hardware.
# Sourced by home/hyprpaper/dot-local/bin/wallpaper-set and
# home/hardware/dot-local/bin/keyboard-backlight.
#
# Why a caller must never run the painter itself: it writes to a USB device, and two at
# once wedge the controller. `alienfx --theme` that cannot claim it spins in
# _wait_controller_ready having already issued a reset, so the keys flash and no colour
# lands. A repeating key ran one painter per press and 25 of them accumulated.
#
# So the unit owns the painter and a caller only asks. `restart` makes systemd kill the
# previous instance's whole cgroup first, which makes a pile-up impossible rather than
# merely unlikely; `--no-block` returns at once, so an OSD never waits on a USB write and
# rapid presses coalesce -- each queued restart replaces the running painter, and the
# last one reads the level that is current by then.

lighting_repaint() {
  command -v alienfx-theme >/dev/null || return 0

  # No user session to ask (the installer's chroot, first-login, a TTY): paint here.
  systemctl --user --no-block restart alienfx-theme.service 2>/dev/null && return 0
  alienfx-theme || true
}
