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

Red confirmed: · Green confirmed:

## Tasks

- [ ] Branch, tracking doc
- [ ] Red: `tests/acceptance/phase-12.bats`
- [ ] `install/install-base-system`: optional `SWAP_SIZE` path + unit tests
- [ ] `autarchy-bootstrap`: seed `current-release` marker
- [ ] Verify against the VM with `SWAP_SIZE` unset (no behavior change)
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
