# Phase 00 — Foundation

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude (Mac, documentation only) |
| **Branch** | `main` (repository bootstrap — no phase branch possible before the first commit) |
| **Snapshot** | N/A — the VM is not touched |
| **Started** | 2026-09-12 |
| **Completed** | — |

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
- [ ] `git init -b main` and initial commit
- [ ] Create private GitHub repo and push
- [ ] Verify visibility is private

## Implementation log

### 2026-09-12
- Mac inspected: Apple M2, 8 GB — control host only. Lab VM is on a remote Unraid
  server, booted into the Arch ISO (kernel 7.2.2-arch1-1), nothing installed.
- Roadmap planned in plan mode and approved. Wrote core documents.

## VM → physical hardware notes

- Nothing phase-specific. General VM limitations recorded in D-0002.

## Exit criteria

- [ ] Private GitHub repo exists with all core documents
- [x] `DECISIONS.md` updated
- [x] `docs/omarchy-influences.md` framework in place
- [ ] `docs/roadmap.md` shows Phase 0 Complete
