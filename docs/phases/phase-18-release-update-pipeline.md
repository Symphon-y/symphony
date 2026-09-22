# Phase 18 — Release payload and update pipeline

| | |
|---|---|
| **Status** | Complete (2026-09-22) |
| **Driver** | Claude + user |
| **Branch** | `phase/18-release-update-pipeline` |
| **Started** | 2026-09-21 |
| **Completed** | 2026-09-22 |

## Goal

An installed machine -- no repo on it, only the root-owned payload at
`/usr/local/share/symphony/current` (D-0067) -- can check for and apply the latest
release on demand: a signed, versioned payload from a GitHub Release, a pre-update
snapshot, a rollback. The same command deploys a checkout on the dev seat. The repo
becomes public so the release assets are plainly downloadable.

## Scope

**In scope**
- A release tag produces, in CI, `symphony-<tag>-payload.tar.zst` (the six payload
  directories plus `VERSION`), its minisign signature and its sha256, on the same
  GitHub Release the ISO goes to; tags with a suffix are pre-releases.
- `symphony-update check|apply|rollback|version` in a new `home/update/` stow package:
  download, verify (minisign against a public key shipped in `/etc/symphony/`),
  snapshot, stage, swap `current`/`previous` at the same path, re-run the appliers
  and migrations from the new payload. `apply --from DIR` stages a checkout instead.
- `update-notify` moves into `home/update/` and also checks `releases/latest` daily.
- The git-based `scripts/update`, its tests and `docs/runbooks/dev-deploy.md` retired;
  `docs/runbooks/update.md` rewritten. The installer no longer seeds
  `~/.local/state/symphony/current-release`; the payload's `VERSION` is the one source.
- Going public: `LICENSE` (MIT), pre-publication audit, author-email rewrite of history
  to the noreply address (user runs `git filter-repo`), visibility flipped by the user.
- Decisions D-0078 to D-0080; D-0059 and D-0062 amended.

**Out of scope**
- A pacman package or repo for the payload (REJECTed: D-0050, D-0061, D-0051).
- Automatic updates: the notifier informs, the user applies (D-0059).
- Applying kernel-parameter quirks (`system/quirks.txt`) to an installed machine -- a
  change ships as a migration.
- Updating the live ISO in place, or updating a machine that was never installed from
  a payload (the old checkout-only VM shape no longer exists).

## Decisions

**Resolved** (user-confirmed 2026-09-21)
- Signing: **minisign**. Secret key in a GitHub Actions secret, public key committed
  at `system/symphony/release.pub` and installed to `/etc/symphony/release.pub`.
  Verification is offline, one small standard tool. (Alternatives: GitHub artifact
  attestation -- needs `gh`, Sigstore and network at verify time, trusts GitHub's
  identity; sha256 only -- integrity, not authenticity.)
- One updater, `--from DIR` for the dev seat; `scripts/update` retired. Two update
  paths for a machine shape that no longer exists was the alternative.
- The daily `update-notify` timer also checks for a new release (one GET a day, the
  same class of fetch `checkupdates` already does; nothing is sent but the request).
- The repo goes public in this phase. History is rewritten so the 37 commits
  authored with a personal address use the noreply one (tree and diffs audited
  clean). The ten pre-Phase-18 releases and tags are deleted first: they are ISOs of
  a state that cannot update and no one should install them.
- Pre-releases by tag suffix (`2026.09.22-test1`); the updater takes
  `releases/latest`, which GitHub defines as the newest non-prerelease.

**Where each piece of knowledge lives (DRY)**

| Knowledge | Single home |
|---|---|
| What a payload contains | `PAYLOAD_CONTENT` in `install/configure-base-system`, read by `scripts/build-payload` |
| The installed release | `/usr/local/share/symphony/current/VERSION` |
| Where releases live | `SYMPHONY_RELEASE_REPO` in `symphony-update` (overridable for tests), used by `update-notify` too |
| The public key | `system/symphony/release.pub` -> `/etc/symphony/release.pub` (`system/files.txt`) |
| The applier order | `symphony-update apply`, the same order `rebuild.md` documented |

## Acceptance tests (written before implementation)

Files: `tests/unit/build-payload.bats`, `tests/unit/symphony-update.bats`,
`tests/unit/update-notify.bats` (extended), `tests/unit/install-base-system.bats`
(marker seeding gone), `tests/acceptance/phase-18.bats`, `tests/acceptance/phase-10.bats`
(updated).

