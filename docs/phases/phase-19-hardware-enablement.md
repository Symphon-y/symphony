# Phase 19 — Hardware detection and enablement: sound, and AlienFX as the bonus

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/19-hardware-enablement` |
| **Started** | 2026-09-22 |
| **Completed** | |

## Goal

The OS knows what hardware it is on and enables it without the user hunting for drivers:
one declarative map keyed by hardware identity, applied at install, first login, update
and on demand by `symphony-hardware`, plus a scan that names what is still unhandled.
Sound works on the Alienware (it does not today), `power-profiles-daemon` runs, and the
AlienFX lighting takes the theme colour -- as a bonus, taken only if the userspace tool
drives this laptop's controller.

## Scope

**In scope**
- `system/hardware.txt` grows from `pci` keys to `pci`/`usb`/`dmi`/`hda`, and from
  packages only to `packages=`, `cmdline=`, `modprobe=`, `files=`, `service=`;
  `system/quirks.txt` folds in. One parser, `scripts/hwmatch`; `hwpkglist` and
  `quirkparams` become wrappers (callers unchanged).
- `symphony-hardware check|apply|scan` (new stow package `home/hardware/`), called by
  `configure-base-system`, `first-login`, `symphony-update apply`, and by hand.
- Sound: the global `api.alsa.soft-mixer` rule removed (an ASUS quirk misapplied to
  every machine, D-0083), `alsa-utils` and `rtkit` shipped, a migration for installed
  machines.
- `power-profiles-daemon` (Phase 12's open task) installed and enabled.
- AlienFX via the AUR `alienfx` tool over the USB HID controller `187c:0525`, a udev
  rule, `alienfx-theme` pushing the palette's primary colour at login and on wallpaper
  change -- if the spike shows the controller responds.
- `iso/build-offline-repo` builds AUR packages listed under `packages/hardware/`.
- Docs: D-0082 to D-0084, an influences entry for hardware quirks, `alienware-14.md`,
  `docs/runbooks/hardware.md`, Phase 12's tasks.

**Out of scope**
- A network driver search -- Arch has no driver database; the kernel's modalias
  autoloading and `linux-firmware` are the mechanism, and `scan` names the gaps.
- Volume, brightness or power-profile controls in the bar (deferred, D-0071).
- Hibernation verification and `nouveau` (stay on Phase 12).
- OpenRGB (does not support this controller's PID).

## Decisions

**Resolved** (user-confirmed 2026-09-22)
- Sound: drop the global soft-mixer rule, ship `alsa-utils` (+ `rtkit`); PipeWire manages
  the hardware mixer. Spike first; the fallback is an `hda:` codec quirk from evidence.
- AlienFX: the kernel's `alienware-wmi` does not cover this firmware (no WMI GUID in
  common); userspace tool over HID, theme colour only, no OpenRGB; stop if it does not work.
- Mechanism: extend the maps (data), one command, plus a generic scan; Omarchy's
  per-vendor scripts are the shape not to copy (D-0074 stands).
- `power-profiles-daemon` folded in from Phase 12.
- Spikes before code.

**Where each piece of knowledge lives (DRY)**

| Knowledge | Single home |
|---|---|
| What hardware needs what | `system/hardware.txt` (one grammar, four key kinds) |
| Matching a line to this machine | `scripts/hwmatch` (fake sysfs/procfs in tests) |
| What to do about a match | `symphony-hardware apply`, one function per value kind |
| The theme's primary colour | the matugen render (one template writes it for consumers) |

## Acceptance tests (written before implementation)

Files: `tests/unit/hwmatch.bats`, `tests/unit/symphony-hardware.bats`,
`tests/unit/alienfx-theme.bats`, `tests/unit/migration-soft-mixer.bats`,
`tests/acceptance/phase-19.bats`; `hwpkglist.bats`, `quirkparams.bats`,
`configure-base-system.bats`, `first-login.bats`, `symphony-update.bats`,
`build-offline-repo` coverage updated.

| Test | What it proves |
|---|---|
| `hwmatch`: each key kind matches against fake sysfs/procfs; each value kind is printed per match; malformed line or unknown list fails closed; the old `hwpkglist`/`quirkparams` cases pass through the wrappers | One parser, nothing regresses |
| `symphony-hardware check` names matches and pending actions; `apply` installs packages, copies modprobe/files, enables user/system units, sudo only where needed, second run does nothing; `scan` names an unbound device by modalias, a firmware failure, a fully muted HDA card; never installs | The mechanism does what the map says and no more |
| no `51-alsa-soft-mixer.conf`; migration removes the rendered link and WirePlumber's route state, idempotent | Sound fix reaches installed machines |
| `alsa-utils`, `rtkit`, `power-profiles-daemon` declared; `power-profiles-daemon.service` in `services-root.txt` | Shipped, enabled |
| `alienfx-theme`: reads the colour, sets each zone, silent without the device | Bonus wiring |
| `build-offline-repo` builds an AUR package from `packages/hardware/` | The ISO carries it |
| acceptance: grammar, wiring into installer/first-login/updater, udev `uaccess`, decisions | Holds together |

Red confirmed: | Green confirmed: |

## Tasks

- [x] Branch, tracking doc, roadmap row
- [ ] Spike A (sound): soft-mixer off -> hardware pins unmute, tone audible
- [ ] Spike B (AlienFX): `alienfx` from the AUR drives `187c:0525`
- [ ] Red tests
- [ ] `scripts/hwmatch`, new `hardware.txt` grammar, `quirks.txt` folded, wrappers
- [ ] `symphony-hardware`; wired into installer, first-login, updater
- [ ] Sound: rule removed, packages, migration; deployed and verified
- [ ] `power-profiles-daemon`
- [ ] AlienFX: package list, udev, `alienfx-theme`, wallpaper hook, unit; verified
- [ ] `build-offline-repo` builds hardware AUR entries
- [ ] Docs, decisions, influences, `alienware-14.md`, Phase 12 tasks, runbook, roadmap, merge, release

## Implementation log

### 2026-09-22
- Plan mode, from the machine. Sound diagnosed before planning: driver bound
  (`snd_hda_codec_alc662`, Realtek ALC3661, subsystem `1028:05a9`), PipeWire sink up at
  40 %, all three output pins muted in hardware (`Amp-Out vals [0x80 0x80]`). Our Phase 6
  `api.alsa.soft-mixer = true` rule applies to every card and stops PipeWire touching the
  hardware mixer; Omarchy applies the same rule only to ASUS ROG and ships `alsa-utils`.
  `alsa-utils` and `rtkit` are absent here.
- AlienFX: `alienware-wmi`'s WMI GUIDs are not in this firmware's list and its DMI table
  has no "Alienware 14"; the lighting is USB HID `187c:0525` ("Alienware M14x",
  `/dev/hidraw0`). AUR `alienfx` has `controller_m14xr3.py` for that PID (same zone codes
  as the verified R2 minus the alien head) marked "needs the correct zone codes".
  OpenRGB supports only the Dell G-series PIDs.
- Omarchy's hardware layer read (`bin/omarchy-apply-hardware`, `install/hardware/*.sh`,
  `install/user/hardware/<vendor>/*.sh`): per-vendor shell scripts run at ISO
  finalisation and on demand. The "apply on demand, rerunnable" idea is taken; the
  scripts-per-quirk shape is not (D-0074).

## VM → physical hardware notes

- Everything here is verified on the Alienware: the codec pins, the HID controller, the
  power profiles. A machine without the hardware must get nothing -- the unit tests
  assert it, and `pkg-audit` on the dev seat proves the AUR package is a hardware entry,
  not a global one.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/omarchy-influences.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
