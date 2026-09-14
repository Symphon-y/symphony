# Roadmap

Each phase gets its own plan mode and tracking document in [`phases/`](phases/)
(lifecycle defined in [`../CLAUDE.md`](../CLAUDE.md)). Phases beyond the current one are
outlines; their scope is finalized in their own plan mode.

| # | Phase | Layer | Driver | Exit signal | Status |
|---|---|---|---|---|---|
| 0 | [Foundation](phases/phase-00-foundation.md) — repo, docs, standing orders, roadmap | — | Claude (Mac, docs only) | Private GitHub repo with core docs | Complete (2026-09-12) |
| 1 | Environment inspection + base Arch install | 1 | **User** (runbook) | Boots to TTY; user login; network + pacman work; `tests/acceptance/phase-01.bats` passes | Complete (2026-09-13) |
| 2 | [Agent handoff + developer bootstrap](phases/phase-02-agent-handoff.md) | 1/5 | User → Claude | Claude Code runs as user in VM; repo cloned; bats/shellcheck/shfmt; deploy mechanism chosen; CI (static + unit) | Complete (2026-09-14) |
| 3 | [Omarchy research](phases/phase-03-omarchy-research.md) | all | Claude | `docs/omarchy-influences.md` classifies components | Complete (2026-09-14) |
| 4 | [Minimal Hyprland session](phases/phase-04-minimal-hyprland-session.md) | 2 | Claude | Hyprland login; terminal, audio, portals, polkit agent, notifications, idle/lock, wallpaper | Complete (2026-09-14) |
| 5 | Interaction | 3 | Claude | Launcher, keybinding scheme, clipboard, screenshots, workspaces/rules, status bar, power menu | Not started |
| 6 | Visual system | 4 | Claude | Single palette source → component themes; fonts, GTK/Qt, icons, cursor, wallpapers | Not started |
| 7 | Developer environment | 5 | Claude | Shell, prompt, Neovim, version manager, containers, git/gh config | Not started |
| 8 | Packages, reproducibility, recovery | cross-cutting | Claude + user | Categorized package inventory; audit script; idempotent bootstrap; fresh-VM rebuild from repo succeeds; backups | Not started |
| 9 | Personal automation | 6 | Claude | Scripts, systemd user services/timers, integrations | Not started |
| 10 | Physical hardware migration | 1–4 | Both | Microcode, GPU drivers, power management, Secure Boot/TPM, hardware package list | Not started |

## Decisions deferred to their phase's plan mode

- **Phase 1:** resolved; see D-0008 to D-0017.
- **Phase 2:** resolved; see D-0018 to D-0024.
- **Phase 3:** resolved; see D-0025.
- **Phase 4:** resolved; see D-0026 to D-0032. Software rendering was never actually
  needed — the VM ended up on Virtio-GPU(3D) (D-0032) after a detour through full
  PCI passthrough broke Unraid's console. GPU passthrough as its own side phase
  wasn't needed either; revisit only if Phase 5's `gpu-screen-recorder` needs Vulkan.
  The VM's audio-device gap (no virtual sound card in Unraid) is still open — audio
  config landed and is statically verified, but not yet heard.

## Cross-cutting concerns (checked in every phase)

- Security posture: no unnecessary listening services, no telemetry.
- Secrets stay out of Git.
- Machine-specific config separate from portable config.
- VM → physical hardware notes.
