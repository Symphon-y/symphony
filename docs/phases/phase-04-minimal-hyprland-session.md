# Phase 04 — Minimal Hyprland Session

| | |
|---|---|
| **Status** | Planned |
| **Driver** | Claude |
| **Branch** | `phase/04-minimal-hyprland-session` |
| **Started** | — |
| **Completed** | — |

## Goal

Hyprland runs as a logged-into graphical session for the first time: a terminal, audio,
portals, a polkit agent, notifications, idle/lock, and a wallpaper all working.

## Scope

**In scope**
- Packages: `hyprland`, `uwsm`, `sddm`, `ghostty`, `mako`, `hypridle`, `hyprlock`,
  `hyprpaper`, `hyprpolkitagent`, `pipewire`, `wireplumber`,
  `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `matugen` (AUR via yay),
  `yay` itself.
- System config (root-owned, via `install/sync-system`): SDDM's `/etc/sddm.conf.d/*`
  drop-ins. `yay` bootstrap needs care around the no-`sudo`-for-Claude rule (building
  an AUR package needs `sudo pacman -U` at the end) — worked out during
  implementation, likely a user-run step similar to Phase 2's SSH/login steps.
- Home config (via `install/link-home`, one stow package per component): Hyprland
  (Lua `require()`-based, per Phase 3's ADOPT decision), ghostty, mako, hypridle,
  hyprlock, hyprpaper, hyprpolkitagent's autostart, WirePlumber user conf.d snippets
  (alsa-soft-mixer, bluetooth-a2dp-autoconnect — carried over from Phase 3's research),
  and a first matugen config + templates (mako, hyprlock, ghostty) driven by one
  placeholder palette — proving the D-0025 pipeline works, not building the full
  multi-theme switcher (that's Phase 6).
- `tests/acceptance/phase-04.bats`, split like Phase 2's SSH tests: static/config
  checks Claude can run directly, and a live-session group that needs an actual
  logged-in Hyprland session (run by the user, from Unraid's console).

**Out of scope**
- Application launcher, menus, keybinding scheme beyond the bare minimum to open a
  terminal, clipboard, screenshots, status bar, web-app launchers — all Phase 5.
- The full theme system / multiple named themes / a theme-switching command —
  Phase 6. Phase 4's matugen setup is one hardcoded palette, just to prove the render
  pipeline.
- Physical hardware concerns (GPU passthrough as its own phase, laptop power
  management) — Phase 10.

## Decisions

**Resolved (user, 2026-09-14)**
- **VM display:** switch to Virtio-GPU(3D) in Unraid before any graphical testing.
  Research finding: Hyprland treats running in a VM as officially unsupported without
  a real DRM render node, and the VM's QXL display exposes none — it may simply
  refuse to start, and even when software rendering works it's reported as "REALLY
  slow." Switching Unraid's VM template to Graphics Card = Virtual, Video Driver =
  Virtio(3D) is a low-risk, reversible GUI change (needs a VM shutdown) that gives a
  real render node — the only path with genuine upstream support. This is a user
  action (Unraid's GUI, not reachable from inside the VM); **the user is restarting
  the VM with this change before implementation begins.**
- **Session start:** SDDM + uwsm — conventional graphical greeter, autologin into one
  session. Heavier package footprint and an always-on daemon compared to
  greetd+tuigreet, ly, or plain TTY-autologin+uwsm (all researched and compared), but
  the most standard path and what Omarchy itself ships. uwsm has no hard requirement
  on any particular front-end; this was a preference call, not a technical one.
- **Terminal:** ghostty — GPU-accelerated, fastest-growing community momentum,
  actively developed. Chosen over foot (software-rendered by design, Omarchy's
  current default, would work regardless of the VM display fix), alacritty (GPU,
  very mature, lowest RAM among GPU terminals), and kitty (GPU, feature-rich, decent
  software-rendering fallback). Ghostty has no robust software-rendering fallback, so
  this pick depends on the Virtio-GPU(3D) switch actually landing.
- **Wallpaper:** hyprpaper — Hyprland-native, IPC-controlled (live-switch without a
  restart), same ecosystem family as hypridle/hyprlock/hyprpolkitagent. Chosen over
  swaybg (the Phase 3 placeholder pick: simpler, no IPC, kill+respawn to change).
- **Polkit agent:** hyprpolkitagent — Hyprland's own native agent, no legacy GTK2/KDE
  dependency, the idiomatic choice for a bare Hyprland session. Chosen over
  polkit-gnome (older, GTK2, what Omarchy v3 used), polkit-kde-agent, lxqt-policykit,
  and mate-polkit (all researched and compared).
- **AUR helper: yay**, adopted now — resolves the standing "AUR helper or none"
  question generally (flagged but never resolved back in Phase 2), not just for this
  phase. Needed because matugen (D-0025's theming tool) is AUR-only; every other
  Phase 4 package is confirmed in Arch's official `extra` repo (checked directly
  against the Arch package database).

**Resolved (plan)**
- Notifications (mako), idle/lock (hypridle + hyprlock), audio
  (PipeWire/WirePlumber), and portals (xdg-desktop-portal-hyprland + -gtk) were
  already classified ADAPT/ADOPT in Phase 3 (`docs/omarchy-influences.md`) — this
  phase implements those directly, no new decision needed.
- Recorded in `DECISIONS.md` at close-out (likely D-0026 onward): session-start
  mechanism, terminal, wallpaper tool, polkit agent, AUR helper.

**Known testing caveat, not a blocker**
- The VM also has no audio device at all (separate from the display issue). Audio
  gets fully configured and its config statically verified either way; actually
  hearing/routing sound needs a virtual sound card added in Unraid, at the user's
  convenience — same shape as Phase 2's sudo-gated tests (config lands and is checked
  now, live verification happens later).

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-04.bats`, split into two groups:

| Group | What it proves | Who runs it |
|---|---|---|
| static | Packages declared+installed; config files linked with correct content; `Hyprland --verify-config` passes; SDDM enabled; `xdg-terminals.list` defaults to ghostty; matugen renders its templates from the placeholder palette correctly | Claude, no live session needed |
| live-session | Hyprland actually starts through SDDM; a terminal opens (ghostty); a notification renders (mako); idle/lock behaves (hypridle/hyprlock); wallpaper shows (hyprpaper); a polkit prompt appears when needed (hyprpolkitagent) | User, from Unraid's console, after the Virtio-GPU(3D) switch |

Red confirmed: _pending_ · Green confirmed: _pending_

## Tasks

**Prerequisite (user)**
- [ ] Switch the VM's display device to Virtio-GPU(3D) in Unraid and restart the VM

**Implementation (Claude)**
- [ ] Branch, tracking doc (this file)
- [ ] Red: `tests/acceptance/phase-04.bats` (static group) + any new script's unit
      tests; confirm red
- [ ] `packages/desktop.txt` (new category) + declare `yay`
- [ ] Bootstrap `yay` (shape TBD around the no-`sudo`-for-Claude rule)
- [ ] `system/sddm/` drop-ins, added to `system/files.txt`
- [ ] `home/hypr/` (Lua-based, modular)
- [ ] `home/ghostty/`, `home/mako/`, `home/hypridle/`, `home/hyprlock/`,
      `home/hyprpaper/`
- [ ] `home/wireplumber/` conf.d snippets
- [ ] `home/matugen/` config + templates + placeholder palette
- [ ] `xdg-terminals.list` defaulting to ghostty
- [ ] Static acceptance tests green

**Live-session testing (user, from Unraid's console)**
- [ ] Log in through SDDM; confirm Hyprland starts
- [ ] Confirm terminal, notification, idle/lock, wallpaper, polkit prompt all work;
      report back

**Close**
- [ ] `DECISIONS.md`, `docs/omarchy-influences.md` (fill in "Our
      implementation"/"Related decision" for the six components this phase builds),
      `docs/roadmap.md`, VM → hardware notes
- [ ] Merge to `main`

## Implementation log

### 2026-09-14
- Plan researched and approved. Three research passes (Explore agents, WebSearch):
  Hyprland-on-QXL/software-rendering feasibility, session-start mechanism comparison
  (SDDM/greetd/ly/plain-TTY), and polkit-agent + terminal comparisons.
- Key finding: QXL exposes no DRM render node at all; Hyprland-in-a-VM is officially
  unsupported without one. Recommended fix: Unraid Graphics Card = Virtual, Video
  Driver = Virtio(3D) — low-risk, reversible, needs a VM shutdown.
- User decisions locked: Virtio-GPU(3D) switch first; SDDM+uwsm; ghostty; hyprpaper;
  hyprpolkitagent; yay adopted as the general AUR helper.
- **User is restarting the VM with the display-device change before implementation
  begins.** This session ends here; implementation (branch, Red, Green) starts once
  the VM is back up on Virtio-GPU(3D).

## VM → physical hardware notes

- The Virtio-GPU(3D) requirement is VM-specific — real hardware will have an actual
  GPU (or the eventual laptop's integrated graphics) and won't need this substitution.
  Revisit whether any VM-only workarounds (e.g. `cursor:no_hardware_cursors` for
  virtualized GPUs lacking hardware cursor scanout) are still needed once on physical
  hardware.
- Revisit the audio testing caveat once a virtual sound card exists in Unraid, and
  again once on physical hardware with real audio devices.

## Exit criteria

- [ ] Static and live-session acceptance tests both pass
- [ ] `scripts/check` green
- [ ] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
