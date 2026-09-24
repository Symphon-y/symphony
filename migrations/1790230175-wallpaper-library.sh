#!/usr/bin/env bash
# Wallpapers move out of ~/.local/share/backgrounds (D-0086): the library becomes
# ~/Pictures/Wallpapers, where a person actually keeps pictures, and the pointer at
# what is showing becomes ~/.local/state/symphony/wallpaper, beside the rest of
# symphony's state. The old directory mixed both with a shipped asset, so
# wallpaper-random defaulted at a folder nobody fills.
#
# Runs after install/link-home has restowed, which has already removed the old
# default.png link from the payload. Idempotent: the old pointer is the marker, and
# once it is gone there is nothing left to do.
#
# Paths are literal here on purpose -- a migration records what was true when it ran,
# and must not change meaning when scripts/lib/wallpaper.bash does.
set -euo pipefail

old="$HOME/.local/share/backgrounds"
default="$HOME/.local/share/symphony/default-wallpaper.png"
library="$(xdg-user-dir PICTURES 2>/dev/null || true)"
[[ -z $library || $library == "$HOME" ]] && library="$HOME/Pictures"
library="$library/Wallpapers"

[[ -L $old/current.png ]] || exit 0

# The user's own images, kept whole: a name already taken in the library wins, because
# the file there is the one they can see.
mkdir -p "$library"
while IFS= read -r image; do
  name=$(basename "$image")
  if [[ -e $library/$name ]]; then
    echo "wallpaper-library: $library/$name already exists, leaving $image in place"
  else
    mv "$image" "$library/$name"
  fi
done < <(find "$old" -maxdepth 1 -type f \
  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \))

# Whatever was showing, carried over by the one script that knows how to set a
# wallpaper -- it writes the new pointer, rewrites hyprpaper's config (which may still
# name a path under the old directory) and re-renders the palette. A target that no
# longer resolves, an unmounted share say, would leave the machine with no wallpaper
# at all, so fall back to the shipped default.
target=$(realpath "$old/current.png" 2>/dev/null || true)
if [[ -z $target || ! -f $target ]]; then
  echo "wallpaper-library: the wallpaper that was showing is gone; using the shipped default"
  target=$default
fi
rm -f "$old/current.png"
"$HOME/.local/bin/wallpaper-set" "$target"

# The stale payload link the restow left behind, then the directory itself. Anything
# else in there is the user's and stays -- said out loud, since the directory is
# supposed to be gone after this.
[[ -L $old/default.png ]] && rm -f "$old/default.png"
if ! rmdir "$old" 2>/dev/null; then
  echo "wallpaper-library: $old still holds files that are not wallpapers; left in place"
fi
