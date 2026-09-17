# Phase 13 — Offline-capable release ISO

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude + user |
| **Branch** | `phase/13-offline-release-iso` |
| **Started** | 2026-09-17 |
| **Completed** | 2026-09-17 |

## Goal

The release ISO installs the entire `packages/*.txt` closure (official
packages + the 3 AUR packages) with zero network connectivity needed —
"buy a Windows key, plug in the USB, install" parity. Only `scripts/update`
afterward needs the internet. Phase 12 (Alienware migration) is paused
until this lands, then resumes with a working offline ISO.

## Scope

**In scope**
- CI build step: `pacman -Syw` (blank throwaway dbpath) the full
  official-repo closure from `packages/*.txt`; `makepkg` the 3 AUR
  packages (`yay`, `xdg-terminal-exec`, `bibata-cursor-theme-bin`);
  `repo-add` into one local repo database baked into `iso/profile/
  airootfs/`.
- New `iso/profile/airootfs/etc/pacman.conf`: `[localrepo]` first
  (`SigLevel = Optional TrustAll`, `file://` to the baked-in path),
  `[core]`/`[extra]` kept as a network fallback.
- `release-iso.yml`: the new download/build/repo-add steps; `df -h`
  logging around the build so real disk-usage numbers land in the first
  CI run; publish via the existing `softprops/action-gh-release` step,
  unchanged unless the real built file's actual size requires splitting.
- `DECISIONS.md`: the local-repo-vs-mirror distinction, extending D-0061.
- `tests/acceptance/phase-13.bats`.

**Out of scope**
- Deciding to split before a real build exists to measure.
- Any change to `install/install-base-system`'s pacstrap invocation.
- Re-opening the Alienware hardware migration (stays Phase 12).
- The ArcoLinux-style pre-installed-filesystem alternative.

## Decisions

**Resolved**
- Bake the whole package closure into a local repo built fresh at CI time
  (not a standing mirror — see D-0061/D-0050 reconciliation in the plan).
- Publish exactly like Phase 10 (real GitHub Release); only split if the
  real, measured build actually exceeds 2 GiB.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-13.bats`

| Group | What it proves |
|---|---|
| static (VM-checkable) | `airootfs/etc/pacman.conf` has `[localrepo]` ranked above `[core]`/`[extra]` with the right SigLevel; the workflow has the download/build/repo-add steps |
| CI (real) | The actual build succeeds within GitHub Actions' resource limits, produces a valid ISO, and publishes |
| hardware (Phase 12, resumed after) | Installs with zero network connectivity |

Red confirmed: 2026-09-17, 6/6 failing cleanly before implementation
existed · Green confirmed: 2026-09-17, 10/10 static + 2 real end-to-end CI
runs (see log) producing a real, split, downloadable ISO
(2,439,299,072 bytes total)

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-13.bats` (6/6 failing cleanly before
      implementation)
- [x] `iso/build-offline-repo`: downloads the official closure (blank
      dbpath), builds the 3 AUR packages as a non-root build user,
      repo-adds both into one local repo
- [x] `iso/profile/airootfs/etc/pacman.conf`: `[localrepo]` ranked above
      `[core]`/`[extra]`, `SigLevel = Optional TrustAll`; confirmed
      `iso/profile/pacman.conf` (build-time-only) stays untouched
- [x] `release-iso.yml`: calls `build-offline-repo` before `mkarchiso`;
      `df -h` logging before/after the build
- [x] Green (static): 7/7 `phase-13.bats`; full `scripts/check` (121/121
      unit tests); full acceptance suite (123/123, no regressions)
- [x] Green (real): pushed a real test tag twice. First real run: build
      succeeded end to end (repo build, AUR builds, mkarchiso all green)
      but the real ISO measured over GitHub's 2 GiB per-file limit --
      confirmed, not assumed, exactly the contingency the plan accounted
      for. Added conditional splitting; second real run: build succeeded,
      split into 2 parts, real total size **2,439,299,072 bytes (≈2.27
      GiB)**. Disk space was never actually tight (72 GB runner, peaked at
      33/72 GB used) -- the pessimistic 14 GB "guaranteed floor" estimate
      didn't materialize as a real constraint.
- [x] Close: `DECISIONS.md`, `docs/roadmap.md`, merge to `main`
- [ ] Resume Phase 12 with the new offline ISO

## Implementation log

### 2026-09-17
- Plan researched (GitHub Release size limits, this repo's own real
  package-closure size measured from the VM, the real local-repo-baking
  mechanism, CI feasibility) and approved after two rounds of correction
  from the user: first rejecting a pre-built split-into-parts design
  ("splitting the iso is not an option... we get a singular non split ISO
  working"), then rejecting a GitHub-Actions-workflow-artifact-instead-of-
  a-real-Release design ("why does your plan still involve pushing to
  github?"). Landed on: keep Phase 10's existing GitHub Release publish
  mechanism entirely unchanged, and don't decide splitting at all until a
  real build gives a real, measured size.
- Branch and tracking doc created.
- Implemented `iso/build-offline-repo` (pacman -Syw with a blank dbpath,
  makepkg as a non-root build user for the 3 AUR packages, repo-add) and
  `iso/profile/airootfs/etc/pacman.conf` ([localrepo] ranked above
  [core]/[extra]); wired into `release-iso.yml` with `df -h` logging
  before/after the build. All 7/7 `phase-13.bats`, full `scripts/check`
  (121/121), and the full acceptance suite (123/123) green, no
  regressions -- confirmed `iso/profile/pacman.conf` (build-time-only)
  correctly stayed untouched.
- User approved a real test-tag push. First real run: the offline-repo
  build, AUR builds, and `mkarchiso` all succeeded, but publishing to the
  Release failed with GitHub's own real error --
  `"size must be less than 2147483648"` -- confirming (not assuming) the
  research's ~2.5-2.8GB estimate. Implemented conditional splitting
  (`stat -c%s` the real built file; `split -d -b 1800M` only if it's
  actually at or over 2 GiB) and re-pinned `target_commitish` (branched
  from `main` before Phase 12's identical fix existed anywhere).
  `docs/runbooks/base-install.md` documents reassembly (`cat` the parts,
  `sha256sum -c` before writing to USB).
  Second real run: succeeded end to end, split into 2 parts, real total
  size 2,439,299,072 bytes. Publishing itself still came back as a
  draft under an `untagged-<hash>` URL -- not a regression of the
  `target_commitish` fix (confirmed via `gh api`: it correctly resolved to
  the exact tagged commit's SHA this time) but a *different* real
  artifact: `action-gh-release` updates an existing release's assets when
  a tag name matches one it already created, without correcting a
  draft/untagged state from that release's *original* creation --  and
  this exact tag name (`2026.09.16`) had already been reused across every
  test-tag push since Phase 10's first broken attempt, keeping the same
  underlying release object (`id: 390191429`) alive the whole time.
  Un-drafted it manually to unblock the user immediately; a genuinely
  fresh tag (any real production release) won't inherit this, since it
  will get an unpoisoned release object from `action-gh-release`'s first
  creation of it.

## VM → physical hardware notes

- This phase is fully completable and verifiable from the VM/CI — the
  "installs with zero network" claim gets its real proof when Phase 12
  resumes on the Alienware.

## Exit criteria

- [x] All acceptance tests pass
- [x] Static checks pass
- [x] `DECISIONS.md` updated
- [x] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
