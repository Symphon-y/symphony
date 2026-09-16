# Phase 10 — Installable release ISO

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude + user |
| **Branch** | `phase/10-installable-release-iso` |
| **Started** | 2026-09-16 |
| **Completed** | 2026-09-16 |

## Goal

A tagged commit on `main` produces a real, bootable, installable Arch ISO via
GitHub Actions, published as a GitHub Release — replacing "manually adapt and
re-run `base-install.md` on new hardware" as the bootstrap mechanism. A
second, related gap closes at the same time: an already-installed machine
gets a proper update entry point (`scripts/update`) that snapshots before
reapplying config-only changes, not just before pacman transactions.

## Scope

**In scope**
- `iso/profile/`: a standard `archiso` profile (based on upstream `releng`,
  no Omarchy code, no custom package mirror/repo, no AUR baked in) whose
  `packages.x86_64` covers only what the live installer environment needs
  (git, github-cli, bats + bats-assert + bats-support) — the desktop stack
  still comes from `packages/*.txt` at pacstrap time, exactly as today.
- An `airootfs` first-boot helper (`autarchy-bootstrap`) that reads the
  release tag baked in at build time and runs `gh auth login --web` +
  `gh repo clone --branch <tag>` — collapsing today's manual step 1 typing
  into one command. The `gh auth login` device-code handshake stays
  interactive by design; no credential is embedded in the ISO.
- `install/install-base-system`: a new script covering runbook steps 4–5
  (partition/LUKS/Btrfs/pacstrap/fstab), driven by the existing
  `base-install.local.vars`, gated by one explicit typed confirmation
  before anything destructive, then calling the existing
  `install/configure-base-system` (step 6, untouched) as its last step —
  the same collect-once-then-run-unattended shape Windows/macOS installers
  use, composed from our own scripts.
- `.github/workflows/release-iso.yml`: triggers on a `20*.*.*`-shaped tag
  push to `main`; builds via `mkarchiso` in a privileged Arch container;
  publishes the `.iso` + checksum as a GitHub Release asset.
- `docs/runbooks/base-install.md` updated to document both the new fast
  path (boot the release ISO, run one script) and the existing manual path
  (kept as the documented recovery/fallback).
- `scripts/update`: the ongoing update entry point for an already-installed
  machine. Diffs the currently-applied release tag (tracked in a marker
  file) against the latest available tag, summarizes pending
  package/migration changes, and on explicit accept takes an unconditional
  `snapper create` *before* running the existing appliers
  (`install/install-packages`, `install/link-home apply`,
  `install/sync-system apply`, `scripts/migrate apply`) in order, recording
  the new tag as current only once every step succeeds. On mid-run failure,
  points at the pre-update snapshot and the existing D-0008 rollback path.
- `docs/runbooks/update.md`: documents the normal update flow.
- `tests/acceptance/phase-10.bats`, unit tests for both new scripts.

**Out of scope**
- Any full offline/desktop-preloaded ISO, custom package mirror, or
  self-hosted repo — stays REJECTed (D-0050).
- Pre-building AUR packages into the ISO.
- The Alienware-specific hardware bring-up — moves to Phase 12.
- Any change to the existing appliers themselves (`install/link-home`,
  `install/sync-system`, `scripts/migrate`) beyond `scripts/update` calling
  them in sequence.

## Decisions

**Resolved**
- Mechanism: our own `archiso` profile, no Omarchy code, no custom
  mirror/repo.
- Release trigger: a date-based tag on `main` (e.g. `2026.09.16`).
- Automation depth: one new script (`install/install-base-system`) extends
  `configure-base-system`'s contract backward to cover steps 4–5, composing
  with (not duplicating) the existing step-6 script.
- D-0009's REJECT targets Omarchy's TUI+archinstall+custom-mirror mechanism
  specifically, not custom bootable media in general — recorded explicitly
  at close-out rather than assumed silently.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-10.bats`

| Group | What it proves |
|---|---|
| archiso profile | `iso/profile/` has the required archiso files; `packages.x86_64` excludes the desktop stack; `profiledef.sh` is UEFI-only, matching D-0010 |
| release workflow | `.github/workflows/release-iso.yml` exists, is valid YAML, triggers on a date-shaped tag |
| new scripts | `install/install-base-system` and `scripts/update` exist, are executable, shellcheck/shfmt-clean (via `scripts/check`) |

Red confirmed: 2026-09-16, all failing cleanly before implementation existed
· Green confirmed: 2026-09-16, 13/13; full `scripts/check` green (121/121
unit tests, shellcheck/shfmt/JSON/YAML/identifiers)

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-10.bats` (13 tests written before any
      implementation existed)
- [x] `iso/profile/` archiso profile + `autarchy-bootstrap` first-boot helper
- [x] `install/install-base-system` + unit tests (11/11 green)
- [x] `.github/workflows/release-iso.yml`
- [x] `scripts/update` + unit tests (11/11 green) + `docs/runbooks/update.md`
- [x] `scripts/check` updated to cover `iso/` shell files and YAML syntax
- [x] `docs/runbooks/base-install.md` updated with both paths
- [x] Green: 13/13 `phase-10.bats`; full `scripts/check` green (121/121
      unit tests). User installed `yq`; also caught that Arch's `yq`
      package is kislyuk/yq (a jq wrapper: `yq '.filter' file`), not
      mikefarah/yq (`yq eval '.filter' file`) -- fixed both `scripts/check`
      and the acceptance tests to the real installed syntax
