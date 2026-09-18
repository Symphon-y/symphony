# Phase 14 — Bake the repo itself into the ISO

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude + user |
| **Branch** | `phase/14-bake-repo-into-iso` |
| **Started** | 2026-09-17 |
| **Completed** | 2026-09-18 |

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
- [x] Close: `DECISIONS.md`, `docs/roadmap.md`, merge to `main`

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
- `2026.09.17-test8` failed fast (~5 min, mid-build) with `fatal:
  detected dubious ownership in repository at '/workspace'` -- a real
  git safety feature: the checkout is owned by whichever user
  `actions/checkout` ran as, outside the `--privileged` container, and
  git (root, inside the container) refuses to open a repo it doesn't own
  unless told it's safe. My `repo_root=$(git -C ... rev-parse
  --show-toplevel)` line was itself the git call hitting this, before
  ever reaching the real `ls-files` call. Fixed by finding `repo_root`
  with plain `cd`/`pwd` instead (no git needed for that part), then
  explicitly `git config --global --add safe.directory "$repo_root"`
  before the one git call that actually needs it. Caught a second,
  self-inflicted problem while re-verifying locally: the new acceptance
  test sources `profiledef.sh` directly, which runs that same `git
  config --global` line -- on a developer's own machine, that would
  silently append a duplicate `safe.directory` entry to their real
  `~/.gitconfig` every time the test suite runs. Fixed by isolating
  `HOME=$BATS_TEST_TMPDIR` for that one test invocation. Verified: full
  `scripts/check` green, and confirmed `git config --global --get-all
  safe.directory` on this dev machine is empty before and after running
  the suite.
- `2026.09.17-test9` got much further -- past `build-offline-repo`, into
  `mkarchiso` itself, into `_make_custom_airootfs`'s airootfs copy (the
  exact function researched from source) -- confirming both the
  dynamically-populated `file_permissions` and the `safe.directory` fix
  worked. Hit a new, real error there: `ERROR: Failed to set permissions
  on '.../root/autarchy/iso/profile/airootfs/usr/local/bin/autarchy-
  install'. Outside of valid path.` `git ls-files -s` also tracks files
  *under* `iso/profile/airootfs/` itself (the live `autarchy-install`
  script's own source file) -- excluded from the bake-in rsync copy
  (same reasoning as `profiledef.sh`'s own header comment on that
  exclude), so it never exists under `/root/autarchy`. This is a
  genuinely different failure mode than assumed: mkarchiso's `realpath`
  check on a listed-but-nonexistent path fails *closed*, aborting the
  whole build, not the harmless "doesn't exist" warning its separate
  plain-existence check gives for every other legitimately-missing
  entry. Fixed by filtering `iso/profile/airootfs/` out of the generated
  list (`grep -v '^iso/profile/airootfs/'`). Verified locally: 31 entries
  now (was 32), the excluded path is gone, both previously-broken
  scripts still present, no leftover `iso/profile/airootfs` entries, no
  gitconfig pollution. New acceptance test asserts no generated key ever
  contains that path.
- `2026.09.17-test10` succeeded and, on the real hardware boot test, got
  further than any prior attempt: `autarchy-install` accepted the review
  screen and `install-base-system` actually started -- `sgdisk --zap-all`
  ran to completion (its "Exact type match not found for type code DE00"
  / "GPT data structures destroyed!" / "operation has completed
  successfully" output is normal `sgdisk` chatter, not an error --
  DE00 is the Dell diagnostic-partition type code, unsurprising on this
  Alienware). Failed on the very next command: `partprobe: command not
  found`. Checked systematically rather than fixing one command at a
  time again: extracted every external command `install-base-system`/
  `configure-base-system` invoke, cross-checked against
  `iso/profile/packages.x86_64` -- `parted` (provides `partprobe`) was
  the only genuine gap; every other command install-base-system calls
  directly on the live medium (not through `arch-chroot`, which only
  needs the *target's* own pacstrap'd packages) already has its
  providing package listed. Added `parted`. Extended the existing
  `phase-10.bats` "packages.x86_64 includes what the live installer
  needs" test to cover the same set (`gptfdisk`, `parted`, `cryptsetup`,
  `btrfs-progs`, `dosfstools`, `arch-install-scripts`), closing the gap
  systematically instead of one real-hardware failure at a time.
