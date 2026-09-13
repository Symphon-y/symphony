# Roadmap

Each phase gets its own plan mode and tracking document in [`phases/`](phases/)
(lifecycle defined in [`../CLAUDE.md`](../CLAUDE.md)). Phases beyond the current one are
outlines; their scope is finalized in their own plan mode.

| # | Phase | Layer | Driver | Exit signal | Status |
|---|---|---|---|---|---|
| 0 | [Foundation](phases/phase-00-foundation.md) — repo, docs, standing orders, roadmap | — | Claude (Mac, docs only) | Private GitHub repo with core docs | Complete (2026-09-12) |
| 1 | Environment inspection + base Arch install | 1 | **User** (runbook) | Boots to TTY; user login; network + pacman work; `tests/acceptance/phase-01.bats` passes | Complete (2026-09-13) |
| 2 | Agent handoff + developer bootstrap | 1/5 | User → Claude | Claude Code runs as user in VM; repo cloned; bats/shellcheck/shfmt; deploy mechanism chosen; CI (static + unit) | Not started |
| 3 | Omarchy research | all | Claude | `docs/omarchy-influences.md` classifies components | Not started |
| 4 | Minimal Hyprland session | 2 | Claude | Hyprland login; terminal, audio, portals, polkit agent, notifications, idle/lock, wallpaper | Not started |
| 5 | Interaction | 3 | Claude | Launcher, keybinding scheme, clipboard, screenshots, workspaces/rules, status bar, power menu | Not started |
| 6 | Visual system | 4 | Claude | Single palette source → component themes; fonts, GTK/Qt, icons, cursor, wallpapers | Not started |
| 7 | Developer environment | 5 | Claude | Shell, prompt, Neovim, version manager, containers, git/gh config | Not started |
| 8 | Packages, reproducibility, recovery | cross-cutting | Claude + user | Categorized package inventory; audit script; idempotent bootstrap; fresh-VM rebuild from repo succeeds; backups | Not started |
| 9 | Personal automation | 6 | Claude | Scripts, systemd user services/timers, integrations | Not started |
| 10 | Physical hardware migration | 1–4 | Both | Microcode, GPU drivers, power management, Secure Boot/TPM, hardware package list | Not started |

## Decisions deferred to their phase's plan mode

- **Phase 1:** resolved; see D-0008 to D-0017.
- **Phase 2:** Claude Code install method (AUR vs. npm vs. native installer, under the
  trust model), AUR helper or none, Claude's privilege model, dotfiles deployment
  mechanism (stow / symlink script / chezmoi). Found in Phase 1: how to use Claude Code
  when the VM is reachable only through the Unraid console (no SSH, and noVNC can't
  paste and sometimes drops Shift); where `gh` stores its token without a keyring.
- **Phase 4:** session start (uwsm / greeter / TTY), acceptability of software
  rendering, whether GPU passthrough becomes its own side phase.
  Findings from the Phase 1 VM report: the display device is QXL with no DRM render
  node (compare virtio-gpu), and the VM has no audio device (add a virtual sound card in
  Unraid before testing PipeWire).

## Cross-cutting concerns (checked in every phase)

- Security posture: no unnecessary listening services, no telemetry.
- Secrets stay out of Git.
- Machine-specific config separate from portable config.
- VM → physical hardware notes.
