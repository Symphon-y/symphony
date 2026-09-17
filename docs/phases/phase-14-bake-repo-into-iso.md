# Phase 14 — Bake the repo itself into the ISO

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/14-bake-repo-into-iso` |
| **Started** | 2026-09-17 |
| **Completed** | |

## Goal

The core install needs zero network/GitHub access at any point.
`iso/profile/airootfs/root/autarchy` gets a pinned, complete copy of the
repo at CI build time; `autarchy-bootstrap` (whose entire job was cloning
that repo from GitHub) is retired.

## Scope

**In scope**
- New CI step in `release-iso.yml`: `rsync -a` the checked-out repo into
  `iso/profile/airootfs/root/autarchy/`, excluding `.git` and
  `iso/profile/airootfs` itself (avoids self-nesting and doubling the
  ~1.4 GiB local package cache `build-offline-repo` populates after this
  step). Ordered after "Record the release tag."
- Retire `autarchy-bootstrap`: delete the script, plus its four ripple
  effects (`profiledef.sh`'s `file_permissions` entry,
  `phase-10.bats`'s existence test, `phase-12.bats`'s
  calls-autarchy-bootstrap assertion, `base-install.md`'s wording).
- `autarchy-install` simplifies: no conditional clone, just `cd
  /root/autarchy` directly.
- New acceptance coverage for the CI step (source review, same pattern as
  the existing offline-repo-builder check).

**Out of scope**
- Optional git/GitHub identity collection (Phase 15).
- The TUI/guided-flow rewrite (Phase 15).
- Automated desktop bring-up after base install (Phase 16).

## Decisions

**Resolved**
- Bake-in location: `/root/autarchy`, matching the path `autarchy-install`
  already expects.
- Exclude `.git` and `iso/profile/airootfs` specifically from the
  bake-in copy, not all of `iso/`.
- Delete `autarchy-bootstrap` rather than leave it as dead/unused code.

## Acceptance tests (written before implementation)

| Group | What it proves |
|---|---|
| static | CI workflow has the bake-in step with the right excludes, in the right order; `autarchy-bootstrap` is fully gone (script + all four ripple-effect references); `autarchy-install` no longer calls it |
| real (CI) | A tag push produces an ISO whose live environment has the repo already present with zero GitHub access needed |

Red confirmed: 2026-09-17 (tests 3 and 4 failed correctly; 1 and 2 passed
immediately since the CI step was written test-first alongside them) ·
Green confirmed: 2026-09-17 (all 4 pass; full `scripts/check` exits 0)

## Tasks

- [x] Branch, tracking doc
- [x] Red: acceptance tests
- [x] CI bake-in step
- [x] Retire `autarchy-bootstrap` + 4 ripple-effect fixes
- [x] Simplify `autarchy-install`
- [x] Green: static checks
- [ ] Green: real test tag (fresh name, not reusing `2026.09.17`), real
      verification of zero-network install
- [ ] Close: `DECISIONS.md`, `docs/roadmap.md`, merge to `main`

## Implementation log

### 2026-09-17
- Plan researched and approved as part of the larger Phase 14/15/16
  breakdown (see Phase 12's tracking doc for the full root-cause context:
  the offline ISO baked in packages but never the repo driving the
  install).
- Branch and tracking doc created.
- Red: `tests/acceptance/phase-14.bats` written (4 tests). One self-caused
  bug along the way: the workflow-ordering test's `build_line` grep first
  matched a header *comment* mentioning `build-offline-repo` rather than
  the real invocation, giving a false ordering failure -- fixed by
  narrowing the pattern to the actual `/workspace/iso/build-offline-repo`
  call site.
- CI bake-in step added to `release-iso.yml`: `rsync -a --exclude='.git'
  --exclude='iso/profile/airootfs'` into
  `iso/profile/airootfs/root/autarchy/`, ordered right after "Record the
  release tag."
- `autarchy-bootstrap` deleted, plus its ripple effects: the
  `file_permissions` entry in `profiledef.sh`; the existence test in
  `phase-10.bats` (removed -- the mechanism it tested is gone, same
  precedent as other retired-mechanism cleanups this repo has done);
  `phase-12.bats`'s `autarchy-install`-composes-it assertion (removed);
  wording in `base-install.md` (repo is already at `/root/autarchy`, no
  clone/`gh auth login` step). Two references the original plan didn't
  anticipate also turned up in a full-repo grep and got fixed: a comment
  in `install/install-base-system` and one in `scripts/update`.
- `autarchy-install` simplified: dropped the `if [[ ! -d $CLONE_DIR ]];
  then autarchy-bootstrap; fi` guard, `cd "$CLONE_DIR"` unconditionally.
- The retirement test itself (`autarchy-bootstrap is fully retired`)
  needed one design correction after writing it: it originally required
  the string to be *completely* absent from the tree except for itself,
  which conflicts with this repo's own established precedent (Phase 13's
  fold-back) of keeping historical tracking docs (`phase-10`, `phase-12`,
  and this phase's own doc) as accurate records of what was true when
  they were written. Narrowed to exclude `docs/phases/` specifically
  (via `--exclude-dir=phases`, since grep's `--exclude-dir` matches a
  bare directory name, not a path) rather than every file.
- Full `scripts/check` run: one real shellcheck failure (SC2016, a
  literal `$CLONE_DIR` inside a single-quoted grep pattern in the new
  test) and one directive-syntax mistake fixing it (`# shellcheck
  disable=SC2016 -- ...` isn't valid syntax in this codebase's shellcheck
  version; the working form uses `#` before the explanation, matching
  every other disable comment already in the repo). Also updated one
  unit-test description in `tests/unit/update.bats` that named the
  retired mechanism ("post-bootstrap clone" -> "post-install baked-in
  repo checkout") for accuracy, since that test itself is not a
  historical record. `scripts/check` now exits 0, zero `not ok` lines.

## VM → physical hardware notes

- Fully verifiable from CI — no physical hardware needed for this phase.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
