#!/usr/bin/env bash
# Phase 6 shipped ~/.config/wireplumber/wireplumber.conf.d/51-alsa-soft-mixer.conf
# (api.alsa.soft-mixer = true) for every machine -- an ASUS ROG quirk generalised by
# mistake. With it, PipeWire never touches the hardware mixer, and on the Alienware
# 14's Realtek codec the output pins stayed muted: no sound at all (D-0083). The
# rule is gone from the payload, so link-home's restow drops the link; what an
# already-themed machine still has is WirePlumber's remembered routes, which keep
# the hardware mixer untouched until they are cleared and WirePlumber re-reads the
# card. Idempotent: nothing to remove is nothing to do.
set -euo pipefail

rule="$HOME/.config/wireplumber/wireplumber.conf.d/51-alsa-soft-mixer.conf"
routes="$HOME/.local/state/wireplumber/default-routes"

changed=0
if [[ -e $rule || -L $rule ]]; then
  rm -f "$rule"
  changed=1
fi
if [[ -e $routes ]]; then
  rm -f "$routes"
  changed=1
fi
# try-restart: only if it is running (a TTY login has no WirePlumber to restart).
((changed)) && systemctl --user try-restart wireplumber.service
exit 0
