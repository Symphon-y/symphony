#!/usr/bin/env bash
# Removes ~/.local/state/autarchy/current-release, the per-user marker the
# git-based scripts/update kept and the installer seeded (Phase 10/12). Since
# Phase 18 the installed release is the payload's own VERSION file
# (/usr/local/share/autarchy/current/VERSION, D-0079), so the marker is stale
# state that would only ever disagree. Idempotent: a no-op once gone.
set -euo pipefail

rm -f "$HOME/.local/state/autarchy/current-release"
