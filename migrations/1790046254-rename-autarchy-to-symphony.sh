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

# Merge OLD into NEW (which sync-system and migrate may already have created,
# since they run before this), then remove OLD. cp -a keeps modes and owners.
merge_dir() {
  local old=$1 new=$2 as_root=${3:-}
  [[ -e $old ]] || return 0
  ${as_root:+sudo} cp -a "$old/." "$new/" 2>/dev/null || {
    ${as_root:+sudo} mkdir -p "$new"
    ${as_root:+sudo} cp -a "$old/." "$new/"
  }
  ${as_root:+sudo} rm -rf "$old"
}

moved=0
if [[ -e $SHARE/$OLD ]]; then
  sudo mv "$SHARE/$OLD" "$SHARE/$NEW"
  moved=1
fi
merge_dir "$ETC/$OLD" "$ETC/$NEW" root
merge_dir "$STATE/$OLD" "$STATE/$NEW"

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

# Every stow link in the home resolves into the payload. stow will not relink
# what it sees as another stow dir's links (the old path), so drop those first
# -- only links whose target is under the old root -- then apply from the new.
# Done whenever such links exist (not only when this run moved the root), so
# an interrupted run finishes on the next.
stale=0
while IFS= read -r -d '' link; do
  if [[ $(readlink "$link") == *"/share/$OLD/"* ]]; then
    rm -f "$link"
    stale=1
  fi
done < <(find "$HOME" -path "$HOME/.cache" -prune -o -type l -print0 2>/dev/null)
if ((moved || stale)); then
  (cd "$SHARE/$NEW/current" && install/link-home apply)
fi
exit 0