- `2026.09.17-test11` succeeded and, on the real hardware boot test, got
  further still: past LUKS format/open (the passphrase prompts are
  `cryptsetup`'s own -- chosen live at the terminal, not anything this
  repo sets), Btrfs subvolumes created, then failed formatting the ESP:
  `mount --mkdir -o fmask=0077,dmask=0077 ...` -> `unknown parameter
  'fmask'`. Researched rather than guessed: this is a known class of
  issue with modern util-linux's newer mount API (fsopen/fsconfig) --
  without an explicit `-t`, `mount` auto-detects the filesystem type via
  probing first, and the new API can fail to correctly route FAT-
  specific options (`fmask`/`dmask`, well-established, standard vfat
  options) to the vfat driver when the type isn't given upfront. Fixed
  by adding `-t vfat` explicitly -- safe and lossless here since the ESP
  was just formatted as FAT32 one line earlier (`mkfs.fat -F 32`), so
  there's no ambiguity about the type. Same fix applied to
  `base-install.md`'s manual-path runbook, which has the identical
  command. Nothing destructive: the LUKS volume, Btrfs subvolumes, and
  ESP formatting from this attempt are all still fine on disk; a full
  re-run (`sgdisk --zap-all` at the top of `partition_disk`) safely
  redoes everything from scratch either way, same as every prior retry
  this phase.
- `2026.09.17-test12` succeeded and got further still on real hardware:
  disk selection, LUKS format/open, Btrfs subvolumes, ESP mount all
  succeeded, then `pacstrap` died: `error: failed to synchronize all
  databases (no servers configured for repository)` / `ERROR: failed to
  install packages to new root`. Given how many real bugs this pipeline
  had already surfaced, the user asked for a deep investigation instead
  of another single-point guess -- ran two research passes in parallel:
  an Explore agent read every relevant file in this repo
  (`iso/profile/pacman.conf`, `iso/profile/airootfs/etc/pacman.conf`,
  `iso/build-offline-repo`, `install/install-base-system`'s `pacstrap`
  call, D-0063/phase-12/phase-13 docs); a research agent used
  WebSearch/WebFetch **and empirically reproduced the failure and the
  fix locally** on this dev VM, via `unshare -r` + a throwaway
  `--config`/`--dbpath`/`--root` pacman sandbox (no sudo, no system
  state touched), against upstream pacman C source, `pacstrap.in`,
  `mkarchiso`, and the Arch Wiki's "Offline installation" article. Both
  converged on the same root cause independently. Two real bugs found:
  (1) `[core]`/`[extra]` reference `/etc/pacman.d/mirrorlist`, which this
  ISO never ships -- falls back to the stock, fully-commented
  `pacman-mirrorlist` template, zero servers. `pacstrap`'s implicit
  `pacman -Sy` refreshes every enabled repo up front, and pacman's own
  sync code (`lib/libalpm/be_sync.c`, `alpm_db_update()`) asserts
  `db->servers != NULL` per repo in a loop that aborts the *entire* call
  on the first failure -- confirmed by reading pacman's actual source,
  independently reproduced locally (after the failure, the sync dir was
  completely empty, not even the correctly-configured `[localrepo]` got
  synced). This directly contradicted D-0063's "core/extra stay enabled
  as a network fallback" claim, which was never validated against a real
  `pacstrap` run -- corrected in a new decision entry (D-0064) rather
  than edited in place, per this repo's own established practice of
  keeping past decisions as accurate history. (2) Latent, would have
  surfaced next: `iso/build-offline-repo` built the repo as
  `autarchy.db.tar.zst` but the pacman.conf section is `[localrepo]`; for
  a bare `Server = file://` URL, pacman derives the expected database
  filename from the *section name*, not the containing directory's name
  -- a real mismatch, confirmed against `pacman.conf(5)`'s own example
  and reproduced locally.

  Fix: commented out (not deleted) `[core]`/`[extra]` in the live
  pacman.conf, matching the Arch Wiki's own documented practice for
  exactly this scenario; renamed `repo-add`'s output to
  `localrepo.db.tar.zst` (chose renaming the database over renaming the
  pacman.conf section + touching the `autarchy-repo` directory name,
  `.gitignore`, and every existing `phase-13.bats` test referencing
  `[localrepo]` -- confirmed via grep that the old db name was referenced
  in exactly one place, the smaller and lower-risk diff, after two
  earlier fixes this phase went wrong from changing more than
  necessary in one pass); added `-M` to the `pacstrap` call so the
  installed system doesn't inherit the live ISO's own blank mirrorlist
  (secondary, not the cause of the reported failure). Caught and fixed a
  real regression in `tests/unit/install-base-system.bats`'s `pacstrap`
  stub along the way: it hardcoded `$2` as the target directory
  position, which broke once `-M` shifted it to `$3`.

  Verified the exact fix locally before spending another CI + real
  destructive-hardware round trip: built a throwaway local repo
  (`repo-add localrepo.db.tar.zst`) and a candidate pacman.conf matching
  exactly what ships, ran `unshare -r pacman -Sy --config ... --dbpath
  ... --root ...` -- clean `exit 0`, package resolved correctly from
  `[localrepo]`. For comparison, reproduced the *original* broken shape
  (core/extra enabled, empty mirrorlist) in the same sandbox and got the
  byte-for-byte identical error text seen on real hardware, confirming
  both the diagnosis and the fix before pushing `2026.09.17-test13`.