| Test | What it proves |
|---|---|
| `build-payload`: only the six dirs + `VERSION` from a ref; `.git`/`tests`/`gui`/`iso`/`docs` absent; unknown ref fails | Only committed OS content ships, nothing else can leak in |
| `symphony-update check`: newer / equal / older; summary of `packages/` and `migrations/` changes | The user knows what an update brings |
| `apply` refuses: `local-*` payload without `--yes`; pacman lock; bad signature or checksum (nothing touched, temp dir gone) | A bad or unwanted payload never reaches the disk |
| `apply` order: verify, snapshot, stage, swap, appliers *from `current`*, migrate; `previous/` kept; `VERSION` from the payload | Recoverable at every step; the new code runs, not the download dir |
| `rollback`: `previous` back to `current`, appliers re-run, migrations not undone (said so) | One command back |
| `--from DIR`: no download, no verification, version `local-<sha>`, dirty tree warned | The dev seat's deploy is the same pipeline |
| `update-notify`: new tag -> one toast; same tag twice -> one; API failure -> silent exit 0; equal or older -> nothing | Informs once, never nags, never blocks on the network |
| installer: no `current-release` marker seeded; `files.txt` installs the key 0644 | One source of truth for the release; verification works on a fresh install |
| acceptance: workflow `payload` job before the ISO job, minisign, prerelease on suffixed tags; `release.pub` is a minisign key; `scripts/update` gone; `LICENSE`; runbook documents the subcommands; decisions present | The pipeline and its record hold together |

Red confirmed: 2026-09-21 · Green confirmed: |

## Tasks

- [x] Branch, tracking doc, roadmap row
- [x] Red: the tests above (2026-09-21: 50 failing, 12 acceptance + 38 unit)
- [x] `scripts/build-payload`; public key + `files.txt`; `minisign` in the inventory; `scripts/setup-signing`
- [x] `home/update/`: `symphony-update`, `update-notify` moved in
- [x] Installer: `seed_release_marker` removed; migration for the old marker
- [x] Workflow: `payload` job (build, sign, release, upload); ISO job after it -- `2026.09.22-test1` signed and verified
- [x] Retire `scripts/update`, `update.bats`, `dev-deploy.md`; rewrite `update.md`; README
- [x] Green: `scripts/check` (323); on the Alienware: `apply --from` (three times, the
      last through the renamed layout), the test tag `2026.09.22-test1` signed and
      verified against the shipped key
- [x] Rename autarchy -> symphony: `scripts/rename`, the migration, D-0081; the dev seat
      migrated (one interrupted run, fixed and finished)
- [x] Public: LICENSE; old releases/tags deleted; history rewritten to the noreply
      address (206 commits; `~/.gitconfig.local` switched too, after five new commits
      briefly reintroduced the personal one and were re-authored); `gh repo rename`,
      force-push, visibility public; verified unauthenticated
- [x] Close: D-0078 to D-0081, influences, roadmap, merge
- [ ] **After the merge, on `main`:** tag `2026.09.22`; on the Alienware
      `symphony-update apply --yes` (replaces `local-*`), `rollback`, `apply` -- the
      full-release proof, which needs the tag to be on `main` (recorded in the log)

## Implementation log

### 2026-09-21
- Plan mode. Read `scripts/update` (git-based: fetch tags, `git pull`, appliers from a
  checkout), the release workflow, the appliers, and Omarchy's update line
  (`omarchy-update`, `-available`, `-migrate`, `-version*`: a pacman package from its own
  repo with `stable`/`rc`/`edge` channels, a snapshot, `pacman -Syu`, timestamped
  migrations with per-user markers, a daily "update available" status). The migration
  shape was already ADAPTed (D-0051); the package/mirror/channel machinery stays
  REJECTed (D-0050, D-0061), so the payload is a signed tarball on a Release.
- Pre-publication audit of the repo: tree clean (`check-identifiers`), history diffs
  clean of emails, keys and tokens; 37 of 193 commits carry a personal author address
  -> rewrite (user decision).

### 2026-09-21 (implementation, on the Alienware)
- **Red:** 50 failing tests across `build-payload`, `symphony-update`, `update-notify`,
  the installer and `phase-18.bats`. **Green** the same day; `scripts/check` 294 unit tests.
- `scripts/build-payload` reads the allow-list from `install/configure-base-system` at the
  ref being packed (one home), archives with `git archive` so nothing uncommitted ships,
  creates any of the six directories git has no file for (git tracks no empty directory),
  and pins mtime/owner/order so the same commit packs to the same bytes.
