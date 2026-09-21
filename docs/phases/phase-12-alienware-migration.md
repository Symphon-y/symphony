# Phase 12 — Offline release ISO + physical hardware migration (Alienware 14 / P39G)

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/12-alienware-migration` (merged 2026-09-17; work continues directly on `main`) |
| **Started** | 2026-09-16 |
| **Completed** | |

## Restructuring note (2026-09-17)

This phase originally covered only the Alienware hardware migration, with
the release-ISO mechanism split out as a separate Phase 13. **That split
was a mistake, corrected here.** The offline ISO exists *for* this
install; this install *needs* the offline ISO — they were never two
stories. The split caused two real regressions: Phase 13 branched from
`main` instead of from this phase's branch, silently losing first the ISO
boot fix (caught only because the Alienware visibly failed to boot with
it) and then the hibernation `SWAP_SIZE` feature (not caught until the
user pointed out they'd been asked to `git checkout` a branch on an ISO
whose entire point was needing no git operations after boot). Patching
each loss with a cherry-pick treated the symptom, not the cause. The fix:
Phase 12's full branch (offline-ISO fixes included, since they'd already
been cherry-picked onto it) merged into `main` directly, and this doc now
tracks the whole effort — offline ISO through installed Alienware — as one
line of work. Phase 13's own tracking doc
(`docs/phases/phase-13-offline-release-iso.md`) stays as an accurate
historical record of what it originally built; nothing there was wrong,
it just should never have been separate.

## Goal

The release ISO installs the entire `packages/*.txt` closure (official
packages + the 3 AUR packages) with zero network connectivity needed, and
autarchy runs on real hardware: a 2014 Alienware 14 (P39G), Intel HD 4600
as the base display driver, hibernation working via a dedicated LUKS2 swap
partition, with the discrete NVIDIA GPU and AlienFX RGB attempted as
explicit, non-blocking bonuses.

## Scope

**In scope**
- The release ISO bakes in the entire `packages/*.txt` closure (official
  packages via `pacman -Syw` against a blank dbpath, the 3 AUR packages
  built via `makepkg`, both `repo-add`'ed into a local repo baked into
  `iso/profile/airootfs/`) so install needs zero network connectivity --
  "buy a Windows key, plug in the USB, install" parity. Only
  `scripts/update` afterward needs the internet. (Originally Phase 13's
  scope; folded in here, see the restructuring note above.)
- Ground truth from the real hardware first (`lscpu`/`lspci`/`free`/`lsblk`/
  `dmidecode -t tpm`) before writing the hardware package list or picking
  `SWAP_SIZE`.
- BIOS: Secure Boot off, SATA mode AHCI.
- `install/install-base-system` extended with an optional `SWAP_SIZE` var:
  a 3rd GPT partition (`cryptswap`), LUKS2 + generated keyfile (no
  interactive prompt), `mkswap`, fstab/crypttab entries, `resume=` baked
  into the UKI cmdline. Empty/unset `SWAP_SIZE` = today's zram-only
  behavior, unchanged for the VM.
- The swap keyfile embedded into the initramfs via a per-host
  `system/hosts/<hostname>/` override (D-0021's existing per-host
  mechanism), not a global mkinitcpio change.
- `autarchy-bootstrap` fix: seed `~/.local/state/autarchy/current-release`
  from the tag it already reads, so `scripts/update` has a correct baseline
  from day one.
- `packages/alienware-14.txt`: `intel-ucode`, WiFi firmware if actually
  needed, `power-profiles-daemon`.
- Claude Code installed locally once base install + networking work;
  `docs/runbooks/rebuild.md` for the rest of the stack.
- Bonus, non-blocking, after the base system is confirmed stable: `nouveau`
  for the discrete GPU, AlienFX tooling (AUR `trackmastersteve/alienfx`).
- `tests/acceptance/phase-12.bats`.

**Out of scope**
- Secure Boot / UKI signing (deferred again — no TPM to pair it with).
- Decommissioning the VM.
- Redesigning anything Phases 1–11 already decided.
- Making the discrete GPU or AlienFX a hard requirement.

## Decisions

**Resolved**
- Device: Alienware 14 / P39G. Base GPU: Intel HD 4600 only, NVIDIA/nouveau
  a non-blocking bonus. Access model: Claude Code runs locally once base
  install + networking work.
- Hibernation: dedicated LUKS2 swap partition + keyfile (not a Btrfs
  swapfile — real, current `resume_offset=` fragility on Btrfs found during
  research).
- Secure Boot: deferred again (no TPM).
- AlienFX: bonus scope.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-12.bats`

| Group | What it proves | Who runs it |
|---|---|---|
| static (VM-checkable) | `install/install-base-system`'s `SWAP_SIZE` path is correctly optional; the VM itself stays zram-only | Claude |
| hardware | WiFi connects, `power-profiles-daemon` active, hibernate/resume works, TPM presence/absence recorded as fact | User, on the Alienware |

Red confirmed: 2026-09-16, 2/8 failing cleanly before implementation existed
(a real bug caught along the way: the "VM stays zram-only" test initially
checked swap TYPE, which zram itself also reports as "partition" -- fixed
to check by device name instead)
· Green confirmed (VM-checkable portion): 2026-09-16, 8/8; full
`scripts/check` green (130/130 unit tests); full acceptance suite green
(124/124, no regressions)

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-12.bats`
- [x] `install/install-base-system`: optional `SWAP_SIZE` path + unit tests
      (9 new tests: 3-partition layout, keyfile generation/permissions,
      LUKS2 format+open+mkswap, crypttab/fstab/mkinitcpio wiring,
      `AUTARCHY_RESUME_DEVICE` handoff)
- [x] `install/configure-base-system`: appends `resume=` to the UKI cmdline
      when `AUTARCHY_RESUME_DEVICE` is set + unit test
- [x] Release-marker seeding: implemented in `install-base-system` instead
      of `autarchy-bootstrap` as originally planned (that script runs
      before the target user/system exist) + 3 unit tests
- [x] Verify against the VM with `SWAP_SIZE` unset (no behavior change) --
      confirmed both by the regression test and the full existing test
      suite staying green
- [x] **Unplanned, real**: fix the release ISO itself, which turned out not
      to boot at all -- see log. Also hardened `release-iso.yml`'s
      `target_commitish` after the fix's own test-tag publish surfaced a
      second, separate real bug.
- [x] **Unplanned, real (originally Phase 13)**: bake the full
      `packages/*.txt` closure into a local repo at CI time
      (`iso/build-offline-repo`), a new live-environment
      `iso/profile/airootfs/etc/pacman.conf`, conditional splitting when
      the real built ISO exceeds GitHub's 2 GiB limit -- see
      `docs/phases/phase-13-offline-release-iso.md` for that work's own
      detailed log.
- [x] **Unplanned, real**: merge Phase 12's full branch into `main`
      directly (not another cherry-pick) after discovering the
      `SWAP_SIZE` feature had also gone missing from `main` the same way
      the boot fix once did -- see the restructuring note above.
- [x] **Unplanned, real**: fix a SIGPIPE race in `scripts/update`
      (`git tag --list ... | head -1` and `git status --porcelain |
      grep -q .` could both make git exit non-zero under `pipefail` if
      the reader closed the pipe before git finished writing) -- caught
      by a real, timing-dependent CI failure (exit 141) on an otherwise-
      identical commit that had already passed once. Fixed on its own
      branch, stress-tested 30x locally, merged separately (unrelated to
      the ISO/hardware work).
- [x] Ground truth on real hardware: `docs/environment/alienware-14.md` (2026-09-21; the BIOS steps that mattered -- Function Key Behavior, Wireless -- are recorded there and in D-0073/D-0076)
- [x] User: boot the offline ISO, `autarchy-install`, `install-base-system`
      with real `SWAP_SIZE` -- done via Phase 14's real-hardware
      verification loop (`autarchy-bootstrap` itself was retired by that
      phase; the guided `autarchy-install` flow replaced it, needing zero
      git operations at all). `2026.09.17-test14` confirmed a real,
      zero-network install completing to a rebootable, logged-in base
      system with hibernation-capable `SWAP_SIZE` wired up (D-0064,
      D-0065) -- see that phase's tracking doc for the full chain.
- [x] ~~`packages/alienware-14.txt`~~ superseded by D-0074's PCI-ID-keyed
      `system/hardware.txt` + `packages/hardware/broadcom-wl.txt` (Phase 17);
      base system boots and networks (Wi-Fi via `wl`, confirmed 2026-09-20)
- [x] Install Claude Code locally; hand off driving to a local session
      (2026-09-20: this and every later entry is written from the machine)
- [ ] `docs/runbooks/rebuild.md` for the full stack
- [ ] Verify hibernation for real; enable + verify `power-profiles-daemon`
- [ ] Bonus: `nouveau` attempt; AlienFX attempt
- [ ] Close: `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md`
- [x] Merge to `main` (offline-ISO + hibernation code; hardware-specific
      close-out still pending real install)

## Implementation log

### 2026-09-16
- Plan researched (hibernation mechanics with LUKS2+Btrfs+UKI+snapper;
  Alienware 14/P39G TPM presence) and approved. Both research passes
  reused/extended the Phase 10 release-ISO mechanism as the install path
  instead of a manual runbook replay.
- Branch and tracking doc created.
- Red: `tests/acceptance/phase-12.bats` written before any implementation.
  One real bug caught immediately: the "VM stays zram-only" test checked
  `swapon`'s TYPE column, which reports zram devices as "partition" too
  (it's kernel swap accounting, not a real block device) -- fixed to check
  by device name (`/dev/zram*`) instead.
- Implemented the `SWAP_SIZE` path in `install/install-base-system`
  (partition/keyfile/LUKS2/mkswap/crypttab/fstab/mkinitcpio wiring) and the
  `resume=` cmdline addition in `install/configure-base-system`, both
  unit-tested with stubs -- all green on the first real run.
  Reconsidered the release-marker-seeding design from the plan while
  implementing it: the plan said to fix `autarchy-bootstrap`, but that
  script runs on the live ISO *before* `install-base-system` has even
  partitioned the disk, let alone created the target user account -- there's
  nothing to seed yet at that point. Moved the fix to
  `install-base-system`'s new `seed_release_marker()`, which runs after
  `configure-base-system` creates the user, reading the live ISO's own
  `/etc/autarchy-release` (already present, written by the CI build,
  independent of whether `autarchy-bootstrap` ran) -- no change to
  `autarchy-bootstrap` needed at all.
  Full `scripts/check` (130/130 unit tests) and the full acceptance suite
  (124/124) stayed green throughout -- no regressions to the VM's own
  still-zram-only, still-`SWAP_SIZE`-unset state.
- Pushed a test tag, user flashed it via Rufus (DD mode) and booted it on
  the real Alienware for the first time. **It didn't boot**: hung on
  `timed out waiting for device /dev/gpt-auto-root`, six dependency
  failures, then an emergency shell with root locked -- unusable. This is
  the actual boot test the Phase 10 plan flagged as a stretch goal and
  never did; the gap was real.
  Root cause, found by pulling upstream releng's *complete* airootfs tree
  via the GitHub API (Phase 10 only skimmed the top-level directories):
  three things missing that mkarchiso/mkinitcpio-archiso do not supply
  automatically -- `etc/mkinitcpio.d/linux.preset` +
  `etc/mkinitcpio.conf.d/archiso.conf` (without pointing the build-time
  mkinitcpio invocation at the archiso-aware HOOKS, the stock `linux`
  package's own default preset built a normal, non-live-aware initramfs
  with no medium-search mechanism at all); a mask for
  `systemd-gpt-auto-generator` (`/etc/.../systemd-gpt-auto-generator ->
  /dev/null`, the same convention as masking a unit) -- without it,
  systemd's generic root-finding races the archiso-specific one and loses,
  which is exactly the reported timeout; and root being locked by the
  `shadow` package's own default (releng ships its own unlocked
  `etc/shadow`/`etc/passwd` + a tty1 autologin drop-in for the live
  medium). Also found and fixed in passing: `dhcpcd`/`iwd`/
  `systemd-resolved` were never enabled (mkarchiso doesn't auto-enable
  installed packages' services; releng enables its own explicitly the same
  way) -- without them the live environment has no network at all.
  Adapted rather than copied verbatim: root's shell is `/bin/bash`, not
  releng's `zsh` -- no reason to add a zsh dependency this ISO doesn't
  otherwise need.
  New regression tests added to `tests/acceptance/phase-12.bats` (archiso
  HOOKS + gpt-auto mask present; root unlocked + autologin; the three
  services enabled) so this class of bug can't silently recur.
  `check-identifiers` flagged `getty@tty1.service` as a false-positive
  email match (the path `getty@tty1.service.d/autologin.conf` -- same
  class already handled for `btrfs-scrub@-.timer`); added to the existing
  allowlist with a unit test.
  Rebuilt under the same `2026.09.16` test tag (deleted and recreated,
  since the previous build under that tag was genuinely broken and
  shouldn't stay published) -- **the rebuild succeeded, but the GitHub
  Release itself came back in a broken state**: `draft: true`, parked
  under an `untagged-<hash>` URL, `target_commitish: main` even though the
  tag was pushed against this phase's own branch. Root cause:
  `action-gh-release` had no explicit `target_commitish`, so it defaulted
  to the repo's default branch -- fine when a tag is always cut from
  `main` (the real, intended production case), but produces this exact
  inconsistent state for a tag pushed against any other ref, which is
  precisely what test-tagging a phase branch does. Un-drafted the release
  manually to unblock the user immediately, and hardened
  `release-iso.yml` with `target_commitish: ${{ github.sha }}` so a real
  release is never exposed to this class of bug either, with a new
  acceptance test. This fix itself was not re-verified with a fresh CI run
  (would only change how the release object is published, not the ISO
  content already fixed and published) -- it gets real exercise the next
  time any tag is pushed.

### 2026-09-17
- Built the offline-capable ISO under what was then a separate Phase 13
  (see that phase's own tracking doc for the detailed log: the local-repo
  mechanism, the real GitHub Release 2 GiB limit hit and handled, disk
  space turning out not to be the real constraint research worried about).
  Cut the first real production release tag, `2026.09.17`, from `main`.
- User attempted the real Alienware install with the new offline ISO:
  reached the timezone prompt, then hit **the exact same boot failure
  already fixed once** (`gpt-auto-root` timeout, locked-root emergency
  shell). Root cause: Phase 13 had branched from `main` before the boot
  fix (built on this phase's branch) ever merged there, so every Phase 13
  build was silently missing it. Cherry-picked the fix onto `main` via a
  small `phase/10-boot-fix-hotfix` branch, deleted and re-cut a genuinely
  fresh `2026.09.17` release. This one booted correctly.
- Told the user the next step required `git checkout
  phase/12-alienware-migration` after boot, to pick up the hibernation
  `SWAP_SIZE` feature -- which is still only on this phase's own,
  unmerged branch. The user correctly called this out: a manual git
  operation on an ISO whose entire purpose is needing none, and a direct
  symptom of the same root mistake (splitting one story into two phases)
  that had just caused the boot-fix regression. Audited
  `phase/12-alienware-migration` against `main` properly this time
  (`git log origin/phase/12-alienware-migration ^main`) rather than
  patching the one thing noticed -- found exactly one commit's worth of
  real, not-yet-merged code (`SWAP_SIZE`), confirmed nothing else was
  missing.
- **Restructured**: merged this phase's full branch into `main` directly
  (one conflict, in `release-iso.yml`'s publish step, resolved in favor of
  `main`'s newer splitting-aware version; the `target_commitish` fix was
  identical on both sides). Deduplicated `tests/acceptance/phase-13.bats`
  against `phase-12.bats` (4 tests existed in both from the two
  independent hotfixes) -- kept in `phase-12.bats`, the doc now tracking
  the unified effort. Full `scripts/check` (131/131 unit tests) and the
  full acceptance suite (137/137) green, no regressions.
- In passing, a real CI failure on the merge commit (exit 141, SIGPIPE) in
  `tests/unit/update.bats` led to finding and fixing a genuine,
  timing-dependent bug in `scripts/update` itself (two pipe-into-`head`/
  `grep -q` constructs that could SIGPIPE their producer under
  `pipefail`) -- unrelated to the ISO/hardware work, fixed and merged
  separately; see its own task entry above.
- Deleted the incomplete `2026.09.17` release (object + tag) a second
  time and cut a genuinely fresh one from the now fully-merged `main`,
  containing the offline ISO, the boot fix, and hibernation together.
- Added `autarchy-install` (a guided sequential prompt flow) and merged,
  cut a third `2026.09.17` release. **User tested it for real and found
  two more real gaps, both architectural, not cosmetic**: (1) the ISO
  still needed `gh repo clone`/`gh auth login` to get the actual install
  *scripts* -- Phase 13 baked in the package cache but never the repo
  content that drives the install, so "offline" was only half-true; (2)
  even a fully successful base install only reaches a bare TTY, not the
  working desktop the user actually wants at reboot -- `rebuild.md`'s
  scope was never automated. Root-caused honestly (see the user's own
  framing: each fix this session solved *the symptom just hit* rather
  than the whole stated goal) and, after real research (`dialog`/
  `whiptail` vs. Textual's real footprint difference; Omarchy's actual
  chroot-vs-first-boot desktop-bringup mechanism, read from its real
  source, not guessed), split the remaining work into three properly
  independent, individually-planned phases rather than another one-shot
  patch: **Phase 14** (bake the repo itself into the ISO), **Phase 15**
  (a real TUI installer), **Phase 16** (fully automated desktop
  bring-up, closing the actual "reboot into a working GUI" goal). This
  phase's own remaining hardware-install work resumes once those land.

## VM → physical hardware notes

- Steps through "boot the release ISO" happen with zero Claude access — the
  user runs them by hand, same division of labor as Phase 1. Claude resumes
  driving once Claude Code is installed locally on the Alienware.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/omarchy-influences.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
