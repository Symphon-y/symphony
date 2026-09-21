# Runbook: Update

The normal way to bring an already-installed machine up to the latest
release tag, once `base-install.md`/`install-base-system` and
`rebuild.md` have run at least once. Verified by `tests/acceptance/phase-10.bats`
and `tests/unit/update.bats`.

**What this is not:** the release ISO (`docs/runbooks/base-install.md`) only
ever bootstraps a machine once, from bare metal. Getting a later change (a
new package, a config tweak, a migration) onto a machine that's already
installed goes through this runbook instead -- `scripts/update` wraps the
same appliers `rebuild.md` already documents (`install/install-packages`,
`install/sync-system`, `install/link-home`, `install/enable-user-services`,
`scripts/migrate`) with an unconditional pre-update Btrfs snapshot, so a
config-only update is exactly as recoverable as a package update already is
via `snap-pac` (D-0011).

**Known gap (Phase 16 -> 18):** this runbook and `scripts/update` are git-based --
they need a checkout of this repo. A machine installed from the release ISO since
Phase 16 has none by design: its OS content is a root-owned payload at
`/usr/local/share/autarchy/current` with a `VERSION` file (D-0067). Updating such
a machine (fetch the latest release, verify, swap the payload, re-run the
appliers below) is Phase 18's scope; until then, reinstall from a newer ISO, or
on the dev seat deploy a checkout by hand (`dev-deploy.md`).

**Conventions**
- Runs **as your user** from `~/Projects/autarchy` (or wherever the repo is
  cloned). `scripts/update apply` calls `sudo` itself for the one step that
  needs it (`install/sync-system apply`) -- same as `rebuild.md` already
  does by hand.
- Like every script in this repo, Claude never runs this: only the user
  does, the same policy `scripts/migrate` already follows.

---

## 1. Check what's pending

```sh
scripts/update check
```

Reports whether a newer release tag exists and, if so, a summary of what
changed under `packages/` and `migrations/` between the currently-applied
tag and the latest one.

## 2. Apply

```sh
scripts/update apply
```

In order:

1. Refuses if the working tree has uncommitted changes, or if the repo is on
   a branch other than `main` (a fresh bootstrap clone sits on a detached
   `HEAD` at the release tag -- that's expected, and gets moved onto `main`
   automatically).
2. Takes an unconditional `snapper create` **before anything else runs** --
   this is the actual point of this script existing rather than just
   documenting the four commands.
3. Fast-forwards the repo to `main`.
4. Runs `install/install-packages`, `sudo install/sync-system apply`,
   `install/link-home apply`, `install/enable-user-services apply`, and
   `scripts/migrate apply`, in that order.
5. Records the new tag as current only once every step above succeeded.

## 3. If something goes wrong mid-update

The pre-update snapshot from step 2 is already there. Roll back the same way
any other bad change is rolled back (D-0008):

```sh
sudo snapper -c root list          # find the pre-update snapshot
sudo snapper -c root rollback <number>
```

or boot the `linux-lts`/fallback UKI from the systemd-boot menu if the
machine won't boot at all. `scripts/update` never marks a tag as current
until every applier has succeeded, so a machine that failed partway through
an update is never mistaken for one that's actually current.
