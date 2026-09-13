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
| Installer / bootstrap flow | 1 | 1, 8 | — |
| Disk layout, encryption, snapshots, bootloader | 1 | 1 | — |
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

_None yet — populated from Phase 3 onward._
