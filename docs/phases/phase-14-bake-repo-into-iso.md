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
- [x] Green: real test tag (fresh name, not reusing `2026.09.17`), real
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
- Real verification, three attempts. `2026.09.17-test1`: the build itself
  succeeded (a correct, correctly-split 2.7 GB ISO), but the job got
  killed by its 45-minute timeout mid-upload of the release assets --
  only the tiny `.sha256` had uploaded. Diagnosed as upload-speed
  variance at first; bumped `timeout-minutes` to 70 (separate commit,
  `e5fbd59`) and retried as `2026.09.17-test2` after deleting the poisoned
  partial release+tag. `2026.09.17-test2` reproduced the *exact same*
  symptom -- zero progress on the two `.iso.part` files for the entire
  70-minute window, only `.sha256` again -- which ruled out "just needs
  more time" and pointed at a real, reproducible bug in
  `softprops/action-gh-release`'s concurrent large-asset upload. Switched
  the publish step to the `gh` CLI directly (`gh release create` +
  sequential `gh release upload` per asset, each under its own `timeout
  600` with one retry) -- commit `7ffd32f`. `2026.09.17-test3` succeeded
  cleanly, all three assets uploaded in ~17 minutes. Downloaded and
  reassembled the real built ISO, `sha256sum -c` verified, confirmed the
  standard archiso layout (`autarchy/x86_64/airootfs.sfs`) is present.
  Deep squashfs-content inspection was attempted but blocked -- no
  `unsquashfs`/`squashfs-tools` available and no `sudo` to install it (nor
  does `bsdtar`/libarchive read squashfs) -- so full verification deferred
  to the user's own real USB boot test instead of a sudo-assisted
  inspection, per their choice.