- `symphony-update`: the sudo stub in the tests runs the real command except `chown`
  (a non-root test can't); the appliers are stubs that log which payload they ran from,
  which is the assertion that matters ("from the new payload, not the download").
- User asked whether the signing step would be automated "for any machine that installs
  symphony": it already is on the verifying side (the installer ships the public key,
  `minisign` is in `base.txt`); creating the *secret* key is per project and stays with
  the maintainer -- scripted as `scripts/setup-signing` (5 tests), never in CI. The user
  ran it by hand; the public key `03B7F2FA9C6C3304` is committed.
- **First self-deploy:** the old manual deploy put the new payload on the machine once;
  then `symphony-update apply --from ~/Projects/Arch` deployed the same checkout through
  its own pipeline -- snapshot, swap, 49 links restowed from the new payload, services
  up, `current`/`previous` root-owned. Two findings: `version` printed no trailing newline
  (`tr -d '[:space:]'`), and the old per-user `current-release` marker was orphaned -- a
  migration removes it (3 tests). Both confirmed fixed by the second `apply --from`.
- **First CI-signed release, `2026.09.22-test1` (pre-release):** the payload job passed
  first time. On the machine: `minisign -V -p /etc/symphony/release.pub` verifies CI's
  signature; the sha256 matches; a single flipped byte fails verification; the tarball
  is **byte-identical** to a local `build-payload` of the same commit. `symphony-update
  check` then hit a real state the plan missed: with only pre-releases, GitHub's
  `releases/latest` is a 404, which read as "could not fetch". Red (2 tests) then green:
  a 404 is "no release published yet", plainly, for `check` and `apply` both.

### 2026-09-21 (the rename)
- With history rewritten locally and nothing force-pushed yet, the user asked how hard a
  rename is and whether the name should become a variable. Measured (~490 code, ~240 docs,
  13 paths, 28 `AUTARCHY_*` vars, plus archiso/systemd/stow/asset names no variable can
  reach); recommended and agreed: no runtime indirection, one re-runnable script.
  **D-0081.** Name chosen: `symphony`.
- Red: `tests/unit/rename.bats` (12) and `tests/unit/migration-rename.bats` (7). The
  script's first real run refused itself: the migration test contained both names, which
  the "NEW already in use" guard caught -- so a `# rename: keep` marker opts a file out
  (content *and* path; the first version only covered content and moved the migration
  to `rename-symphony-to-symphony.sh`, caught by its own test glob). `\b` was wrong for
  the token (sed counts `_` as a word character), so the boundary is an explicit class.
- `scripts/rename autarchy symphony`: 103 files, 13 paths, `scripts/check` green (323).
  The old token survives only in the migration, its test and `scripts/rename`'s example.
- Not covered by the script, by design: the gitignored `packages/local/alien.txt` (moved
  by hand on the dev seat), the GitHub slug (`gh repo rename`), and the installed
  machine (the migration, run by the old `autarchy-update apply --from` one last time).

### 2026-09-22 (public, and the order of the last proof)
- `symphony-update apply --from` deployed `local-300af86` through the renamed layout:
  snapshot, swap, 49 links, seven user units and three root timers enabled, the rename
  migration marked. Then `gh repo rename symphony`, `git push --force --all`, visibility
  public -- verified from outside (200 unauthenticated; the old slug redirects; GitHub's
  API shows only the noreply author). `git-filter-repo` was a one-off tool and is removed
  after (pkg-audit flagged it, correctly).
- The full-release proof (`check` sees a release, `apply --yes`, `rollback`, `apply`)
  needs a real tag, and a release is cut from `main` -- so it happens right after this
  branch merges, not before. `check` already handles the no-release state ("no release
  published yet"), confirmed against the real 404.
- Backlog: `symphony-update` could `hyprctl reload` after the swap when a Hyprland session
  is present (the config-error overlay during the swap window is expected but ugly);
  the 19 merged `phase/*` branches on the public remote are deleted at close.

## VM → physical hardware notes

- The whole pipeline is exercised on the Alienware itself: `apply --from` first (the
  updater deploys itself), then a real tag through CI, `apply`, `rollback`, `apply`. A
  fresh install verifying a release with the shipped key is owed on a second machine
  along with Phase 16/17's checks.

## Exit criteria

- [x] All acceptance tests pass (`phase-18.bats` 15/15; full suite on the Alienware at close)
- [x] Static checks pass (`scripts/check`, 323 unit tests)
- [x] `DECISIONS.md` updated (D-0078 to D-0081; D-0059, D-0062 amended)
- [x] `docs/omarchy-influences.md` updated
- [x] `docs/roadmap.md` status updated
- [x] Branch merged to `main`