- `2026.09.17-test13` succeeded and, on real hardware, got all the way
  through `pacstrap`'s full package install this time -- then the
  *installed system's own first boot* hung indefinitely: `A start job
  is running for /dev/mapper/cryptswap (27min / no limit)`. Not an
  install-script bug -- a real boot-time deadlock in Phase 12's
  hibernation feature (`SWAP_SIZE`). The user asked for the same depth
  of investigation again: ran two parallel research agents, one reading
  every line of this repo's swap/hibernation wiring, one reading
  systemd's actual generator source (`hibernate-resume-generator.c`,
  `cryptsetup-generator.c`) and the Arch Wiki. Root cause, confirmed
  from systemd's own source: `resume=/dev/mapper/cryptswap` was appended
  to the kernel cmdline (`configure_boot()`), but nothing ever added a
  matching `rd.luks.name=` for the swap device -- only root has one.
  `systemd-hibernate-resume.service` runs *inside the initramfs*,
  ordered before the real root mount, and binds to the resume device's
  unit; that device can only be created by unlocking `/etc/crypttab`'s
  `cryptswap` entry, which lives on the not-yet-mounted real root and is
  only processed *after* root mounts -- itself blocked on the resume
  service. A genuine, airtight deadlock, not a race, and with
  `JobTimeoutSec=infinity` (no `x-systemd.device-timeout` was set) it
  was never going to resolve on its own. Full root cause, fix design,
  and citations recorded in **D-0065**.

  Full fix implemented (user's explicit choice: wire up real
  hibernation now, not defer it) -- `configure_boot()` now looks up the
  swap partition's UUID the same way root's already is and adds
  `rd.luks.name=$swap_uuid=$swap_mapper` (mapper name derived from
  `$AUTARCHY_RESUME_DEVICE` via `basename`, no new env var) plus
  `resumeflags=x-systemd.device-timeout=30s` as unconditional insurance
  against a similar future hang ever being unbounded again. The swap
  keyfile is renamed `swap.key` -> `cryptswap.key` (matches
  `crypttab(5)`'s automatic per-mapper keyfile discovery, letting
  `sd-encrypt` find it from inside the initramfs with no extra
  `rd.luks.key=` parameter), and the crypttab entry gains
  `x-initrd.attach` (correct shutdown ordering now that the initramfs
  does the real unlock). `tests/unit/configure-base-system.bats`'s
  `blkid` stub -- previously a single hardcoded UUID for *any* queried
  device, which would have masked exactly this class of wrong-device
  bug -- made device-specific; added a new test directly encoding the
  invariant that was violated (`resume=/dev/mapper/X` implies
  `rd.luks.name=...=X` in the same cmdline), not just an update to the
  existing brittle full-string-match test. Given the user was mid-hang
  on real hardware, also handed them an immediate, out-of-band recovery
  procedure (power-cycle, boot the install USB, `arch-chroot` in, strip
  `resume=` from `/etc/kernel/cmdline`, rebuild the UKI) rather than
  making them wait on a fresh CI build.

  Explicitly **not** claimed: unlike the pacstrap fix, this class of bug
  (systemd generator/unit ordering during a real kernel boot) cannot be
  verified in a local sandbox -- there's no safe, no-sudo way to
  simulate initramfs/PID1 behavior the way `unshare -r pacman -Sy`
  simulated the pacman sync. Confidence comes from reading systemd's
  actual generator source directly and matching a real, confirmed-
  working reference setup, but real verification is still only a real
  hardware boot plus an actual `systemctl hibernate` + resume cycle --
  Phase 12's own hardware acceptance test for this has been a `skip
  "manual: ..."` stub since it was written and stays that way until
  that real cycle actually runs.

### 2026-09-18 — Close

- `2026.09.17-test14` succeeded, and the user confirmed it on real
  hardware: the fully offline, zero-network installer now completes
  end-to-end (disk selection -> LUKS/Btrfs/ESP -> `pacstrap` -> full
  `configure-base-system`) and the freshly installed system boots and
  logs in at a TTY with no hang. This is the goal the whole 14-test
  real-hardware chain was chasing: `autarchy-install` -> `install-
  base-system` completing to a rebootable, network-free base system.
- The user asked whether the lack of a GUI (no Hyprland) at that TTY
  login was expected. Confirmed against the repo, not assumed:
  `hyprland` lives in `packages/desktop.txt`, which the `pacstrap`
  glob (`packages/*.txt`) already installs, but `configure-base-
  system`'s `enable_services()` only enables base system services
  (NetworkManager, resolved, timesyncd, nftables, boot-update,
  fstrim, paccache) -- nothing starts a display manager or session.
  This is by design: Phase 1's own original acceptance criterion
  (`docs/roadmap.md`) is exactly "Boots to TTY; user login; network +
  pacman work" -- precisely what was just delivered, via a fully
  automated offline installer, for the first time. Session auto-start
  is explicitly Phase 16's ("Fully automated desktop bring-up")
  not-yet-started scope, not a gap in this phase.
- No `docs/omarchy-influences.md` entry this phase -- confirmed via
  grep that Phase 10's existing entry already covers the relevant
  Omarchy-ISO-approach comparison; nothing this phase's work (CI
  wiring, archiso/systemd/pacman internals) touched maps to a new
  Omarchy comparison point (same "confirmed none of these topics were
  ever covered" precedent Phase 9 set).
- Closed: `DECISIONS.md` (D-0064, D-0065), `docs/roadmap.md`, merged
  to `main`.

## VM → physical hardware notes

- The CI/static half is fully verifiable without hardware. The actual
  goal -- zero network access needed for the core install -- is only
  really provable on real hardware, so the user boot-tested each real
  release build on the Alienware as attempts landed. `test3` was the
  first to get far enough to reach `autarchy-install` with no network
  connection at all and surfaced the disk-selection bug fixed above;
  `test4` verifies that fix specifically. `test14` is the one that
  finally closed the loop: a real, from-scratch, zero-network install
  completing to a rebootable, logged-in base system on the actual
  Alienware -- the goal this entire real-hardware verification chain
  (test1 through test14, 14 real build-and-boot cycles) was chasing.

## Exit criteria

- [x] All acceptance tests pass
- [x] Static checks pass
- [x] `DECISIONS.md` updated
- [x] `docs/roadmap.md` status updated
- [x] Branch merged to `main`
