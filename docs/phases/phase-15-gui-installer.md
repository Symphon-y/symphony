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
- [ ] `GSK_RENDERER` value to pin at boot -- Milestone B's dev-VM
      testing found the renderer name itself has changed between GTK
      versions (`ngl` -> `gl` as of GTK 4.22, discovered live via a GTK
      warning); the actual value needed on the Alienware's GTK version
      is a Milestone C question, verified on real hardware, not decided
      here.

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
- [x] Red: passphrase-fd contract tests
- [x] Milestone A: passphrase-fd plumbing, shared runner extraction,
      terminal fallback passphrase prompt -- zero hardware boots needed
- [x] Milestone A: Green, `scripts/check`
- [x] Milestone B: GTK4/libadwaita app against a `--dry-run` fake
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
- **Milestone A implemented.** Designed and built the fd-9 passphrase
  contract, not fd 3 as planned in plan mode: confirmed live in bats
  that `bats-core` itself holds fds 3, 4, and 5 open internally for its
  own output capture, so `[[ -e /dev/fd/3 ]]` was true even when no
  test provided one -- a real bug caught by actually running the tests,
  not assumed. fd 9 is the standard "app-specific, unlikely to
  collide" choice for exactly this reason; confirmed clear in this
  bats environment before committing to it. `install/
  install-base-system`'s `encrypt_and_format()` reads the passphrase
  from fd 9 **once** into a variable, then pipes it into each
  `cryptsetup --key-file -` call via stdin, rather than pointing
  `--key-file` at `/dev/fd/9` directly -- verified locally (a small
  standalone script first) that a second read from the same fd after
  the first gets EOF, since the file offset is shared once a fd is
  inherited, not reset per process; `cryptsetup` runs twice here
  (format, then open), so this would have silently broken the second
  call. Falls back to today's exact interactive-prompt behavior when
  fd 9 isn't open, keeping `base-install.md`'s documented manual/
  recovery path (calls `install-base-system` directly, no collector at
  all) unaffected. Extracted `install/run-guided-install` (new) from
  `autarchy-install`'s own tail-end (the `install-base-system` call +
  reboot prompt) -- the shared runner both the terminal collector and
  the future GTK4 app will call. `autarchy-install` gains
  `ask_password()` (type-twice-confirm, silent input) and now collects
  the passphrase alongside every other field, passing it via
  `9<<<"$passphrase"` -- the whole terminal flow is genuinely
  unattended after the review screen now too. Verified fd-9
  inheritance survives **two** levels of subprocess calls
  (`autarchy-install` -> `run-guided-install` -> `install-base-system`),
  not just one, with a standalone smoke test before trusting the real
  chain. Updated `tests/acceptance/phase-12.bats`'s `autarchy-install`
  structure test and `base-install.md`'s guided-flow description to
  match. Confirmed Phase 14's dynamic `file_permissions` derivation in
  `profiledef.sh` picks up the new script automatically (32 entries,
  was 31) -- no manual edit needed. `scripts/check` green throughout.
- **Milestone B implemented.** Built `gui/installer/` (an `Adw.
  ApplicationWindow` navigation frame -- `Adw.ToolbarView` + header bar
  + `Gtk.Stack` in an `Adw.Clamp(maximum_size=560)` + Back/Next nav bar
  -- around 8 `Page` subclasses: Welcome, Language & Region (keymap/
  locale/timezone, each an `Adw.ComboRow` with `set_enable_search(True)`
  for type-ahead over ~400 timezones), Account (hostname/username/
  password via `Adw.PasswordEntryRow`), Disk (target disk + optional
  hibernation swap size), Encryption (LUKS passphrase, type-twice-
  confirm), Developer Identity (optional git name/email, genuinely
  skippable), Review (populates from `Answers` in `on_shown`), and
  Progress (streams the runner's output live, then shows Reboot Now/
  Stay at the Shell). `system_info.py` queries the live system for
  every list (keymaps via `localectl`, locales by parsing `/etc/
  locale.gen` in the exact format `configure-base-system` already
  parses, timezones via `timedatectl`, disks by mirroring
  `autarchy-install`'s own `lsblk`/`findmnt` logic) rather than hand-
  maintaining a second data table -- this project's established DRY
  convention. `runner.py` hands off to `install/run-guided-install`
  (real) or `gui/fake-backend` (`--dry-run`) exactly like every other
  collector in this repo, never containing install logic itself.
  Two real bugs found and fixed empirically, both via a minimal
  standalone repro before touching the real code: (1) Python's
  `subprocess.Popen(preexec_fn=...)` alone does not survive --
  `close_fds=True` (the default) runs independently of `preexec_fn` and
  silently closes right back out whatever it `dup2`'d in; fixed by also
  passing `pass_fds=(8, 9)`. (2) GTK widget updates from the background
  I/O thread must go through `GLib.idle_add`, not called directly, or
  they silently corrupt/crash the main loop.
  Verified visually, not just by import: launched the real app as a
  normal window in this dev VM's existing Hyprland session
  (`WAYLAND_DISPLAY=wayland-1`) against `--dry-run`, and used `grim` to
  screenshot every one of the 8 pages (a small throwaway debug harness
  drove `Gtk.Stack` directly, page by page, on a timer, since no input-
  simulation tool -- `wtype`/`ydotool`/`wlrctl` -- turned out to be
  installed on this dev VM). Every page renders correctly and matches
  the "clean macOS Setup Assistant" look the user asked for; the
  Progress page's live log confirmed fd 8/fd 9 actually arrive at the
  fake backend ("fd 8 (user password): received", "fd 9 (LUKS
  passphrase): received"), proving the whole GUI -> runner -> backend fd
  chain works, not just the bash-level chain Milestone A already proved.
  Along the way, hit (and noted, not yet acted on) a real GTK version
  landmine for Milestone C: GTK >=4.16 defaults to a Vulkan (GSK)
  renderer on Wayland, and this dev VM's GTK 4.22 warned live that the
  documented software-fallback renderer name itself changed from `ngl`
  to plain `gl` -- the exact value to pin on the Alienware's real GTK
  version is now an explicit open decision (above), not an assumption.
  Added test coverage for the pure-logic pieces, stdlib `unittest` (no
  `pytest` installed, and stdlib is enough here): `gui/tests/
  test_state.py` (the vars-file contract, including the actual invariant
  that mattered most -- neither password ever appears in it) and `gui/
  tests/test_runner.py` (`_secret_pipe_fd`'s read-once-then-EOF
  behavior, the same property `install-base-system`'s `read -r <&9`
  depends on). `system_info.py` stayed untested by design -- every
  function in it queries live system state (subprocess calls, `/etc/
  locale.gen`), the same "manual/acceptance, not unit tests" bucket this
  project already applies to other live-system code. Wired into
  `scripts/check`: `python3 -m py_compile` over every `gui/*.py` (syntax
  only -- the page modules `import gi` at module level, which needs a
  real GTK install `py_compile` doesn't require) plus `python3 -m
  unittest discover` over `gui/tests`. `gui/fake-backend` (bash) added
  to the existing shellcheck/shfmt file list. `scripts/check` green
  throughout, including the two new steps.

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
