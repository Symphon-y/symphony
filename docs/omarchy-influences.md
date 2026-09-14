# Omarchy Influences

Omarchy is a source of ideas, not a specification. This document records what we
learned from it and what we decided — so autarchy benefits from Omarchy without
becoming Omarchy.

Research is done by reading Omarchy's source and documentation. Omarchy is never
installed on this system.

## Classifications

| Class | Meaning |
|---|---|
| **ADOPT** | We want essentially the same behavior. |
| **ADAPT** | We like the idea but want an independent implementation or different tooling. |
| **REJECT** | We intentionally don't want this behavior or architecture. **Final**, with no "for now". |
| **DEFER** | Interesting, not important enough yet. The only class that is revisited. If we later take the idea, we build it our own way. |

Omarchy itself is never installed. These classifications are about ideas and
implementations only.

## Entry format

```
### <Component>
- Omarchy approach:
- Problem it solves:
- Why it is interesting:
- Coupling to other Omarchy components:
- Better modern alternatives:
- Our decision: ADOPT | ADAPT | REJECT | DEFER
- Our implementation:
- Reason:
- Related decision: D-XXXX
```

## Components to research (Phase 3, and per-phase as each area comes up)

Omarchy's actual approach for each is to be verified from source — nothing below is
assumed.

| Component | Our layer | Phase | Decision |
|---|---|---|---|
| Installer / bootstrap flow | 1 | 1, 8 | REJECT (D-0009) |
| Disk layout, encryption, snapshots, bootloader | 1 | 1 | ADAPT (D-0010–D-0012) |
| Firewall | 1 | 1 | ADAPT (D-0015) |
| Base services | 1 | 1 | ADAPT (D-0014) |
| Claude Code CLI integration | — | 2 | DEFER / REJECT (D-0018) |
| Dotfiles / config deployment | — | 2 | REJECT (D-0020) |
| Login / session start | 2 | 4 | — |
| Hyprland config structure | 2 | 4 | — |
| Audio, portals, polkit | 2 | 4 | — |
| Notifications | 2 | 4 | — |
| Idle management and locking | 2 | 4 | — |
| Wallpaper | 2 | 4, 6 | — |
| Application launcher | 3 | 5 | — |
| Menus (system / power / utility) | 3 | 5 | — |
| Keybinding scheme | 3 | 5 | — |
| Terminal | 3 | 4, 5 | — |
| Clipboard | 3 | 5 | — |
| Screenshots / screen recording | 3 | 5 | — |
| Status bar | 3 | 5 | — |
| Web-app launchers | 3 | 5 | — |
| Theme system and switching | 4 | 6 | — |
| Fonts, GTK/Qt, icons, cursors | 4 | 6 | — |
| Shell and prompt | 5 | 7 | — |
| Neovim distribution | 5 | 7 | — |
| Language / tool version management | 5 | 7 | — |
| Containers | 5 | 7 | — |
| Package selection | all | 8 | — |
| Update and migration mechanism | cross-cutting | 8 | — |

## Entries

Phase 1 entries, researched from source on 2026-09-12 (`omacom/omarchy-iso` and
`basecamp/omarchy` `install/`).

### Installer / bootstrap flow
- Omarchy approach: a custom ISO with a gum TUI configurator (keyboard, account,
  hostname, timezone, disk, encryption) feeding a Python orchestrator built on archinstall.
- Problem it solves: a one-step, low-decision install for newcomers.
- Why it is interesting: careful disk handling (never predicts partition numbers; rolls
  back the partitions it created on failure), and it is tested.
- Coupling to other Omarchy components: high; its own package repo, offline mirror, and
  post-install scripts.
- Better modern alternatives: none needed; the point here is understanding.
- Our decision: **REJECT**
- Our implementation: a manual runbook, plus `install/configure-base-system` for the
  configuration step.
- Reason: we want to understand every step; our install automation (Phase 8) will be our
  own design.
- Related decision: D-0009

### Disk layout, encryption, snapshots, bootloader
- Omarchy approach: GPT with a 2 GiB EFI partition and root; LUKS on by default
  (unencrypted only via Ctrl+C); Btrfs; snapper root config with `NUMBER_LIMIT=5` and
  `TIMELINE_CREATE=no` plus the cleanup timer; Limine installed by Omarchy's own code,
  with `limine-snapper-sync` for bootable snapshots.
