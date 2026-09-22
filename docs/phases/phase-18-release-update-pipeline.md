# Phase 18 — Release payload and update pipeline

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/18-release-update-pipeline` |
| **Started** | 2026-09-21 |
| **Completed** | |

## Goal

An installed machine -- no repo on it, only the root-owned payload at
`/usr/local/share/autarchy/current` (D-0067) -- can check for and apply the latest
release on demand: a signed, versioned payload from a GitHub Release, a pre-update
snapshot, a rollback. The same command deploys a checkout on the dev seat. The repo
becomes public so the release assets are plainly downloadable.

## Scope

**In scope**
- A release tag produces, in CI, `autarchy-<tag>-payload.tar.zst` (the six payload
  directories plus `VERSION`), its minisign signature and its sha256, on the same
  GitHub Release the ISO goes to; tags with a suffix are pre-releases.
- `autarchy-update check|apply|rollback|version` in a new `home/update/` stow package:
  download, verify (minisign against a public key shipped in `/etc/autarchy/`),
  snapshot, stage, swap `current`/`previous` at the same path, re-run the appliers
  and migrations from the new payload. `apply --from DIR` stages a checkout instead.
- `update-notify` moves into `home/update/` and also checks `releases/latest` daily.
- The git-based `scripts/update`, its tests and `docs/runbooks/dev-deploy.md` retired;
  `docs/runbooks/update.md` rewritten. The installer no longer seeds
  `~/.local/state/autarchy/current-release`; the payload's `VERSION` is the one source.
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
  at `system/autarchy/release.pub` and installed to `/etc/autarchy/release.pub`.
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
| The installed release | `/usr/local/share/autarchy/current/VERSION` |
| Where releases live | `AUTARCHY_RELEASE_REPO` in `autarchy-update` (overridable for tests), used by `update-notify` too |
| The public key | `system/autarchy/release.pub` -> `/etc/autarchy/release.pub` (`system/files.txt`) |
| The applier order | `autarchy-update apply`, the same order `rebuild.md` documented |

## Acceptance tests (written before implementation)

Files: `tests/unit/build-payload.bats`, `tests/unit/autarchy-update.bats`,
`tests/unit/update-notify.bats` (extended), `tests/unit/install-base-system.bats`
(marker seeding gone), `tests/acceptance/phase-18.bats`, `tests/acceptance/phase-10.bats`
(updated).

| Test | What it proves |
|---|---|
| `build-payload`: only the six dirs + `VERSION` from a ref; `.git`/`tests`/`gui`/`iso`/`docs` absent; unknown ref fails | Only committed OS content ships, nothing else can leak in |
| `autarchy-update check`: newer / equal / older; summary of `packages/` and `migrations/` changes | The user knows what an update brings |
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
- [ ] `scripts/build-payload`; public key + `files.txt`; `minisign` in the inventory
- [ ] `home/update/`: `autarchy-update`, `update-notify` moved in
- [ ] Installer: `seed_release_marker` removed
- [ ] Workflow: `payload` job (build, sign, release, upload); ISO job after it
- [ ] Retire `scripts/update`, `update.bats`, `dev-deploy.md`; rewrite `update.md`; README
- [ ] Green: `scripts/check`; on the Alienware: `apply --from`, a test tag, a real tag,
      `apply`, `rollback`, `apply`
- [ ] Public: LICENSE; old releases/tags deleted; history rewrite; force-push; visibility
- [ ] Close: D-0078 to D-0080, influences, roadmap, merge

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

## VM → physical hardware notes

- The whole pipeline is exercised on the Alienware itself: `apply --from` first (the
  updater deploys itself), then a real tag through CI, `apply`, `rollback`, `apply`. A
  fresh install verifying a release with the shipped key is owed on a second machine
  along with Phase 16/17's checks.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/omarchy-influences.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
