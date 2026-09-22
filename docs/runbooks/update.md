# Runbook: Update

How an installed machine moves to the latest release -- or, on the dev seat, to
the checkout being worked on. One command, `symphony-update`, in every install
since Phase 18 (D-0079). Verified by `tests/unit/symphony-update.bats` and
`tests/acceptance/phase-18.bats`.

**What this is:** an installed machine has no repo on it. Its OS content is the
root-owned payload at `/usr/local/share/symphony/current` (D-0067), and a release
is a new payload: `symphony-<tag>-payload.tar.zst` on the GitHub Release for that
tag, signed with minisign (D-0078). `symphony-update` downloads it, verifies the
signature against `/etc/symphony/release.pub`, takes a Btrfs snapshot, swaps the
payload in at the same path, and re-runs the same appliers the installer ran --
from the new payload. The release ISO (`base-install.md`) only ever bootstraps a
machine once; everything after that is this.

**Conventions**
- Runs **as your user**; it calls `sudo` itself for the steps that need root
  (the snapshot, the swap, `sync-system`, `enable-root-services`). Claude never
  runs it -- the same policy `scripts/migrate` follows.
- Nothing is applied automatically. The daily `update-notify` timer (D-0059)
  shows one toast when a newer release exists; you decide when.

---

## 1. See where you are and what a release would change

```sh
symphony-update version     # the installed release, e.g. 2026.09.22 (or local-<sha> on the dev seat)
symphony-update check       # the latest release, and a diff of packages/ and migrations/
```

`check` downloads and verifies the release before summarizing it, so a bad
signature shows up here too.

## 2. Apply

```sh
symphony-update apply
```

In order:

1. Refuses if a pacman transaction is running, if the machine runs a
   `local-*` build (the dev seat -- `--yes` overrides; see 4), or if the
   installed release is newer than the latest (`--yes` to downgrade).
2. Downloads the payload, its `.minisig` and `.sha256`; verifies the signature
   with `minisign -V -p /etc/symphony/release.pub`, then the checksum. A
   failure here stops before anything on the machine is touched.
3. `snapper -c root create -d "pre-update: <old> -> <new>"` (D-0062).
4. Unpacks beside the current payload, `chown -R root:root`, then two renames:
   `current` -> `previous`, staging -> `current`. The path never changes, so
   every stow link in your home keeps working.
5. From the new payload: `install/install-packages` (plus this machine's
   hardware packages, `scripts/hwpkglist`), `sudo install/sync-system apply`,
   `install/link-home apply`, `install/enable-user-services apply`,
   `sudo install/enable-root-services apply`, `scripts/migrate apply`.

The payload's own `VERSION` is what `symphony-update version` reports afterwards;
there is no separate marker to get out of sync.

## 3. Roll back

```sh
symphony-update rollback
```

Takes a snapshot, swaps `previous` back to `current`, and re-runs the appliers
from it. Migrations the newer release ran are **not** undone (they are one-way by
design, D-0051); if one of them is the problem, use the pre-update snapshot:

```sh
sudo snapper -c root list          # find "pre-update: ..."
sudo snapper -c root undochange <number>..0
```

or boot the `linux-lts`/fallback UKI from the systemd-boot menu if the machine
won't boot at all.

## 4. The dev seat: deploy a checkout

The machine you develop on is also a real install; the running system reads the
payload, never `~/Projects/Arch`. To try the checkout:

```sh
symphony-update apply --from ~/Projects/Arch
```

Same pipeline, no download or verification; the payload is versioned
`local-<short sha>` and uncommitted changes go too (it says so). `check` and
`update-notify` leave a `local-*` machine alone; `apply --yes` puts it back on a
release. After a deploy, `hyprctl reload` clears the config-error overlay
Hyprland shows while the links dangled during the swap.

## 5. Cutting a release

A tag on `main` shaped like a date -- `2026.09.22`, or `2026.09.22-test1` for a
pre-release that `check` will not offer -- makes `.github/workflows/release-iso.yml`
build and sign the payload, create the Release, then build and upload the ISO.
The signing key lives only in the repository secrets `MINISIGN_SECRET_KEY` and
`MINISIGN_PASSWORD`; the matching public key is `system/symphony/release.pub`,
which every install carries at `/etc/symphony/release.pub`. The workflow verifies
its own signature against that file, so a key mismatch fails the release, never
an update.

**Once per project** (the maintainer, or whoever forks this): `scripts/setup-signing`
generates the keypair under `~/.minisign/`, copies the public half
into `system/symphony/release.pub`, and stores the secret half and its password as
the two repository secrets through `gh`. Nothing on any installed machine needs
doing -- the installer ships the public key.
