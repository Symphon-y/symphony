#!/usr/bin/env bash
# ~/.bashrc is the user's own file now (D-0095, #31). It was a stow link into the
# root-owned payload, so editing it needed sudo -- and a sudo edit lives inside the
# payload, which the next `symphony-update apply` replaces wholesale. That happened, and
# the edit was lost with no error. symphony's shell configuration moved to
# ~/.config/bash/symphony.bash, which is the link and every deploy replaces; ~/.bashrc is
# seeded once, sources it, and is never written again.
#
# Runs after install/link-home has restowed, so ~/.config/bash/symphony.bash is already
# in place and seed_shell has already declined to touch the old link. That link is what
# stow cannot tidy: `--restow` unlinks what is *in* the package, so a file deleted from
# the payload leaves its symlink behind, pointing at nothing. Its existence is this
# migration's "not yet done" marker, so a real file -- the user's, or a previous run's
# output -- needs no extra state to be left alone.
#
# The seeded text is spelled out here rather than read from the payload's
# install/seed/bashrc on purpose: a migration records what was true when it ran, and must
# not change meaning when that template does. A machine that skips several releases would
# otherwise run this against a template nobody tested it against.
set -euo pipefail

bashrc="$HOME/.bashrc"
symphony="$HOME/.config/bash/symphony.bash"

if [[ -L $bashrc ]]; then
  # Nothing of the user's is discarded: the link's target was symphony's own file. rm
  # first -- writing through the link would try to create a file inside the payload.
  # Replaced whether or not it still resolves: on a machine whose deploy ordering was
  # unusual the target is symphony's former dot-bashrc in either payload, and the point
  # of D-0095 is that this path stops being a link at all.
  rm -f "$bashrc"
  cat >"$bashrc" <<'BASHRC'
# ~/.bashrc -- yours. symphony seeds this file once, on install, and never touches it
# again: edit it freely, it survives every update.
# shellcheck shell=bash
#
# symphony's own shell configuration is the file sourced below -- a symlink into the
# payload, replaced by every deploy. Change symphony's behaviour there, in the repo;
# change yours here. Anything you add after the source line wins, because it runs last.

[[ $- != *i* ]] && return

# Guarded so that a rolled-back machine, where the payload has no such file, comes up
# quietly instead of printing an error in every new shell.
# shellcheck source=/dev/null # a link into the payload; not present at lint time
[[ -r ~/.config/bash/symphony.bash ]] && source ~/.config/bash/symphony.bash

# Your own aliases, functions and exports below.
BASHRC
  echo "$bashrc is yours now: a real file, editable without sudo, kept by every update."
  echo "  symphony's own shell config is $symphony, sourced from it."
  exit 0
fi

# A real file that already sources symphony's config is either a fresh install, where
# install/link-home seeded it, or this migration on a second run: nothing to say. One that
# does not is the user's own .bashrc, from before this change or written since -- left
# alone, and said out loud, because that shell will otherwise come up with no prompt, no
# mise, no zoxide and no aliases, and nobody would connect the two.
if [[ -f $bashrc ]] && ! grep -q '\.config/bash/symphony\.bash' "$bashrc"; then
  echo "note: $bashrc is your own file and has been left alone." >&2
  echo "      symphony's shell config lives in $symphony now. Add" >&2
  echo "        [[ -r ~/.config/bash/symphony.bash ]] && source ~/.config/bash/symphony.bash" >&2
  echo "      to pick it up again (the prompt, mise, zoxide, fzf, the aliases)." >&2
fi

# Nothing there at all: creating it is install/link-home's seeding, which has already run
# by the time migrations do. Deliberately not duplicated here.