- [x] Verify a real tag push produces a release ISO on a real GitHub Release
      -- confirmed for real: `2026.09.16` on GitHub Releases carries
      `autarchy-2026.09.16.iso` + `.sha256`, built by
      `.github/workflows/release-iso.yml` (13m3s, well under the 45min
      timeout). Took 4 pushes of the same test tag to get there, each one a
      real bug this approach was specifically meant to catch before it ever
      reached hardware (see implementation log).
- [x] Exercise `scripts/update` against the live VM for real
- [x] Close: `DECISIONS.md` (D-0061, D-0062), `docs/omarchy-influences.md`,
      `docs/roadmap.md`
- [x] Merge to `main`

## Implementation log

### 2026-09-16
- Plan researched (archiso mechanics, `omacom/omarchy-iso`'s real structure,
  independent GitHub Actions ISO-build examples) and approved. Mid-planning,
  the user redirected twice: first toward a custom release ISO instead of a
  manual reinstall, then (after seeing the archiso/Omarchy research) added a
  second, related gap directly to the plan file — an ongoing `scripts/update`
  entry point with an unconditional pre-update snapshot for config-only
  reapply cycles, which the existing `snap-pac` (D-0011) doesn't cover since
  it only fires on pacman transactions.
- Branch and tracking doc created.
- Built the archiso profile (`iso/profile/`: `profiledef.sh` UEFI-only per
  D-0010, `pacman.conf` unmodified from upstream releng, a deliberately thin
  `packages.x86_64`, and the `autarchy-bootstrap` first-boot helper),
  `install/install-base-system` (steps 4-6, composing with rather than
  duplicating `configure-base-system`), `.github/workflows/release-iso.yml`
  (privileged-container `mkarchiso`, corroborated against Omarchy's own real
  workflow and independent examples), and `scripts/update` (unconditional
  pre-update snapshot, then the same appliers `rebuild.md` already
  documents). Real bugs caught and fixed during unit testing: the
  block-device check needed to go through `lsblk` rather than a bash `[[ -b
  ]]` builtin to stay stubbable; the pacstrap stub needed to create
  `$TARGET/etc` itself, same as real pacstrap does, for genfstab's redirect
  to have somewhere to write; `scripts/update` originally took its snapshot
  *before* validating which branch the repo was on -- moved the branch
  check earlier so nothing destructive happens before every precondition is
  validated, matching this repo's established pattern.
  `action-gh-release`'s pinned commit SHA was initially guessed wrong and
  caught by verifying it against the real tag via `gh api` before it ever
  shipped.
  Added `yq` to `packages/tooling.txt` for YAML syntax checking (mirrors the
  existing `jq`/JSON check in `scripts/check`) -- not yet installed on this
  VM, so `scripts/check` and 2 of 13 `phase-10.bats` tests fail locally
  until the user installs it; nothing else regressed (full unit suite
  121/121, full acceptance suite otherwise clean).
  Close-out docs written: `DECISIONS.md` D-0061 (the ISO decision, recording
  explicitly why it doesn't reopen D-0009's REJECT) and D-0062 (`scripts/
  update`'s snapshot, extending D-0011); `docs/omarchy-influences.md`'s
  "Installer / bootstrap flow" entry got a Phase 10 addendum rather than a
  changed verdict; `docs/roadmap.md` Phase 10 retitled, Phase 12 added for
  the Alienware migration with its already-resolved decisions carried
  forward.
- User installed `yq`; turned out to be a real gap in my own assumption --
  Arch's official `yq` package is kislyuk/yq (a jq wrapper, `yq '.filter'
  file`), not mikefarah/yq (`yq eval '.filter' file`, what I'd written
  against). Fixed `scripts/check` and both YAML acceptance tests to the
  actually-installed syntax; confirmed against the real binary before
  trusting it.
- User approved pushing a real test tag. Took 4 pushes of `2026.09.16`
  against the same phase branch, each one catching a real bug the whole
  point of this mechanism is to catch before it ever reaches hardware:
  (1) `mkarchiso` requires `efiboot/loader/entries/` to exist for
  `uefi.systemd-boot` -- missing entirely from the first profile, fixed by
  replicating upstream releng's minimal loader.conf + boot entry;
  (2) `packages.x86_64` is read directly by `mkarchiso`, not through
  `scripts/pkglist` -- it has no inline-comment support, and the trailing
  comments this project's own `packages/*.txt` convention uses became part
  of the literal package name (`error: target not found: intel-ucode<tab>`),
  fixed by moving every comment to its own line; (3) the privileged build
  container runs as root and writes the ISO into a bind-mounted host
  directory, so the next step (running as the plain runner user, no
  container) got `Permission denied` renaming it -- fixed with a `chown`
  back to the runner's UID/GID from inside the container before it exits.
  The 4th push succeeded end to end: `autarchy-2026.09.16.iso` +
  `.sha256` published on a real GitHub Release, 13m3s build time.
  Also ran `scripts/update check` and `scripts/update apply` for real
  against this VM (not just stubbed): `check` correctly reported
  `(none) -> 2026.09.16`; `apply`, run from this phase branch on purpose,
  correctly refused before touching anything ("on branch
  'phase/10-installable-release-iso', not main"), a real confirmation of
  that guard rather than only a stubbed one.

## VM → physical hardware notes

- This phase is fully completable and verifiable from the VM — no physical
  hardware required. The Alienware migration (Phase 12) is where this ISO
  gets used for real.

## Exit criteria

- [x] All acceptance tests pass
- [x] Static checks pass
- [x] `DECISIONS.md` updated
- [x] `docs/omarchy-influences.md` updated
- [x] `docs/roadmap.md` status updated
- [x] Branch merged to `main`
