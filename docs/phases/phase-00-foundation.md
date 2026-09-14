# Phase 00 — Foundation

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude (Mac, documentation only) |
| **Branch** | `main` (repository bootstrap — no phase branch possible before the first commit) |
| **Snapshot** | N/A — the VM is not touched |
| **Started** | 2026-09-12 |
| **Completed** | 2026-09-12 |

## Goal

A private GitHub repository holding the project's working agreement, decision log,
roadmap, Omarchy research framework, and phase tracking template.

## Scope

**In scope**
- `CLAUDE.md`, `README.md`, `DECISIONS.md`, `docs/roadmap.md`,
  `docs/omarchy-influences.md`, `docs/phases/_template.md`, this document
- `.gitignore`, `.editorconfig`
- Git init and private GitHub remote

**Out of scope**
- Any change to the VM
- Component directories and test harness (created by the phases that need them, D-0007)

## Decisions

**Resolved**
- D-0001 — Arch Linux is the foundation
- D-0002 — Lab VM on Unraid
- D-0003 — Private GitHub repository
- D-0004 — Phase lifecycle
- D-0005 — Engineering principles and TDD
- D-0006 — Claude Code handoff after base install
- D-0007 — Repository layout

## Acceptance tests

Not applicable — documentation-only phase (D-0005). The bats harness is introduced in
Phase 1 (acceptance) and Phase 2 (unit tests, CI). Verification is manual:

- `git log` shows the initial commit
- `gh repo view --json visibility` reports `PRIVATE`
- A fresh Claude Code session in the repo can state the standing orders from `CLAUDE.md`

## Tasks

- [x] Write `CLAUDE.md` (standing orders, principles, current driver)
- [x] Write `README.md`
- [x] Write `DECISIONS.md` (D-0001 … D-0007)
- [x] Write `docs/roadmap.md`
- [x] Write `docs/omarchy-influences.md` (framework + research list)
- [x] Write `docs/phases/_template.md`
- [x] Write `.gitignore` and `.editorconfig`
- [x] `git init -b main` and initial commit
- [x] Private GitHub repo exists (`Symphon-y/autarchy`)
- [x] Verify visibility is private
- [x] Push `main` to origin

## Implementation log

### 2026-09-12
- Mac inspected: Apple M2, 8 GB — control host only. Lab VM is on a remote Unraid
  server, booted into the Arch ISO (kernel 7.2.2-arch1-1), nothing installed.
- Roadmap planned in plan mode and approved. Wrote core documents.
- **Deviation:** planned `gh repo create`, but `Symphon-y/autarchy` already existed
  (empty, created minutes earlier, **public**). With the user's approval, switched it to
  private (verified `PRIVATE`) instead of creating a new repo.
- First push failed: `remote: Your repository is disabled` (HTTP 403), right after the
  visibility change. The API then reported `disabled: false`, which suggests GitHub was
  still processing the change. Claude's retry was blocked by the permission policy
  (out-of-place publication); the push is left for the user to run.
- User pushed `main` successfully. Verified: `origin/main` = local `HEAD` (`5db6bc0`),
  visibility `PRIVATE`, default branch `main`.
- **Lesson for later phases:** pushes to GitHub may need the user to run them (or a
  permission rule) until Claude's permissions inside the VM are settled in Phase 2.

## VM → physical hardware notes

- Nothing phase-specific. General VM limitations recorded in D-0002.

## Exit criteria

- [x] Private GitHub repo exists with all core documents
- [x] `DECISIONS.md` updated
- [x] `docs/omarchy-influences.md` framework in place
- [x] `docs/roadmap.md` shows Phase 0 Complete
