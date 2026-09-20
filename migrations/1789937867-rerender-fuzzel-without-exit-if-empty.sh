#!/usr/bin/env bash
# fuzzel.ini used to set [dmenu] exit-immediately-if-empty, which closes the Wi-Fi
# password prompt of networkmanager-dmenu at once (D-0075). The file is rendered by
# matugen, so a machine themed before the template changed still has the setting:
# re-render from the current wallpaper. Idempotent: a no-op once the setting is gone,
# and on a machine that was never themed (first-login renders it fresh).
#
# --source-color-index 0 skips matugen's interactive source-colour prompt, same as
# wallpaper-set.
set -euo pipefail

fuzzel_ini="$HOME/.config/fuzzel/fuzzel.ini"
[[ -e $fuzzel_ini ]] || exit 0
grep -q '^[[:space:]]*exit-immediately-if-empty' "$fuzzel_ini" || exit 0

matugen --config "$HOME/.config/matugen/config.toml" \
  image "$HOME/.local/share/backgrounds/current.png" --source-color-index 0
