# Runbook: Rebuild (post-first-boot)

> **Since Phase 16 (D-0067) a machine installed from the release ISO has no
> checkout and needs none of the linking below:** the installer copies the OS
> content to `/usr/local/share/symphony/current`, links the home from it and
> runs `install/first-login` on the first desktop start. This runbook is for a
> *development* machine that also carries the repo, and for the steps the
> installer does not do (identity, auth, the personal Neovim config).

Picks up exactly where `base-install.md` leaves off — a freshly booted system with
the base install done (`install/configure-base-system` already run), logged in as
the regular user. Everything from here on is what Phases 2–7 each did by hand, one
tracking doc at a time; this consolidates it into one repeatable sequence. Verified
by `tests/acceptance/phase-08.bats`.

Used for two things: rebuilding for real after a from-scratch reinstall
(`base-install.md`, then this), and — the way Phase 8 itself validated this
runbook, since a real from-scratch test wasn't warranted yet — re-running the whole
sequence against an **already-configured** machine and confirming every step is a
safe no-op.

**Conventions**
- Runs **as your user** (`travis`) from `~/Projects/symphony`, in a terminal, unless
  a step says otherwise. Steps needing `sudo` are called out explicitly — run those
  yourself; Claude never does.
- Every script here is idempotent: re-running the whole sequence on a
  fully-configured machine should change nothing and report success throughout.

---

## 1. Clone the repo (skip if already present)

```sh
gh repo clone Symphon-y/symphony ~/Projects/symphony
cd ~/Projects/symphony
```

## 2. Bootstrap yay (skip if `yay --version` already works)

AUR packages (below) need it first. Needs `sudo` for the final install step — see
`packages/external.md`'s `yay` row for the exact commands and why this can't be
scripted further (an AUR helper can't come from a repo pacman already trusts).

## 3. Install every declared package

```sh
install/install-packages
```

## 4. Apply system config, home config, user services

```sh
sudo install/sync-system apply
install/link-home apply
install/enable-user-services apply
```

## 5. Run pending migrations

```sh
scripts/migrate check   # see what's pending first
scripts/migrate apply   # needs sudo for any migration that itself needs it
```

## 6. External, non-packaged config

Not part of this repo at all (`packages/external.md` has the full list and why):

```sh
git clone https://github.com/Symphon-y/config.nvim.git ~/.config/nvim
```

## 7. Identity and authentication (manual, interactive — can't be scripted)

- `~/.gitconfig.local` — recreate with the real `[user]` block (D-0048). Not in
  git, by design (D-0022: no personal identifiers in this repo, even privately).
- `gh auth login` (device/web flow), then `gh auth setup-git`.
- `install/claude-code install`, then run `claude` once and complete its own login.

## 8. Verify

```sh
scripts/check
bats tests/acceptance
scripts/pkg-audit               # zero drift
scripts/migrate check           # nothing pending
install/enable-user-services check
install/link-home check
```

---

## Out-of-repo state: what a rebuild can't get from git alone

| State | Lives | Restored by |
|---|---|---|
| Git identity (`user.name`/`user.email`) | `~/.gitconfig.local` | Recreate by hand — step 7 |
| Neovim config | `github.com/Symphon-y/config.nvim`, a separate repo | `git clone` — step 6 |
| `gh` OAuth token | `~/.config/gh/hosts.yml` | `gh auth login` — step 7 |
| Claude Code's own credentials | `~/.claude/.credentials.json` | Claude Code's own login — step 7 |
| LUKS header | Backed up to the Unraid host (not the VM, not this repo) | `cryptsetup luksHeaderRestore` from that backup — see D-0052 for how/when it was taken |
| SSH jump-host private key | Unraid's flash only (`/root/.ssh/symphony-vm`), never the VM (D-0021) | Not a VM rebuild concern at all — it never lived here |

Nothing above is scriptable end-to-end: identity, auth, and the LUKS passphrase all
need a human. That's the point — none of it belongs in git either way.
