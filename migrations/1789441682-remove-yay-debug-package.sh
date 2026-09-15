#!/usr/bin/env bash
# Removes yay-debug: an unintended side effect of building yay from source
# (makepkg splits detached debug symbols into their own package during the
# manual bootstrap, packages/external.md), never a deliberate choice and never
# declared anywhere -- found by scripts/pkg-audit during Phase 8. Idempotent:
# a no-op if it's already gone.
#
# Needs root (pacman -R): run by the user, same as every other privileged step
# in this project -- never by Claude.
set -euo pipefail

if pacman -Qi yay-debug &>/dev/null; then
  sudo pacman -Rns --noconfirm yay-debug
fi
