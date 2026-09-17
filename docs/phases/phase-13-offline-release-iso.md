# Phase 13 — Offline-capable release ISO

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/13-offline-release-iso` |
| **Started** | 2026-09-17 |
| **Completed** | |

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

Red confirmed: · Green confirmed:

## Tasks

- [ ] Branch, tracking doc
- [ ] Red: `tests/acceptance/phase-13.bats`
- [ ] `release-iso.yml`: package-download/AUR-build/repo-add steps + `df -h`
      logging
- [ ] `iso/profile/airootfs/etc/pacman.conf`
- [ ] Green: real test-tag push, verify actual build succeeds and real ISO
      size
- [ ] Close: `DECISIONS.md`, `docs/roadmap.md`, merge to `main`
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

## VM → physical hardware notes

- This phase is fully completable and verifiable from the VM/CI — the
  "installs with zero network" claim gets its real proof when Phase 12
  resumes on the Alienware.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
