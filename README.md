# symphony

An individually opinionated Arch Linux workstation.

> Opinionated defaults, individually owned.

symphony is not a distribution and not an Omarchy installation. It is standard Arch
Linux plus a deliberate, documented system design — with the polish of a curated
desktop and the transparency of a personally maintained Arch install.

The target feeling:

> Someone already made all the annoying decisions. That someone is me.

## Principles

- **Arch is the foundation.** Native packages, upstream config, standard systemd
  primitives. No derivative distro, no opaque wrappers.
- **Omarchy is a source of ideas, not a specification.** Every borrowed idea is
  classified ADOPT / ADAPT / REJECT / DEFER in the decision that acts on it.
- **Every opinion is explicit.** Choices are recorded with their reasoning in
  [`DECISIONS.md`](DECISIONS.md).
- **The desktop is software.** Version controlled, tested, reviewable, recoverable.
- **Every component earns its place.** The test is "does this improve the
  workstation?", not "is this sufficiently minimal?".

How we work — phases, plan modes, tests first, engineering principles — is defined in
[`CLAUDE.md`](CLAUDE.md). Open work is tracked in
[issues](https://github.com/Symphon-y/symphony/issues), a phase per
[milestone](https://github.com/Symphon-y/symphony/milestones).

## Layers

| Layer | Scope |
|---|---|
| 1 — Operating system | Arch, systemd, filesystem, bootloader, networking, users, security, hardware support |
| 2 — Graphics / desktop | Wayland, Hyprland, portals, input, audio, notifications, idle, lock, wallpaper |
| 3 — Interaction | Launcher, terminal, clipboard, screenshots, workspaces, window rules, keybindings, menus, power |
| 4 — Visual system | Fonts, GTK/Qt, icons, cursors, terminal/compositor/app themes, wallpapers |
| 5 — Developer environment | Git, gh, Neovim, shell, version managers, containers, tooling |
| 6 — Personal automation | Scripts, systemd user services/timers, integrations |

## Repository map

```
CLAUDE.md                     working agreement: standing orders + engineering principles
DECISIONS.md                  every architectural and UX decision, with its reasoning
docs/environment/             ground truth about the machines this runs on
home/<component>/             GNU stow packages linked into the home directory
install/                      the installer and the appliers an installed machine re-runs
iso/                          archiso profile, offline repo, ISO build
migrations/                   one-time fixes for machines installed earlier
packages/                     package inventory: one package per line, each with a reason
system/<component>/           root-owned system config; each file names its target path
scripts/                      small single-purpose tools (pkglist, hwmatch, system-report)
tests/unit/                   bats unit tests for scripts
tests/acceptance/             bats tests asserting system state, one file per phase
```

Component directories (`hypr/`, `waybar/`, `shell/`, …) are created by the phase that
first needs them, not in advance.

## Installing and updating

- **Install:** download `symphony-<tag>.iso` from the latest
  [release](https://github.com/Symphon-y/symphony/releases) and write it to a USB
  stick. The ISO is over GitHub's 2 GiB per-file limit, so it arrives as numbered
  parts — join them in order and check the digest before writing:

  ```sh
  cat symphony-<tag>.iso.*.part > symphony-<tag>.iso
  sha256sum -c symphony-<tag>.iso.sha256
  ```

  On Windows, join them with `Get-Content -Raw`, then `iso/write-usb.ps1` checks the
  digest, writes the stick and reads it back to compare. A graphical
  installer collects everything once and installs offline; the first
  boot lands on the themed desktop with nothing left to type. Boot the ISO with
  `symphony.nogui` for a terminal instead, where `symphony-install` asks the same
  questions; Wi-Fi is optional either way (`nmtui` joins one, and the profile carries
  over to the installed system).
- **Update:** `symphony-update check`, then `symphony-update apply`. Every release
  ships a signed payload; the machine verifies it against `/etc/symphony/release.pub`
  before touching anything and takes a Btrfs snapshot first. `symphony-update rollback`
  goes back one. On a machine that also has the repo checked out,
  `symphony-update apply --from <checkout>` deploys the working tree instead of a
  release.
- **Own it:** fork, run `scripts/setup-signing` once (your own signing key), change
  `home/`, `system/` and `packages/`, tag -- CI builds your ISO and your signed payload.

## Status

Phases 0-19 complete. A release ISO installs the whole system offline through a GTK4
guided installer (with an optional Wi-Fi step) and boots into a themed Hyprland desktop
with a working network bar. Releases are signed payloads applied by `symphony-update`
with a snapshot and a rollback. Hardware support is one map (`system/hardware.txt`)
applied by `symphony-hardware`, which also names hardware nothing handles yet. The
Alienware 14 it runs on is the development seat
([`docs/environment/alienware-14.md`](docs/environment/alienware-14.md)) and is never
reinstalled, so fresh-install proofs need a second machine.

What is still open is in [issues](https://github.com/Symphon-y/symphony/issues).
