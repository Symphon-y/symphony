# Phase 12 — Physical hardware migration (Alienware 14 / P39G)

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/12-alienware-migration` |
| **Started** | 2026-09-16 |
| **Completed** | |

## Goal

autarchy runs on real hardware: a 2014 Alienware 14 (P39G), installed via
the Phase 10 release ISO, Intel HD 4600 as the base display driver,
hibernation working via a dedicated LUKS2 swap partition, with the discrete
NVIDIA GPU and AlienFX RGB attempted as explicit, non-blocking bonuses.

## Scope

**In scope**
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
- [ ] User: ground truth on real hardware, BIOS steps
- [ ] User: boot release ISO, `autarchy-bootstrap`, `install-base-system`
      with real `SWAP_SIZE`
- [ ] `packages/alienware-14.txt`; verify base system boots + networks
- [ ] Install Claude Code locally; hand off driving to a local session
- [ ] `docs/runbooks/rebuild.md` for the full stack
- [ ] Verify hibernation for real; enable + verify `power-profiles-daemon`
- [ ] Bonus: `nouveau` attempt; AlienFX attempt
- [ ] Close: `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md`
- [ ] Merge to `main`

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