- Problem it solves: safe defaults and easy rollback.
- Why it is interesting: encryption by default, and snapshots without timeline noise.
- Coupling to other Omarchy components: Limine integration and the snapshot boot menu.
- Better modern alternatives: systemd-boot with UKIs for Secure Boot and TPM2.
- Our decision: **ADAPT**. We adopt the 2 GiB ESP size, LUKS by default, Btrfs, and
  snapper with the timeline off. We REJECT Limine and `limine-snapper-sync`. The idea of
  bootable snapshots is DEFERred.
- Our implementation: ESP at `/efi`, LUKS2 via `sd-encrypt`, five subvolumes, snapper
  (limit 10) plus snap-pac, systemd-boot with UKIs for `linux` and `linux-lts`.
- Reason: standard systemd primitives, and snap-pac covers the moments that matter
  (pacman transactions).
- Related decisions: D-0010, D-0011, D-0012

### Firewall
- Omarchy approach: ufw denying incoming traffic, plus open LocalSend ports (53317
  tcp/udp), Docker DNS rules, and a `ufw-docker` shim.
- Problem it solves: a closed-by-default machine that still supports Omarchy's bundled tools.
- Why it is interesting: deny-inbound as a default.
- Coupling to other Omarchy components: LocalSend and Docker.
- Better modern alternatives: plain nftables, which ufw wraps.
- Our decision: **ADAPT**. We keep the deny-inbound idea and REJECT the LocalSend and
  Docker rules.
- Our implementation: `system/nftables/nftables.conf`, and a test that allows no
  listeners beyond loopback.
- Reason: standard primitive; any open port is a deliberate, recorded decision.
- Related decision: D-0015

### Base services
- Omarchy approach: enables cups, avahi, docker.socket, systemd-resolved, NetworkManager
  (wait-online masked), power-profiles-daemon, sddm, and systemd-oomd.
- Problem it solves: a desktop where everything works out of the box.
- Why it is interesting: resolved plus NetworkManager; oomd for runaway apps.
- Coupling to other Omarchy components: sddm autologin and the encryption flow; Docker
  tooling.
- Our decision: **ADAPT**. We ADOPT NetworkManager and resolved (with LLMNR and mDNS
  off). We REJECT enabling cups and avahi as base services. We DEFER
  power-profiles-daemon (hardware, Phase 10), and sddm/autologin and oomd (Phase 4).
- Our implementation: `install/configure-base-system` enables NetworkManager, resolved,
  timesyncd, nftables, systemd-boot-update, fstrim.timer, and paccache.timer.
- Reason: no listening services or daemons without a job on this machine.
- Related decision: D-0014

### Claude Code CLI integration
- Omarchy approach: bundles theme sync (matching Claude Code's UI to the desktop
  palette) and a usage-panel widget for its status bar. The Claude *desktop app*
  installer is a separate, optional component from this CLI integration.
- Problem it solves: makes the CLI feel native to Omarchy's desktop.
- Why it is interesting: theme sync is worth having once a palette source exists.
- Coupling to other Omarchy components: Omarchy's palette/theme system and status bar.
- Better modern alternatives: none needed — Claude Code's own settings and hooks cover
  this without extra scripts.
- Our decision: **DEFER** (theme sync, until Phase 6's palette source exists); **REJECT**
  (the desktop app installer — this project runs the CLI only, and any GUI integration
  is a Phase 4/6 decision on its own terms, not something borrowed from Omarchy).
- Our implementation: none yet; Claude Code is installed and run per D-0018, independent
  of any desktop theme.
- Reason: theme sync only makes sense once a palette exists; nothing else here should
  wait for it.
- Related decision: D-0018

### Dotfiles / config deployment
- Omarchy approach: copies/symlinks its own dotfiles from its repo during its one-shot
  install, with no separate manifest and no drift check — the installer is the source of
  truth, run once.
- Problem it solves: gets Omarchy's opinionated config onto disk during install.
- Why it is interesting: nothing beyond "it works for a single install."
- Coupling to other Omarchy components: its installer/bootstrap flow (already REJECT,
  see above).
- Better modern alternatives: GNU stow for symlink management (conflict detection, no
  folding), plus an explicit manifest with a drift check for root-owned files — neither
  of which a one-shot copy needs, since it's never re-applied.
- Our decision: **REJECT**
- Our implementation: `install/link-home` (stow) and `install/sync-system` (manifest-
  checked copy); see D-0020.
- Reason: this repo's config is applied repeatedly — every phase, every re-sync — not
  once at install time, so it needs drift detection Omarchy's approach doesn't have.
- Related decision: D-0020
