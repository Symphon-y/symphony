# Phase 04 — Minimal Hyprland Session

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude |
| **Branch** | `phase/04-minimal-hyprland-session` |
| **Started** | 2026-09-14 |
| **Completed** | — |

## Goal

Hyprland runs as a logged-into graphical session for the first time: a terminal, audio,
portals, a polkit agent, notifications, idle/lock, and a wallpaper all working.

## Scope

**In scope**
- Packages: `hyprland`, `uwsm`, `sddm`, `ghostty`, `mako`, `hypridle`, `hyprlock`,
  `hyprpaper`, `hyprpolkitagent`, `pipewire`, `pipewire-pulse`, `pipewire-alsa`,
  `wireplumber`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `matugen`,
  `vulkan-intel` — all confirmed in Arch's official `extra` repo directly against this
  VM's pacman database (correcting the plan's original research, which wrongly claimed
  matugen was AUR-only). Plus `xdg-terminal-exec` — genuinely AUR-only this time
  (confirmed both against the live pacman database and the AUR PKGBUILD directly),
  and it's the mechanism CLAUDE.md itself already names for the `$terminal` role, so
  **yay is adopted after all** (see Decisions).
- System config (root-owned, via `install/sync-system`): SDDM's `/etc/sddm.conf.d/*`
  drop-ins.
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
- **AUR helper: yay, adopted — resolved twice in one session.** First pass: the
  plan's original research claimed matugen (D-0025's theming tool) was AUR-only,
  which was wrong — checked directly against this VM's live pacman database, matugen
  is in the official `extra` repo (v4.2.0-1, packaged by an Arch Trusted User), same
  as every other package researched so far. With that justification gone, the user
  initially deferred "AUR helper or none" again. Second pass: implementation then hit
  a genuine AUR-only need — `xdg-terminal-exec`, the exact mechanism CLAUDE.md already
  names for the `$terminal` role, confirmed AUR-only both against the live pacman
  database and its AUR PKGBUILD directly (no ambiguity this time). The user chose to
  adopt yay after all rather than vendor the script by hand or one-off `makepkg`.
  yay itself has to be bootstrapped manually (`git clone` + `makepkg -si`, needs
  `sudo` for the final `pacman -U`) — a user-run step, like Phase 2's SSH/login
  steps. Both packages tracked in `packages/external.md`.

**Resolved (plan)**
- Notifications (mako), idle/lock (hypridle + hyprlock), audio
  (PipeWire/WirePlumber), and portals (xdg-desktop-portal-hyprland + -gtk) were
  already classified ADAPT/ADOPT in Phase 3 (`docs/omarchy-influences.md`) — this
  phase implements those directly, no new decision needed.
- Recorded in `DECISIONS.md` at close-out (likely D-0026 onward): session-start
  mechanism, terminal, wallpaper tool, polkit agent.

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
- [x] Switch the VM's display device in Unraid and restart the VM — user did GPU
      passthrough (real Intel UHD Graphics 770, Raptor Lake-S GT1) rather than the
      virtio-gpu-3D fallback the plan suggested, with some hiccups troubleshooted
      along the way. Verified: `lspci` shows the Intel VGA controller bound to `i915`
      (modules `i915`, `xe`); `/dev/dri/renderD128` exists, group `render`. This is a
      real DRM render node, better fidelity to eventual physical hardware than
      virtio-gpu-3D would have been.

**Implementation (Claude)**
- [ ] Branch, tracking doc (this file)
- [ ] Red: `tests/acceptance/phase-04.bats` (static group) + any new script's unit
      tests; confirm red
- [ ] `packages/desktop.txt` (new category), `packages/tooling.txt` (+yay),
      `packages/external.md` (+yay, +xdg-terminal-exec)
- [ ] User bootstraps `yay` (`git clone` + `makepkg -si`, needs `sudo`), then
      `yay -S xdg-terminal-exec`
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
  hyprpolkitagent; yay adopted as the general AUR helper (later corrected — see below).
- **User is restarting the VM with the display-device change before implementation
  begins.** This session ends here; implementation (branch, Red, Green) starts once
  the VM is back up on Virtio-GPU(3D).
- **VM back up.** User did real GPU passthrough (Intel UHD Graphics 770) rather than
  virtio-gpu-3D, after some troubleshooting. Confirmed via `lspci`/`/dev/dri`: a real
  `i915`/`xe`-driven render node exists. Implementation starts now.
- **Research correction:** checked the actual Phase 4 package list directly against
  this VM's live pacman database (`pacman -Si`) before writing anything, rather than
  trusting the plan's WebSearch-derived claim. Every package, including matugen, is in
  the official `extra` repo — the "matugen is AUR-only" research from planning was
  wrong. Told the user immediately rather than quietly installing yay for no reason;
  **user decision: defer the AUR-helper question again**, since nothing in this phase
  needs one. Added `vulkan-intel` to the package list (not in the original plan) once
  real Intel GPU passthrough was confirmed, for a proper Vulkan driver alongside
  mesa's OpenGL/EGL support. Also added `pipewire-pulse`/`pipewire-alsa` (app
  compatibility for anything not PipeWire-native), not called out individually in the
  plan's audio bullet.
- **Second AUR check, this one real:** `xdg-terminal-exec` — the exact tool CLAUDE.md
  already names for the `$terminal` role — turned out to be genuinely AUR-only,
  confirmed against both the live pacman database (`pacman -Ss` found nothing) and
  its AUR PKGBUILD (`gitlab.freedesktop.org/Vladimir-csp/xdg-terminal-exec`, a
  ~1500-line POSIX script, `make install`, no compiled deps). Presented the user three
  options (vendor it like `install/claude-code`, adopt yay, one-off `makepkg`);
  **user decision: adopt yay after all**. `yay` and `xdg-terminal-exec` both recorded
  in `packages/external.md`; `yay` declared in `packages/tooling.txt`,
  `xdg-terminal-exec` in `packages/desktop.txt`.

## VM → physical hardware notes

- Superseded by events: the user did real GPU passthrough (Intel UHD Graphics 770,
  `i915`/`xe`) instead of the planned virtio-gpu-3D fallback, so this VM now runs
  against real Intel graphics rather than a virtualized display device. Workarounds
  that exist specifically for virtualized GPUs without hardware cursor scanout
  (`cursor:no_hardware_cursors`) likely aren't needed here — confirm during
  implementation rather than assuming either way, and note whether Hyprland needs it
  regardless once tested. If the eventual physical workstation uses different (e.g.
  discrete NVIDIA/AMD) graphics, driver packages will need revisiting then; if it's
  also Intel, this VM's config should carry over close to as-is.
- Revisit the audio testing caveat once a virtual sound card exists in Unraid, and
  again once on physical hardware with real audio devices.

## Exit criteria

- [ ] Static and live-session acceptance tests both pass
- [ ] `scripts/check` green
- [ ] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
