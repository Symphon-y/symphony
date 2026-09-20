#!/usr/bin/env bash
# Phase 17 added @error to the Waybar stylesheet (for #network.disconnected and
# #battery), read from ~/.config/waybar/colors.css -- which matugen generates, and
# a machine themed before this had none. A stylesheet naming a colour that isn't
# defined fails to load and leaves the bar unstyled, so re-render the palette from
# the current wallpaper. Idempotent: a no-op once colors.css defines it, and on a
# machine that was never themed (first-login renders it fresh).
#
# --source-color-index 0 skips matugen's interactive source-colour prompt, same as
# wallpaper-set.
set -euo pipefail

colors="$HOME/.config/waybar/colors.css"
[[ -e $colors ]] || exit 0
grep -q '@define-color error' "$colors" && exit 0

matugen --config "$HOME/.config/matugen/config.toml" \
  image "$HOME/.local/share/backgrounds/current.png" --source-color-index 0
