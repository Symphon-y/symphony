#!/usr/bin/env bash
# Every chord lives in the keymap now (#23), so home/hypr/.../bindings.lua is gone from
# the payload. A machine installed earlier has ~/.config/hypr/bindings.lua as a stow link
# into it, and stow cannot clear that: `--restow` unlinks what is *in* the package, so a
# file deleted from the payload leaves its symlink behind, pointing at nothing.
#
# Only the dangling link is removed. A real file there is somebody's own config -- left
# alone, and said out loud, because hyprland.lua no longer requires it and they would
# otherwise wonder why it stopped taking effect.
set -euo pipefail

bindings="$HOME/.config/hypr/bindings.lua"

if [[ -L $bindings && ! -e $bindings ]]; then
  rm -f "$bindings"
  echo "removed the stale ~/.config/hypr/bindings.lua link; bindings are in keymap/defaults.lua now"
  exit 0
fi

if [[ -f $bindings && ! -L $bindings ]]; then
  echo "note: $bindings is a real file and has been left alone -- nothing loads it any more." >&2
  echo "      Its bindings belong in ~/.config/symphony/keymap.lua now (see keymap/defaults.lua)." >&2
fi
