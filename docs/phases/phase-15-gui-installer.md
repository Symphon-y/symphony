# Phase 15 — Real GUI guided installer

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/15-gui-installer` |
| **Started** | 2026-09-18 |
| **Completed** | |

## Goal

Boot the release ISO and land in a real, graphical guided installer
(cage + a hand-written GTK4/libadwaita app) -- not a terminal prompt --
that collects every field once (including the LUKS root passphrase,
closing a real existing gap) and then runs the install fully
unattended, matching the "confirm settings, remove the USB, reboot"
flow the user originally asked for.

## Scope

**In scope**
- Passphrase-fd contract: `install/install-base-system`'s
  `cryptsetup luksFormat`/`open` read the root LUKS passphrase from a
  dedicated file descriptor (fd 3), never interactively, never written
  to the vars file or disk.
- Split the terminal collector from the shared install runner so both
  the terminal fallback and the future GUI hand off through one
  contract.
- Terminal fallback (`autarchy-install`) gains its own passphrase
  prompt (type-twice-confirm) to satisfy the new contract -- kept as
  the boot fallback / manual-recovery path, not replaced.
- A hand-written GTK4/libadwaita installer app: keyboard/locale,
  timezone, hostname/username, user password, disk selection, LUKS
  passphrase, optional git identity (name/email only, genuinely
  skippable, no GitHub auth), review, progress, done/reboot.
- `cage` (kiosk compositor) auto-starting the app on `tty1` login;
  `tty2`+ stay on plain getty as the escape hatch.
- `GSK_RENDERER` pinned explicitly (Haswell/HD 4600 Vulkan
  blank-window risk, found during Phase 15 planning research).

**Out of scope**
- Calamares or any other pre-built installer framework (researched and
  rejected during planning -- AUR-only on Arch, no UKI support, biggest
  win (`unpackfs`) unusable since this project `pacstrap`s).
- Automated desktop bring-up after install completes (Phase 16).
- Any change to the actual disk/LUKS/Btrfs/pacstrap layout itself --
  `install/install-base-system`'s install logic is unchanged except for
  the passphrase-fd plumbing.

## Decisions

**Resolved**
- GUI approach: `cage` + hand-written GTK4/libadwaita, not Calamares,
  not gum/TUI, not a webview. Full research and rationale in the plan
  mode session (2026-09-18) -- see the implementation log below for a
  summary and DECISIONS.md for the recorded entry.
- LUKS root passphrase: collected in the GUI (and, for the fallback,
  the terminal flow too), passed via file descriptor 3, never fd 0
  (stdin stays free for `confirm_destructive()`'s own typed-disk-path
  safety gate, which is kept for both frontends, not bypassed).
- `install/install-base-system` stays the single source of truth for
  install logic; the GUI and the terminal fallback are both just
  collectors feeding the same contract.

**Open**
- [ ] Exact GTK4 screen-by-screen layout/copy -- designed during
      Milestone B, iterated live in the dev VM, not fully speced up
      front.

## Acceptance tests (written before implementation)

File: `tests/unit/install-base-system.bats`, `tests/unit/
configure-base-system.bats` (extended), plus a new `tests/acceptance/
phase-15.bats` for anything Milestone C's real ISO/boot wiring needs.

| Test | What it proves |
|---|---|
| `install-base-system` reads the LUKS passphrase from fd 3, not stdin/interactively | The passphrase-fd contract is real, not just documented |
| `confirm_destructive()`'s typed-disk-path prompt still reads from stdin correctly with fd 3 also open | fd 3 and fd 0 don't collide |
| Terminal fallback collects and forwards the passphrase via fd 3 | The terminal path satisfies the same contract as the future GUI |
| (Milestone C) `cage`/GTK4 packages present in `iso/profile/packages.x86_64`; `GSK_RENDERER` set in the boot wiring | Static, CI-checkable half of the real hardware verification |

Red confirmed: · Green confirmed:

## Tasks

- [x] Branch, tracking doc
- [ ] Red: passphrase-fd contract tests
- [ ] Milestone A: passphrase-fd plumbing, shared runner extraction,
      terminal fallback passphrase prompt -- zero hardware boots needed
- [ ] Milestone A: Green, `scripts/check`
- [ ] Milestone B: GTK4/libadwaita app against a `--dry-run` fake
      backend, iterated in this dev VM's own Hyprland session
- [ ] Milestone C: `cage` + real boot wiring, `GSK_RENDERER` pinned,
      real ISO build + real hardware boot verification
- [ ] Close: `DECISIONS.md`, `docs/omarchy-influences.md`,
      `docs/roadmap.md`, merge to `main`

## Implementation log

### 2026-09-18
- Plan mode: user pushed back on defaulting to a terminal UI, asking
  why not a real graphical installer (Windows Setup / macOS Setup
  Assistant style). Researched rather than assumed: Calamares (the
  standard real-GUI-installer framework other Arch-based distros use)
  is a poor fit specifically for this project -- AUR-only on Arch (no
  AUR path into `mkarchiso`), its biggest win (`unpackfs`) is unusable
  since this project `pacstrap`s from a baked local repo, zero UKI
  support in its bootloader module (this project's whole boot design
  is UKIs -- EndeavourOS had to fork Calamares itself, branches named
  `luks2`/`partition-fixes`, to make Arch work at all), heaviest
  option measured (+876 MiB) for the least usable logic, and
  philosophically the same shape D-0009 already REJECTed (a config
  wrapper -- YAML instead of Python -- around someone else's
  orchestrator).
- Found a real, right-sized precedent instead: Crystal Linux's
  `jade`/`jade_gui` -- a hand-written Rust backend + GTK4/libadwaita
  Python frontend, ~160 KB total, mostly keymap/locale/timezone lookup
  tables as data, not logic, for an installer that does *more* than
  this project needs (forked and reused as-is by blendOS with a
  different backend, proving the split holds up). Recommended and the
  user approved: `cage` (a 66 KiB wlroots kiosk compositor, already in
  `extra`) + a hand-written GTK4/libadwaita app in the same shape.
  Measured real cost: ISO ~2.7 GB -> ~2.95 GB, ~0.6-0.9 GiB additional
  RAM during install -- not an OOM risk on the Alienware's 8 GB, but a
  real margin worth confirming on Milestone C's real boot rather than
  assuming (this ISO's `copytoram=auto` already pins ~2.6 GiB today,
  before any GUI).
- Found one real, documented landmine during the same research pass:
  GTK4 >=4.16 defaults to a Vulkan renderer (GSK) on Wayland, and the
  Alienware's Haswell/HD 4600 has an incomplete Vulkan driver
  (`hasvk`) with documented blank-window bugs on exactly this GPU
  generation (openSUSE forum report, Ubuntu shipped an `ngl` override
  for the same class of hardware). Must pin `GSK_RENDERER` explicitly
  in Milestone C's boot wiring, not discover this live on a
  destructive real-hardware boot.
- Identified a real, pre-existing gap while designing the hand-off
  contract: `install/install-base-system`'s `cryptsetup luksFormat`/
  `open` calls have never taken a `--key-file` -- they interactively
  prompt on the TTY today, *after* the review-screen confirmation
  already happened, breaking the "fully unattended after confirm"
  promise `autarchy-install`'s own header already claims. Fixed as
  Milestone A, ahead of and independent of the GUI itself: passphrase
  collected once by whichever collector is running, passed to the
  runner via file descriptor 3 (not stdin -- `confirm_destructive()`'s
  own typed-disk-path safety gate still reads fd 0, and stays as a
  second, independent layer for both frontends, not bypassed for the
  GUI).
- Sequenced into three milestones specifically to protect the
  25-40-minute real-hardware test-cycle cost this whole project has
  been paying since Phase 14: Milestone A (passphrase-fd + collector/
  runner split) is fully bats-testable, zero hardware boots. Milestone
  B (the actual GTK4 app) is developed and iterated as a normal window
  inside this dev VM's own existing Hyprland session, against a
  `--dry-run` fake backend that never touches a real disk -- zero
  ISO-build cost per iteration. Only Milestone C (`cage` + real boot
  wiring + the `GSK_RENDERER` question) needs a real ISO build and a
  real destructive hardware boot, same loop as every fix in Phase 14.

## VM → physical hardware notes

- Milestones A and B are fully verifiable in this dev VM (bats tests
  for A; a normal windowed GTK4 app against a dry-run backend for B).
  Milestone C's `GSK_RENDERER`/Vulkan-vs-Haswell question specifically
  cannot be verified in this VM -- its GPU is virtio-gpu, not the real
  target's Intel HD 4600/Haswell path -- so that part is real-hardware-
  only, same as every GPU-adjacent question this project has hit.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/omarchy-influences.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
