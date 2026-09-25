# wallpaper: where a wallpaper lives, and the shape of hyprpaper's config.
# Sourced by home/hyprpaper/dot-local/bin/wallpaper-{set,random}, install/link-home
# and install/first-login.
#
# Three concepts, three homes (D-0086): the user's library is theirs to fill, the
# pointer at what is showing is state, and the image a fresh install starts from is a
# payload asset. Phase 6 kept all three in ~/.local/share/backgrounds, which made
# wallpaper-random default at a directory no user ever puts pictures in.

# The user's library. Asked from XDG rather than hardcoded, so a relocated pictures
# directory takes its wallpapers with it. xdg-user-dir answers $HOME for a key it has
# no answer for -- a fresh account before xdg-user-dirs-update has run -- which would
# put the library straight in the home directory.
wallpaper_library() {
  local pictures=""
  command -v xdg-user-dir >/dev/null && pictures=$(xdg-user-dir PICTURES)
  [[ -z $pictures || $pictures == "$HOME" ]] && pictures="$HOME/Pictures"
  echo "$pictures/Wallpapers"
}

# What is showing. State, not data: rewritten on every change and meaningless on
# another machine. A symlink, so anything that wants the image just resolves it; no
# extension, because matugen reads the file's contents, not its name.
wallpaper_pointer() {
  echo "$HOME/.local/state/symphony/wallpaper"
}

# The image a fresh install starts from -- a stow link into the payload.
wallpaper_default() {
  echo "$HOME/.local/share/symphony/default-wallpaper.png"
}

# hyprpaper's whole config, naming $1. The one home of its shape: hyprpaper 0.8.4
# renders only what this file declares, resolving the path once at startup, so
# wallpaper-set rewrites it on every change and install/link-home seeds it for a home
# that has never had one (D-0085).
hyprpaper_config() {
  cat <<CONF
# Generated -- edit the wallpaper, not this file:
#   wallpaper-set <path>    wallpaper-random [dir]    SUPER+CTRL+W
wallpaper {
  monitor = *
  path = $1
  fit_mode = cover
}

ipc = on
splash = false
CONF
}
