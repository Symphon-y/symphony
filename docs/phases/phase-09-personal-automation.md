# Phase 09 — Personal automation (standard Arch upkeep)

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude + user |
| **Branch** | `phase/09-personal-automation` |
| **Started** | 2026-09-15 |
| **Completed** | 2026-09-16 |

## Goal

Fill the real, verified gaps between this system and a well-maintained Arch
install's standard upkeep automation: mirror freshness, btrfs scrub, journal
size, AUR build-cache growth, and update visibility (never auto-applying).

## Scope

**In scope**
- `reflector` installed + configured + `reflector.timer` enabled.
- `system/services-root.txt` + `install/enable-root-services` (mirrors Phase
  8's user-service pattern), declaring `reflector.timer`, `btrfs-scrub@-.timer`,
  `pacman-filesdb-refresh.timer`.
- `system/journald/10-autarchy.conf` (`SystemMaxUse=`).
- `home/yay/dot-config/yay/config.json` (`CleanAfter`, exact key verified
  against yay's real config schema).
- `home/update-notify/`: `checkupdates` wired to a desktop notification via a
  `systemd --user` timer, added to `system/services-user.txt`.
- `tests/acceptance/phase-09.bats`, static + one live-session check.

**Out of scope**
- Bespoke personal scripts, media management, third-party integrations.
- Auto-applying updates unattended.
- A periodic `yay -Sc` timer (superseded by `CleanAfter`).

## Decisions

**Resolved (user, 2026-09-15)**
- Phase scope redirected from open-ended "personal automation" to standard
  Arch-idiomatic system upkeep.
- AUR cache: yay's own `CleanAfter` config, not a periodic clean timer.

**Resolved (plan, mechanical)**
- Reflector country: `United States`, inferred from the VM's configured
  timezone (`America/Chicago`).
- Recorded in `DECISIONS.md` at close-out, starting at D-0054.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-09.bats`

| Group | What it proves | Who runs it |
|---|---|---|
| static | Packages installed; configs present with correct content; `systemd-analyze cat-config` shows the journald drop-in merged; root/user services enabled; yay's `CleanAfter` config set | Claude, no live session needed |
| live-session | `update-notify` actually delivers a real desktop notification | User |

Red confirmed: 2026-09-16, 6/8 failing (1 trivial pass -- `enable-user-services
check` has nothing to check yet; 1 correctly skipped -- manual live-session) ·
Green confirmed: 2026-09-16, 7/7 (1 remains a manual live-session skip by
design)

## Tasks

- [x] Branch, tracking doc
- [ ] Red: `tests/acceptance/phase-09.bats`; confirm failing, no load/syntax errors
- [x] `packages/base.txt` addition (`reflector`)
- [x] `system/reflector/reflector.conf` + `system/files.txt` entry -- verified
      the real shipped default format first (Arch Wiki + reflector's own
      source, since GitLab's Anubis anti-bot wall blocked direct fetches)
- [x] `system/journald/10-autarchy.conf` + `system/files.txt` entry
- [x] `system/services-root.txt` + `install/enable-root-services` + unit tests
      (mirrors Phase 8's `enable-user-services` pattern at root scope)
- [x] `home/yay/dot-config/yay/config.json` -- found a real gotcha verifying
      this empirically: yay's `--config` flag is pacman's own config flag, not
      a way to point at yay's *own* JSON settings file, which is only ever
      auto-discovered at `~/.config/yay/config.json`
- [x] `home/update-notify/` (script + user service/timer units), added to
      `system/services-user.txt` -- tested for real against this VM's actual
      13 pending updates: first run produced a genuine mako notification
      (confirmed via `makoctl history`), second run correctly stayed silent
      (verified `checkupdates --change`'s real exit-code/output behavior from
      its own source rather than trusting the man page's prose, which turned
      out to describe it ambiguously)
- [x] Static acceptance tests green for everything not gated on root (4/8);
      `scripts/check` green (95/95 unit tests)
- [x] User: installed packages (via `yay`, after a plain-`pacman` AUR-mismatch
      false start -- same class of slip as prior phases), `sync-system apply`,
      `enable-root-services apply`, confirmed a real mirrorlist refresh
      (`reflector.service` exit 0, `/etc/pacman.d/mirrorlist` regenerated with
      a fresh timestamp, replacing the stale 2026-09-01 install-media
      snapshot) -- caught and fixed a real bug along the way (see log)
- [x] Close: `DECISIONS.md` (D-0054–D-0059), `docs/roadmap.md` (no
      `docs/omarchy-influences.md` entries -- none of this phase's topics were
      ever covered by Omarchy's source, confirmed during research)
- [x] Merge to `main`

## Implementation log

### 2026-09-15
- Plan researched and approved. User redirected Phase 9's open-ended
  "personal automation" scope toward standard Arch-idiomatic system upkeep.
  One research pass confirmed five real gaps against the live system:
  reflector not installed (stale mirrorlist), btrfs-scrub timer shipped but
  disabled, journald unconfigured (relying on a large compiled-in default,
  not an explicit cap), yay's build cache unmanaged (no package-shipped
  cleanup), and `checkupdates` (already installed via pacman-contrib) not
  wired to any notification. Also found `pacman-filesdb-refresh.timer`
  disabled as a related freebie.
- Branch, tracking doc created.
- Mid-phase, the user reported a real, unrelated bug: leaving the VM idle long
  enough causes a hard hang requiring a force-stop from Unraid. Diagnosed via
  two live test attempts with the persistent journal, not guessed -- root
  caused to `hypridle.conf`'s existing suspend listener hitting a guest-suspend
  hang, most likely in this VM's Virtio-GPU(3D)/`virgl` driver's own PM
  callback. Made real progress (a libvirt `&lt;pm&gt;` block fixed one blocker,
  exposing a second, deeper one) but left unresolved by the user's own choice,
  to avoid spending more forced-restart cycles mid-Phase-9. Full detail in
  "VM → physical hardware notes" below. `hypridle.conf` itself was not changed
  -- the config is correct for physical hardware, which is the actual target.
- Built and verified the rest of Phase 9's actual scope: `packages/base.txt`
  (`reflector`), `system/reflector/reflector.conf`, `system/journald/
  10-autarchy.conf`, `system/services-root.txt` + `install/
  enable-root-services` (+ unit tests), `home/yay/dot-config/yay/config.json`,
  `home/update-notify/` (script + user timer/service). Tested `update-notify`
  against this VM's real 13 pending updates end to end: a genuine mako
  notification appeared (`makoctl history` confirmed it), and a second run
  correctly produced no duplicate. `scripts/check` green throughout (95/95
  unit tests); static acceptance tests green except the four steps gated on
  the user's own `sudo` (package install, `sync-system apply`,
  `enable-root-services apply`).
- User ran the sudo-gated steps. First attempt used plain `pacman -S` instead
  of `yay -S` for the package install -- aborted the whole transaction before
  installing anything (including `reflector`) because `packages/desktop.txt`
  deliberately holds AUR-only packages plain pacman can't resolve; same class
  of mistake documented in earlier phases, fixed by re-running with `yay`.
- **Found a real bug testing `reflector.service` for real**: it failed with
  `error: unrecognized arguments: States`. The config's `--country "United
  States"` value has a space, and reflector's config parser (Python's `shlex`)
  splits unquoted words the same way a shell would -- `United States`
  unquoted became two separate tokens, `--country` only consumed `United`,
  leaving `States` as a stray unrecognized argument. Fixed by quoting the
  value (`--country "United States"`); confirmed on the next real run:
  `reflector.service` exited 0 and `/etc/pacman.d/mirrorlist` was regenerated
  fresh (2026-09-16), replacing the stale 2026-09-01 install-media snapshot.
  Full acceptance suite re-run: Phase 9's own 7/7 (real checks) green, no
  regressions anywhere else.

## VM → physical hardware notes

- **Guest suspend (`systemctl suspend`, triggered by `hypridle.conf`'s 10-minute
  listener) hangs this VM and requires a hard stop from Unraid.** Not a Phase 9
  change or finding -- surfaced mid-phase while investigating an unrelated user
  report, logged here since it's squarely a VM-vs-physical-hardware issue.
  `hypridle.conf` itself is correct and unchanged -- the intent (lock, then
  suspend) is right for real hardware; only this VM's ability to actually
  suspend/resume is in question.
  - Diagnosed via the persistent journal across two live test attempts (not
    guessed): the first attempt hung immediately after `systemd-sleep` logged
    `Performing sleep operation 'suspend'...`, before the kernel even logged
    starting the transition. Adding a `<pm><suspend-to-mem enabled='yes'/>
    <suspend-to-disk enabled='no'/></pm>` block to the VM's libvirt XML (it had
    none) made real, measurable progress: the second attempt got a level
    deeper, reaching `kernel: PM: suspend entry (deep)` before hanging again,
    silently, inside the kernel's own per-device suspend sequence.
  - Leading suspect: this VM's Virtio-GPU(3D) + `virgl` display device (D-0032)
    -- virtio-gpu's suspend/resume support has known gaps across QEMU/kernel
    version combinations, and a GPU driver stuck in its own suspend callback
    would explain the silent, total hang (nothing else in the sequence gets to
    run or log after it).
  - **Not resolved.** Further isolation would need kernel boot parameters for
    verbose per-device PM logging, and each test attempt costs a forced VM
    restart -- the user chose to set this aside for now rather than keep
    spending restarts on it mid-Phase-9. Expected to be moot on real hardware
    (Phase 10): no virtio-gpu in the picture there at all. Revisit if it
    matters before then.

## Exit criteria

- [x] Static and live-session acceptance tests both pass
- [x] `scripts/check` green
- [x] `DECISIONS.md`, `docs/roadmap.md` updated
- [x] Branch merged to `main`
