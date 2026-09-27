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

# The brightness states the controller actually has. alienfx's 0x1C command takes
# Enable or Disable, so the hardware is dimmed or not; `off` is a dark colour, there
# being no third state. Brightness is deliberately not a percentage: scaling the RGB
# values is the only way to fake one, and with 16 levels per channel that loses the
# smallest lit channel first and shifts the hue as the lights dim.
# shellcheck disable=SC2034 # read by the callers that source this file
readonly LIGHTING_STATES=(off dim full)

lighting_state_file() {
  echo "${SYMPHONY_STATE:-$HOME/.local/state/symphony}/led-brightness"
}

# Prints one of LIGHTING_STATES. Anything unreadable reads as full: keys left dark with
# no obvious cause are worse than ignoring a corrupt file.
lighting_state() {
  local file raw=full
  file=$(lighting_state_file)
  [[ -r $file ]] && raw=$(<"$file")

  case $raw in
    off | dim | full) printf '%s' "$raw" ;;
    # The level was a percentage before the hardware dim was found; keep the intent of
    # a machine whose state file predates that.
    '' | *[!0-9]*) printf 'full' ;;
    *)
      if ((raw == 0)); then
        printf 'off'
      elif ((raw <= 50)); then
        printf 'dim'
      else
        printf 'full'
      fi
      ;;
  esac
}

lighting_set_state() {
  local file
  file=$(lighting_state_file)
  mkdir -p "$(dirname "$file")"
  printf '%s' "$1" >"$file"
}

# Asking for a repaint. Note that alienfx-theme uses only the state helpers above --
# it is what this function runs, so it must never call back into it.
lighting_repaint() {
  command -v alienfx-theme >/dev/null || return 0

  # No user session to ask (the installer's chroot, first-login, a TTY): paint here.
  systemctl --user --no-block restart alienfx-theme.service 2>/dev/null && return 0
  alienfx-theme || true
}