- Real hardware boot test (user, `2026.09.17-test3`): got further than
  any previous attempt -- reached the guided `autarchy-install` flow with
  no network connection. Found two real problems at the disk-selection
  prompt: no way to see the available disks, and leaving it blank and
  pressing enter surfaced only as an unrelated, unhelpful "permission
  denied" much later rather than a clear error at the point of input.
  Root cause: the disk prompt used the same generic, unvalidated `ask()`
  as every other field, so a blank value could flow all the way into
  `install-base-system` before anything caught it. Fixed with dedicated
  `list_disks`/`ask_disk` functions in `autarchy-install`: lists every
  whole disk (name/size/model), labels the one the live medium itself is
  booted from (identified via archiso's own `/run/archiso/bootmnt`, not a
  hard block -- the existing typed-disk-path confirmation in
  `install-base-system` remains the real safety net), defaults to the
  sole non-installer-media disk when there's exactly one, and loops
  instead of ever returning a blank or unrecognized value. Verified with
  stubbed `lsblk`/`findmnt` covering: default-on-blank-Enter,
  explicit-valid-entry, blank-then-valid (loops), selecting the
  installer-media disk itself (allowed, labeled), invalid-then-valid
  (loops), and the ambiguous-multiple-disks case (no default, blank
  rejected). New acceptance coverage in `phase-12.bats` (where
  `autarchy-install`'s other tests already live). The "prompts are in a
  terminal, not a nice GUI" half of the same feedback is Phase 15's
  already-planned scope, not addressed here.
- `2026.09.17-test4` (disk-selection fix baked in): the build and the
  now-fixed gh-CLI publish pipeline both worked again, but a *different*,
  genuine failure showed up immediately -- a real `HTTP 500: Error saving
  asset` from GitHub's own upload API, hit twice in a row within seconds.
  This is exactly the fail-fast behavior the gh-CLI switch was meant to
  produce (a clear, immediate, actionable error instead of the old
  action's silent multi-hour hang), but two attempts with no delay
  between them wasn't enough to ride out a transient server error.
  Widened to 3 attempts with a 20-second backoff between them.
- `2026.09.17-test5` (disk-selection fix + wider retry): published
  cleanly. The user boot-tested it -- the disk listing/validation worked
  (real progress: "it looked like it was going to work better"), but
  after answering all the guided prompts and confirming the review
  screen, `autarchy-install` itself failed: `line 149:
  install/install-base-system: Permission denied` (bash's own
  exec-permission error, not one of our `die()` messages). `git ls-files
  -s install/install-base-system` confirmed the script is committed as
  `100755` -- so the executable bit is getting lost somewhere in the
  checkout -> rsync -> mkarchiso pipeline that bakes the repo into the
  ISO, a regression specific to Phase 14's new rsync-based bake-in
  (`autarchy-bootstrap`'s old live `git clone` always set the bit
  correctly from the git index at boot time; nothing exercised this path
  before). Reproduced the rsync step locally with `cp -a` as a stand-in
  (no `rsync` binary on this dev VM) -- permissions survived fine
  locally, which points at mkarchiso's own airootfs-to-squashfs staging
  rather than the rsync step itself, though the exact point was never
  pinned down for certain. Rather than chase it further, added a new CI
  step right after the bake-in (`git ls-files -s | awk '$1 ==
  "100755"'` -> `chmod 755` on each matching path inside the baked-in
  copy) that re-stamps every file git's own index says should be
  executable, immediately before mkarchiso ever reads the tree -- robust
  regardless of which downstream step was actually stripping it. New
  acceptance coverage in `phase-14.bats` (ordering: after the rsync
  bake-in, before the mkarchiso build).
- `2026.09.17-test6` failed fast (under 2 minutes -- never reached the
  actual ISO build), in the new chmod step itself: `git ls-files -s`
  lists every tracked file in the whole repo, including files under
  `iso/profile/airootfs/` itself -- deliberately excluded from the
  bake-in copy (avoids nesting the tree inside itself) and so never
  present at the destination path, causing a real `chmod: cannot access
  ...: No such file or directory`. Guarding with `[[ -e $path ]] &&
  chmod ...` alone wasn't enough either -- reproduced locally under
  `bash -e` before pushing again: a `while` loop's own exit status is
  whatever its *last* iteration's last command returned, so a loop whose
  final iteration skips a missing file still counts as "failed" and
  trips `set -e`, even though skipping is the correct, intended
  behavior. Fixed with `if [[ -e $path ]]; then chmod 755 "$path"; fi`
  instead -- an `if` with no `else` always exits 0 when its condition is
  false. Verified locally against this real repo (empty destination:
  loop completes; one file present with its bit deliberately stripped:
  loop completes and the bit is restored) before pushing `test6`'s
  replacement.
- `2026.09.17-test7` (with the CI-side chmod fix, correctly working this
  time) still failed on the real hardware boot test, with the *exact
  same* error. This meant the whole CI-side-chmod approach was wrong,
  not just buggy. Asked the user to check the live system directly:
  `ls -la` on both `install/install-base-system` and `scripts/
  system-report` showed `-rw-r--r--` for **both** -- not file-specific
  after all. `system-report`'s failure had simply been invisible the
  whole time: its call site is `scripts/system-report || true`
  (swallowed), while `install-base-system`'s call has no such guard
  (fatal, visible). Fetched `mkarchiso`'s actual source
  (`archlinux/archiso`, `archiso/mkarchiso`) directly to find the real
  mechanism rather than guess a fourth time:
  `_make_custom_airootfs()` copies the *entire* `airootfs/` tree with
  `cp -af --no-preserve=ownership,mode` -- deliberately stripping every
  mode bit on every file, unconditionally -- then restores ownership/
  mode **only** for paths explicitly listed in `profiledef.sh`'s
  `file_permissions` array. That fully explains every observation:
  `/usr/local/bin/autarchy-install` (listed) worked; everything else
  baked in under `/root/autarchy` (not listed) didn't. A CI-side chmod
  applied *before* `mkarchiso` runs can never survive this -- it's
  unconditionally discarded by the copy regardless of what mode was
  there beforehand, which is exactly why `test6`/`test7`'s fix, though
  itself correct and bug-free, could never have worked.

  Real fix: deleted the now-proven-dead CI chmod step entirely, and made
  `profiledef.sh`'s `file_permissions` array populate itself dynamically
  from git's own index (`git ls-files -s | awk '$1 == "100755"'`) for
  every path landing under the baked-in `/root/autarchy` copy, rather
  than hand-listing each script (a footgun -- a script added later would
  silently ship non-executable unless someone remembered to also list it
  here). `git` and the real `.git` checkout are both present in the
  build container when `mkarchiso` sources `profiledef.sh` (`iso/build-
  offline-repo` installs `git` first in the same `&&` chain; only the
  *bake-in destination copy* excludes `.git`, not the actual checkout).
  Verified by simulating `mkarchiso`'s own pre-declaration
  (`declare -A file_permissions`) and sourcing the real `profiledef.sh`
  locally: all 32 expected paths populate correctly, including both
  previously-broken scripts. New acceptance test dry-runs this exact
  logic against the real repo. Considered the (deprecated, explicitly
  flagged for removal in a future archiso version)
  `customize_airootfs.sh` chroot-hook mechanism found in the same
  source -- not used; `file_permissions` is the current, sanctioned
  mechanism for exactly this.

## VM → physical hardware notes

- The CI/static half is fully verifiable without hardware. The actual
  goal -- zero network access needed for the core install -- is only
  really provable on real hardware, so the user boot-tested each real
  release build on the Alienware as attempts landed. `test3` was the
  first to get far enough to reach `autarchy-install` with no network
  connection at all and surfaced the disk-selection bug fixed above;
  `test4` verifies that fix specifically.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
