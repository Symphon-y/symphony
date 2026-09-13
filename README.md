# autarchy

An individually opinionated Arch Linux workstation.

> Opinionated defaults, individually owned.

autarchy is not a distribution and not an Omarchy installation. It is standard Arch
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
docs/phases/                  one tracking document per phase
```

Component directories (`hypr/`, `waybar/`, `shell/`, `tests/`, …) are created by the
phase that first needs them, not in advance.

## Status

Phase 0 (foundation) complete. Next: Phase 1, environment inspection and base Arch
install. The lab VM is booted into the Arch installer on an Unraid server; nothing is
installed yet. See [`docs/roadmap.md`](docs/roadmap.md).
