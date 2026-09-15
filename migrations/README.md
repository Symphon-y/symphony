# migrations/

One-time changes to an already-configured system, run exactly once by
`scripts/migrate`. Modeled on Omarchy's own `migrations/<timestamp>.sh` +
completion-marker pattern (`docs/omarchy-influences.md`, "Update and migration
mechanism") — its channel/mirror/pacman-guard infrastructure is not part of this.

This is **not** where ordinary config changes go — those are just edits to
`home/`/`system/` files, applied the normal way (`install/link-home apply`,
`install/sync-system apply`). A migration is for the rarer case: a change that
needs to *run a command once* against a system that's already in some earlier
state (installing a package the old way left behind, renaming something,
fixing up state a previous phase's manual step got wrong) — not something a
declarative file sync can express.

## Convention

- One file per change: `migrations/<unix-timestamp>-<slug>.sh`, executable,
  `set -euo pipefail`.
- **Idempotent and safe to interrupt.** `scripts/migrate` only marks a migration
  complete after it exits `0`; a script that's already applied its change must
  detect that and no-op, not fail or double-apply.
- If a migration needs root, it calls `sudo` itself (matching every other
  privileged step in this project) — the user runs `scripts/migrate apply`,
  never Claude.
- Never renumber or edit a migration once it's shipped and could have already
  run somewhere; add a new one instead, the same way a database migration
  framework would.

## Running

    scripts/migrate check   # list what's pending, run nothing
    scripts/migrate apply   # run every pending migration in order

Completion markers live under `~/.local/state/autarchy/migrations/` (override
with `$AUTARCHY_STATE`), one empty file per completed migration's filename.
