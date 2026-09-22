#!/usr/bin/env bash
# Moves an installed machine from the project's old name to its new one
# (D-0081, Phase 18): the payload root, /etc/<name>, the user's state dir and
# the four root-owned drop-ins, then a restow of the home from the payload's
# new path. Ships in the renamed payload and runs from it; scripts/rename
# leaves this file alone (# rename: keep), since it must know both names.
#
# Ordering matters, and the updater's is what makes this work: the old
# `autarchy-update apply` swaps the renamed payload in at the OLD path, then
# runs migrations from it -- this one moves the whole root to the new path and
# restows, and `scripts/migrate` (already running from the new payload,
# computing its state dir under the new name) then records this migration's
# marker in the moved state dir. The next command is `symphony-update`.
#
# Idempotent: a no-op once nothing under the old name exists. Refuses if both
# roots exist -- nothing is guessed about which one is live. Needs root for
# the system paths (sudo per step; the user runs migrations, never Claude).
# rename: keep
set -euo pipefail

readonly OLD=autarchy NEW=symphony
readonly ROOT="${MIGRATION_ROOT:-}" # tests point this at a fake /; empty on a real machine
readonly SHARE="$ROOT/usr/local/share"
readonly ETC="$ROOT/etc"
readonly STATE="$HOME/.local/state"
readonly DROPINS=(
  systemd/journald.conf.d
  mkinitcpio.conf.d
  systemd/resolved.conf.d
  ssh/sshd_config.d
)

if [[ -e $SHARE/$OLD && -e $SHARE/$NEW ]]; then
  echo "rename migration: both $SHARE/$OLD and $SHARE/$NEW exist -- resolve by hand" >&2
  exit 1
fi

moved=0
if [[ -e $SHARE/$OLD ]]; then
  sudo mv "$SHARE/$OLD" "$SHARE/$NEW"
  moved=1
fi
if [[ -e $ETC/$OLD && ! -e $ETC/$NEW ]]; then
  sudo mv "$ETC/$OLD" "$ETC/$NEW"
fi
if [[ -e $STATE/$OLD && ! -e $STATE/$NEW ]]; then
  mv "$STATE/$OLD" "$STATE/$NEW"
fi

# The renamed drop-ins are installed by sync-system; the old ones must not
# stay beside them, or both apply. mkinitcpio's is part of the initramfs build.
removed=0
for dir in "${DROPINS[@]}"; do
  if [[ -e $ETC/$dir/10-$OLD.conf ]]; then
    sudo rm -f "$ETC/$dir/10-$OLD.conf"
    removed=1
  fi
done
((removed)) && sudo mkinitcpio -P

# Every stow link in the home resolves into the payload; restow from its new path.
if ((moved)); then
  (cd "$SHARE/$NEW/current" && install/link-home apply)
fi
exit 0
