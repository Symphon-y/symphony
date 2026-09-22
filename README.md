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
  classified ADOPT / ADAPT / REJECT / DEFER in
  [`docs/omarchy-influences.md`](docs/omarchy-influences.md).
- **Every opinion is explicit.** Choices are recorded with their reasoning in
  [`DECISIONS.md`](DECISIONS.md).
- **The desktop is software.** Version controlled, tested, reviewable, recoverable.
- **Every component earns its place.** The test is "does this improve the
  workstation?", not "is this sufficiently minimal?".

How we work — phases, plan modes, tests first, engineering principles — is defined in
[`CLAUDE.md`](CLAUDE.md).

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
DECISIONS.md                  architectural and UX decisions, with reasoning
docs/roadmap.md               phases and current status
docs/omarchy-influences.md    what we took (or didn't) from Omarchy, and why
docs/phases/                  one tracking document per phase (+ test evidence)
docs/runbooks/                reusable procedures (base install, ...)
packages/                     package inventory: one package per line, each with a reason
system/<component>/           root-owned system config; each file names its target path
scripts/                      small single-purpose tools (pkglist, system-report)
tests/unit/                   bats unit tests for scripts
tests/acceptance/             bats tests asserting system state, one file per phase
```

Component directories (`hypr/`, `waybar/`, `shell/`, …) are created by the phase that
first needs them, not in advance.

## Installing and updating

- **Install:** download `symphony-<tag>.iso` from the latest
  [release](https://github.com/Symphon-y/symphony/releases) (reassemble the
  `.part` files if it was split; check the `.sha256`), write it to a USB stick, boot
  it. A graphical installer collects everything once and installs offline;
  the first boot lands on the desktop. Details: `docs/runbooks/base-install.md`.
- **Update:** `symphony-update check`, then `symphony-update apply`. Every release
  ships a signed payload; the machine verifies it before touching anything and
  takes a Btrfs snapshot first. `symphony-update rollback` goes back one.
  Details: `docs/runbooks/update.md`.
- **Own it:** fork, run `scripts/setup-signing` once (your own signing key), change
  `home/`, `system/` and `packages/`, tag -- CI builds your ISO and your signed payload.

## Status

Phases 0-17 complete except Phase 12's hardware bonuses. A release ISO installs the
whole system offline through a GTK4 guided installer (with an optional Wi-Fi step) and
boots into a themed Hyprland desktop with a working network bar; the Alienware 14 it
runs on is now the development seat (`docs/environment/alienware-14.md`). Phase 18
(in progress) adds the signed release payload and `symphony-update`. See
[`docs/roadmap.md`](docs/roadmap.md).
