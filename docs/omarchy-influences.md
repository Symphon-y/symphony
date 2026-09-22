# Omarchy Influences

Omarchy is a source of ideas, not a specification. This document records what we
learned from it and what we decided — so symphony benefits from Omarchy without
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
| Installer / bootstrap flow | 1 | 1, 8, 10, 15 | REJECT Omarchy's mechanism; own bootable media built independently (D-0009, D-0061); own GUI, not Omarchy's gum TUI (D-0066) |
| Disk layout, encryption, snapshots, bootloader | 1 | 1 | ADAPT (D-0010–D-0012) |
| Firewall | 1 | 1 | ADAPT (D-0015) |
| Base services | 1 | 1 | ADAPT (D-0014) |
| Claude Code CLI integration | — | 2 | DEFER / REJECT (D-0018) |
| Dotfiles / config deployment | — | 2 | REJECT (D-0020) |
| Desktop shell architecture (bar/notify/launcher/menus/idle-lock/wallpaper/clipboard/polkit, as a whole) | 2, 3 | 3 | REJECT unified shell; ADAPT via matugen (D-0025) |
| Login / session start | 2 | 4 | ADAPT (D-0026) |
| Hyprland config structure | 2 | 4 | ADOPT |
| Audio, portals, polkit | 2 | 4 | ADOPT (audio, portals); ADAPT polkit (D-0029) |
| Notifications | 2 | 4 | ADAPT (D-0025, D-0031) |
| Idle management and locking | 2 | 4 | ADAPT (D-0025, D-0031) |
| Wallpaper | 2 | 4, 6 | ADAPT (D-0025, D-0028) |
| Application launcher | 3 | 5 | ADAPT (D-0025, D-0033) |
| Menus (system / power / utility) | 3 | 5 | ADAPT idea; REJECT plugin engine (D-0025, D-0033) |
| Keybinding scheme | 3 | 5 | ADAPT (D-0033, D-0034, D-0035) |
| Terminal | 3 | 4, 5 | ADAPT (D-0027, D-0030) |
| Clipboard | 3 | 5 | ADAPT (D-0025, D-0031) |
| Screenshots / screen recording | 3 | 5 | ADOPT (D-0036) |
| Status bar | 3 | 5 | ADAPT (D-0025, D-0031) |
| Network and Wi-Fi (stack, installer step, bar indicator) | 1, 3 | 17 | ADOPT NetworkManager + wireless-regdb; ADAPT the optional installer step, regdom, bar icon states, hardware quirks as declarative maps; REJECT the Quickshell panel and the iwd stack (D-0068 to D-0077) |
| Bluetooth | 3 | 17 | DEFER (D-0071) |
| Web-app launchers | 3 | 5 | ADAPT (D-0034) |
| Theme system and switching | 4 | 6 | ADAPT (matugen, wallpaper-driven, D-0025, D-0037) |
| Fonts, GTK/Qt, icons, cursors | 4 | 6 | ADAPT (D-0038–D-0041) |
| Shell and prompt | 5 | 7 | ADAPT (bash, Starship; D-0043, D-0044) |
| Neovim distribution | 5 | 7 | REJECT packaging; personal config used (D-0045) |
| Language / tool version management | 5 | 7 | ADAPT (mise; D-0046) |
| Containers | 5 | 7 | REJECT Docker; rootless Podman (D-0047) |
| Package selection | all | 8 | ADAPT idea; REJECT custom repo/mirror (D-0050) |
| Update and migration mechanism | cross-cutting | 8, 18 | ADAPT migrations (D-0051), snapshot-then-update and a daily availability check (D-0078, D-0079); REJECT channels/mirror and the pacman guard |

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

**Phase 10 addendum (researched 2026-09-16):** revisited when the user asked
for a custom, releasable installer ISO instead of re-running the manual
runbook by hand on new hardware. Fresh research into Omarchy's *own* ISO
tooling (`omacom/omarchy-iso`, not researched in Phase 1) found it depends
on a self-hosted package mirror and custom repo to work around `archiso`'s
real limitation (no AUR during a build) — exactly the "custom repo/mirror"
shape already REJECTed elsewhere in this document (see "Package selection,"
D-0050). That REJECT stands, corroborated rather than reopened. Separately,
re-reading D-0009's own REJECT confirmed it targets Omarchy's specific
mechanism — the gum TUI configurator feeding a Python orchestrator on
`archinstall` — not custom bootable media as a category. A stock-`archiso`
profile of our own, no Omarchy code, no archinstall, no TUI, no custom
mirror, was built independently on that basis: see D-0061. The REJECT verdict
above is unchanged; this addendum records why building our own installer
media doesn't reopen it.

**Phase 15 addendum (researched 2026-09-18):** revisited when the user asked
for a genuinely graphical guided installer — "how Windows/macOS does it
with a real UI" — rather than a nicer terminal prompt. This moves further
from Omarchy's own approach, not closer to it: Omarchy's configurator is a
`gum` TUI feeding a Python orchestrator built on `archinstall`; symphony's
is a hand-written GTK4/libadwaita app (`gui/`), kiosk-launched via `cage`,
still handing off to this project's own `install/install-base-system` — no
`archinstall`, no TUI toolkit, no Omarchy code, same as every prior
addendum here. Evaluated and rejected a real third-party option along the
way (Calamares, the standard "real GUI installer" framework other
Arch-based distros use) for reasons specific to this project, not
Omarchy-related: AUR-only on Arch (no path into this project's `mkarchiso`
build), its biggest win (`unpackfs`, copying a prebuilt image) unusable
since this project `pacstrap`s from a baked-in local repo, and zero UKI
support in its bootloader module. The REJECT verdict above is unchanged;
D-0066 records the GUI design itself.

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

Phase 3 entries, researched from source on 2026-09-14. Omarchy's repo moved from
`basecamp/omarchy` to `omacom/omarchy` (the old name redirects); its default branch is
`quattro`, the current v4.x generation (stable `v4.0.3`, released 2026-09-08). Facts
below are current as of that branch unless a component explicitly discusses v3
("Tre") history for context.

### Desktop shell architecture (bar, notifications, launcher, menus, idle/lock, wallpaper, clipboard, polkit — as a whole)
- Omarchy approach: v3 used eight separate programs (waybar, walker+elephant, mako,
  swayosd, hyprlock, hypridle, swaybg, polkit-gnome), each with its own config format.
  v4 ("Quattro") replaced all of them with one bespoke Quickshell/QML application
  (`shell/shell.qml`, plugins under `shell/plugins/*`) that owns every one of those
  surfaces plus a plugin ecosystem, controlled over IPC (`omarchy-shell ...`).
- Problem it solves: keeping one visual identity and one behavioral model across what
  used to be eight independently-configured programs.
- Why it is interesting: Omarchy's own stated reasons (v4.0.0 release notes) are
  concrete and worth taking seriously — theming consistency (one engine instead of
  eight configs), event-driven updates instead of waybar-style polling (near-zero idle
  CPU), notification/clipboard state surviving a shell restart (which happens on every
  Omarchy update), and a real plugin system with an external ecosystem
  (omarchyplugins.com).
- Coupling to other Omarchy components: total — the shell is the bar, the notification
  daemon, the launcher, the menu system, the idle/lock stack, the wallpaper renderer,
  the clipboard manager, and the polkit agent, all in one process sharing one theme.
- Better modern alternatives: standard, independently-maintained tools for each role
  (waybar, mako, hypridle/hyprlock, swaybg, a standard launcher, cliphist,
  polkit-gnome), unified only at the theming layer by **matugen** — a mature,
  single-binary, no-daemon templating tool (one palette → per-tool templates →
  post-hook reload) already standard in the wider Hyprland community for exactly this
  problem. A middle path also exists and was considered: **Noctalia**, an independent
  (non-Omarchy) Quickshell-based shell.
- Our decision: **REJECT** the unified-shell architecture; **ADAPT** the consistency
  goal via matugen instead.
- Our implementation: see D-0025. Each of the seven components below gets its own
  standard tool (picked in its own Phase 4/5 plan mode) plus a matugen template.
- Reason: of Omarchy's stated motivations, only the consistency problem actually bites
  a single-user system. The performance and plugin-ecosystem wins matter far more at
  Omarchy's multi-user, frequently-updated scale, and the restart-persistence problem
  doesn't exist here in the first place, since nothing forces every desktop component
  to restart together the way updating a monolithic shell does. Building or adopting a
  whole shell also cuts directly against this project's own stated interface-
  segregation and "no custom abstraction over a standard primitive" principles.
- Related decision: D-0025

### Login / session start
- Omarchy approach: SDDM (Wayland greeter) with autologin into one session, launching
  Hyprland through `uwsm` (`install/login/sddm.sh` writes
  `/etc/sddm.conf.d/{10-wayland,autologin}.conf`; the session's `.desktop` runs
  `uwsm start -g -1 -e -D Hyprland hyprland.desktop`). A migration file
  (`migrations/1758487660_change_dm_to_sddm.sh`) shows Omarchy previously used a
  custom seamless-login systemd service plus Plymouth boot-splash trickery instead of a
  greeter, and deliberately moved to SDDM later — evolution from a "fast boot-to-desktop
  hack" to a conventional display manager.
- Problem it solves: getting from power-on to a running Wayland compositor session
  with minimal visible ceremony, while still supporting standard session management
  (logout back to a login screen, multi-user).
- Why it is interesting: `uwsm` is the standard modern way to launch a Wayland
  compositor under systemd (proper scopes/slices, clean shutdown); pairing it with a
  real greeter rather than a bespoke boot-splash trick is the more maintainable choice,
  evidenced by Omarchy's own migration away from the latter.
- Coupling to other Omarchy components: PAM (keyring auto-unlock: Omarchy strips
  `pam_gnome_keyring.so` from `/etc/pam.d/sddm` to avoid conflicting with a
  passwordless default keyring).
- Better modern alternatives: none needed beyond uwsm + a standard greeter; this is
  already close to current best practice.
- Our decision: **ADAPT**
- Our implementation: SDDM configured for Wayland only (`system/sddm/
  10-wayland.conf`, just `DisplayServer=wayland`, no forced default session), the
  `hyprland` package's own shipped `hyprland-uwsm.desktop` picked at the greeter.
  Since Phase 16 the installer also writes `/etc/sddm.conf.d/20-autologin.conf` for
  the created user into that session -- Omarchy's autologin, adopted after all
  (D-0067): LUKS is the gate at boot, and a fresh install must reach the desktop
  with nothing typed. The PAM keyring edit is not needed (no keyring here).
- Reason: `uwsm` is worth adopting regardless of the greeter choice; SDDM won the
  greeter-vs-TTY question on convention and documentation, not a technical
  requirement.
- Related decision: D-0026, D-0067

### Hyprland config structure
- Omarchy approach: config is Lua, not the old `hyprland.conf` DSL. `config/hypr/
  hyprland.lua` is the single entrypoint (`dofile(.../default/hypr/bootstrap.lua)` then
  plain `require()` calls); `default/hypr/bootstrap.lua` layers `package.path` across
  `~/.local/state` (generated), `~/.config` (user overrides), then `$OMARCHY_PATH`
  (shipped defaults). `default/hypr/apps/` (per-app window rules) and `default/hypr/
  toggles/` (runtime feature toggles, backed by state files under `~/.local/state/
  omarchy/toggles/hypr/`) both still exist as directories of small Lua modules.
- Problem it solves: splitting configuration into small, composable files instead of
  one monolith, while keeping shipped defaults separate from user edits.
- Why it is interesting: **this is not an Omarchy invention.** Hyprland itself moved to
  Lua as its native config format starting in 0.55 (current stable 0.56.2); the old
  `hyprlang` `.conf` DSL still loads as a fallback but is officially deprecated
  upstream. Omarchy's "convert all configs to Lua" v4.0.0 changelog entry was tracking
  Hyprland's own migration, not building something bespoke.
- Coupling to other Omarchy components: none beyond Hyprland itself — this is
  independent of the shell-architecture fork above.
- Better modern alternatives: none — Lua's `require()` is now the standard mechanism.
- Our decision: **ADOPT**
- Our implementation: `home/hypr/dot-config/hypr/{hyprland,monitors,input,
  looknfeel,bindings,autostart}.lua`, `hyprland.lua` doing nothing but `require()`
  the rest — written against Hyprland's own real `hl.*` API (fetched from
  `hyprwm/Hyprland`'s official example config directly, not Omarchy's), validated
  with `Hyprland --verify-config`. CLAUDE.md's principle-table wording was updated
  (`source =` → Lua `require()` modules) back in Phase 3.
- Reason: adopting Hyprland's own recommended, actively-maintained config path costs
  nothing and avoids maintaining anything against a deprecated format.
- Related decision: none new — Phase 3's ADOPT call needed no further decision to
  implement, just execution

### Audio, portals, polkit
- Omarchy approach: PipeWire + WirePlumber (standard packages, package-default user
  units, no bespoke systemd wiring), with two WirePlumber conf.d snippets
  (`default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf` forcing
  `api.alsa.soft-mixer=true`; `config/wireplumber/wireplumber.conf.d/
  bluetooth-a2dp-autoconnect.conf` auto-connecting A2DP profiles). Portals:
  `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk`, with a custom screen-share
  picker binary configured in `config/hypr/xdph.conf`
  (`custom_picker_binary = hyprland-preview-share-picker`) — the portal mechanism
  itself is standard; only the picker UI is bespoke. Polkit is genuinely new in v4:
  `shell/plugins/polkit/PolkitAgent.qml` registers the shell itself as the Quickshell
  polkit agent (password + fingerprint/PAM), replacing the old standalone
  `polkit-gnome` process.
- Problem it solves: audio routing, sandboxed portal access (screenshare, file
  choosers) for apps, and authenticating privileged actions.
- Why it is interesting: the ALSA soft-mixer and Bluetooth auto-connect snippets are
  small, genuinely useful WirePlumber tweaks worth copying outright; the custom
  screen-share picker is a nice touch but optional polish.
- Coupling to other Omarchy components: polkit is now coupled to the shell
  architecture (rejected above); audio and portals are not.
- Better modern alternatives: none needed for audio/portals — this is already the
  standard stack. For polkit, a standalone agent (`polkit-gnome`, `polkit-kde-agent`,
  or `lxqt-policykit`) started via `exec-once`, since we're not building a shell to
  host its own.
- Our decision: **ADOPT** (PipeWire/WirePlumber, portals); **ADAPT** (polkit agent)
- Our implementation: `pipewire`+`pipewire-pulse`+`pipewire-alsa`+`wireplumber`,
  `xdg-desktop-portal-hyprland`+`-gtk`; the two WirePlumber conf.d snippets rewritten
  against WirePlumber 0.5's actual current rule syntax (`monitor.alsa.rules`/
  `monitor.bluez.rules`, not the old 0.4 Lua scripts Omarchy's version used) and
  verified by actually starting the service. Polkit: **hyprpolkitagent** (D-0029),
  not one of the four originally compared — found during research as Hyprland's own
  native agent.
- Reason: audio and portals are unaffected by the shell-architecture decision (D-0025)
  either way; polkit needs a standalone replacement now that no shell will host it.
- Related decision: D-0029

### Notifications
- Omarchy approach (v4): mako is gone. The shell is the notification daemon —
  `shell/plugins/notifications/Service.qml` hosts a Quickshell `NotificationServer`
  claiming `org.freedesktop.Notifications` on the session bus; apps notify exactly as
  before over the standard D-Bus interface, the shell just renders the popups (stacked
  top-right; 5s low / 8s normal / persistent critical) instead of a separate daemon.
  Every notification mirrors to `~/.local/state/omarchy/notifications/`, so history (and
  do-not-disturb state) survives a shell restart. `bin/omarchy-notification-send` is the
  mandated sender, calling `Notify` via `busctl --user` with typed parameters rather
  than shelling out to `notify-send`.
- Problem it solves: rendering desktop notifications, with history and a
  do-not-disturb mode.
- Why it is interesting: notifications are still just the standard freedesktop D-Bus
  interface underneath — only the renderer changed. Sending via `busctl --user` with
  typed params instead of raw `notify-send` string interpolation is a good habit
  (avoids argv-injection-style issues) worth keeping regardless of which daemon renders
  them.
- Coupling to other Omarchy components: rendering is coupled to the shell
  architecture (rejected above); the D-Bus interface and the "use a typed sender, not
  raw notify-send" habit are not.
- Better modern alternatives: **mako** — a standard, actively-maintained, config-file
  notification daemon that implements the same `org.freedesktop.Notifications`
  interface, themed via a matugen template instead of shell IPC.
- Our decision: **ADAPT**
- Our implementation: mako, started via its own shipped systemd `--user` service
  (D-0031) rather than an `exec-once` line, config fully generated by a matugen
  template (`home/matugen/.../templates/mako.ini`) — no separate sender script yet;
  Omarchy's `busctl`-over-`notify-send` pattern is worth adopting whenever this
  project sends its own notifications (Phase 9-ish, personal automation), not needed
  for Phase 4.
- Reason: matches D-0025 — the interface apps notify through is unchanged; only the
  renderer needs to be a standard, independently-replaceable program.
- Related decision: D-0025, D-0031

### Idle management and locking
- Omarchy approach (v4): hypridle and hyprlock are gone (confirmed retired by
  `bin/omarchy-upgrade-to-quattro`'s removal list). Idle detection is
  `shell/plugins/services/idle/Service.qml` (Wayland idle-notify via
  `Quickshell.Wayland`); lock-screen rendering and PAM auth are
  `shell/plugins/lock/{LockView.qml,Service.qml}` (`Quickshell.Services.Pam` plus the
  Wayland session-lock protocol directly) — no external lock binary at all. Default
  timeouts: 150s to a screensaver, 300s to lock, configurable in `~/.config/omarchy/
  shell.json`. (v3's hypridle used 150s/152s, with the 152 a workaround for hypridle's
  own timer-reset behavior on a listener firing — a wrinkle specific to hypridle's
  design that a two-listener replacement doesn't need to reproduce.)
- Problem it solves: detecting inactivity and locking the session before sleep, with a
  configurable screensaver step before the actual lock.
- Why it is interesting: absorbing lock-screen rendering directly into a process
  handling Wayland's session-lock protocol removes a moving part (no separate lock
  binary to crash or hang), but that benefit is specific to owning the shell process.
- Coupling to other Omarchy components: entirely coupled to the shell architecture
  (rejected above).
- Better modern alternatives: **hypridle** + **hyprlock** — the standard, separately-
  maintained pair for exactly this (idle detection dispatching to any lock command;
  lock-screen rendering as its own program), themed via matugen templates for each.
- Our decision: **ADAPT**
- Our implementation: hypridle (`home/hypridle/.../hypridle.conf`, plain hyprlang
  syntax — screensaver/lock/suspend listeners) + hyprlock (matugen-templated,
  `home/matugen/.../templates/hyprlock.conf` → `~/.config/hypr/hyprlock.conf`,
  never stow-linked directly). hypridle started via its own shipped systemd
  `--user` service (D-0031).
- Reason: two small, standard, independently-replaceable programs over one shell
  feature, per D-0025.
- Related decision: D-0025, D-0031

### Wallpaper
- Omarchy approach (v4): swaybg is gone (confirmed retired). The shell renders
  wallpaper itself — `shell/plugins/background/Background.qml` reads a symlink
  (`~/.local/state/omarchy/current/background`), detects video files, and composes
  `shell/Ui/BackgroundMedia.qml`/`BackgroundVideo.qml`, pausing video decode when
  locked or in a screensaver to save power. The `omarchy-theme-bg-*` CLI helpers
  (`-set`, `-next`, `-current`, `-cache`, `-install`, `-switcher`) are unchanged in
  spirit: they repoint the symlink and push the change live. Each theme bundles its
  own numbered background images.
- Problem it solves: setting and cycling desktop wallpaper, tied to the active theme.
- Why it is interesting: native video wallpaper support is a genuinely nice feature,
  though it depends on the shell owning wallpaper rendering directly.
- Coupling to other Omarchy components: rendering is coupled to the shell
  architecture (rejected above); the "wallpaper is a per-theme bundled asset, cycled by
  a small CLI script repointing a symlink" idea is not.
- Better modern alternatives: **hyprpaper** (Hyprland-native, IPC-controlled) —
  picked over swaybg once actually deciding, for the same "native ecosystem family"
  reasoning applied to the polkit agent (D-0029); video wallpaper support noted as a
  DEFERrable nice-to-have (e.g. `mpvpaper`) rather than a Phase 4/6 requirement.
- Our decision: **ADAPT**
- Our implementation: hyprpaper (D-0028), pointed at a generated solid-color
  placeholder PNG (`~/.local/share/backgrounds/placeholder.png`) rather than
  Omarchy's symlink-and-cycle-script pattern — that pattern is worth adopting once
  Phase 6 actually has multiple named themes/backgrounds to cycle between; Phase 4
  has exactly one placeholder image, so there's nothing yet to cycle.
- Reason: the reusable idea (theme-bundled backgrounds, symlink + cycle script) doesn't
  need a shell process; static wallpaper covers the common case, and video wallpaper
  can be added later without redesigning anything.
- Related decision: D-0025, D-0028

### Application launcher
- Omarchy approach (v4): Walker and Elephant (the v3 launcher daemon pair) are
  confirmed fully retired — `bin/omarchy-upgrade-to-quattro` explicitly removes
  `omarchy-walker`, `walker-bin`, and every `elephant-*` package. App search is now
  native shell UI (`shell/services/AppLibrary.qml` + `AppSearch.js`, fuzzy-scored,
  matching name/genericName/comment/keywords/acronym), merged into the same command
  palette as the system menu (`SUPER+SPACE`), launching via `uwsm-app -- gtk-launch
  <id>.desktop`.
- Problem it solves: finding and launching an installed application by fuzzy name
  match.
- Why it is interesting: even Omarchy itself moved away from a separate
  launcher-daemon architecture (Walker+Elephant) — worth noting as a data point against
  adopting that specific v3 architecture even if we weren't already rejecting the
  shell-based replacement.
- Coupling to other Omarchy components: current implementation is coupled to the
  shell architecture (rejected above); the underlying need (fuzzy desktop-entry search)
  is not.
- Better modern alternatives: a standard standalone launcher (**wofi**, **fuzzel**, or
  **rofi**) — mature, well-documented, no daemon required, config-file based.
- Our decision: **ADAPT**
- Our implementation: **fuzzel** (D-0033) — matugen-templated, bound to
  `SUPER+SPACE`.
- Reason: fuzzy app search doesn't need a daemon or a shell process; a standard
  launcher does the job with far less to own.
- Related decision: D-0025, D-0033

### Menus (system / power / utility)
- Omarchy approach (v4): `bin/omarchy-menu` is now a thin IPC wrapper
  (`omarchy-shell shell toggle|summon|hide|call omarchy.menu <json>`) — no bash+dmenu
  logic left. Menu content is data-driven JSONC
  (`default/omarchy/omarchy-menu.jsonc`, user-overlaid at
  `~/.config/omarchy/extensions/omarchy-menu.jsonc`), rendered by a QML plugin
  (`shell/plugins/menu/Menu.qml` + `MenuModel.js`) with `when`/`checked`/`disabled`
  bash-evaluated guards and `provider:` submenus (apps, fonts, power-profiles). The
  system/power menu is just one entry in this same menu (`SUPER+ESCAPE` /
  `XF86PowerOff`); other sibling scripts (`omarchy-menu-emoji`, `-select`, `-input`,
  `-timezone`, `-keybindings`, …) either open a dedicated shell panel over IPC or drive
  the same menu plugin's generic `select`/`input` modes via a tempfile handshake — "the
  same plugin doubles as the system's dmenu."
- Problem it solves: a consistent way to present nested choices (system actions,
  power, timezone picker, keybinding search, etc.) without a separate tool per menu.
- Why it is interesting: the JSONC-driven, single-engine-for-every-menu approach is a
  genuinely elegant idea — one plugin instead of N different dmenu-wrapper scripts —
  but it's only elegant because there's already a persistent shell process to host it.
- Coupling to other Omarchy components: entirely coupled to the shell architecture
  (rejected above).
- Better modern alternatives: a small script using a standard launcher's dmenu mode
  (wofi/fuzzel/rofi `--dmenu`), one per menu (system/power, timezone, etc.), following
  the well-worn Hyprland-dotfiles pattern of bash `case` statements over a picker's
  selected line.
- Our decision: **ADAPT** the idea (one small scriptable menu mechanism); **REJECT**
  the JSONC+QML plugin engine (only makes sense inside a shell process).
- Our implementation: `power-menu` — a ~10-line bash script piping a fixed option
  list through `fuzzel --dmenu` and `case`-matching the result (Lock, Logout,
  Suspend, Reboot, Shutdown). Bound to `SUPER+ESCAPE`.
- Reason: the nested-menu *need* is real and worth solving simply; the general-purpose
  plugin *engine* Omarchy built for it is sized for a shell we're not building.
- Related decision: D-0025, D-0033

### Keybinding scheme
- Omarchy approach: modular Lua bindings under `default/hypr/bindings/*.lua`
  (utilities, tiling, media, clipboard, voxtype, applications), assembled by
  `default/hypr/bindings.lua`. Conventions: **SUPER** for window/workspace focus and
  tiling; **SUPER+SHIFT** for move-window/workspace variants and app/webapp launches;
  **SUPER+CTRL** for panel/menu toggles (audio, bluetooth, network, power) and
  system-level toggles (idle, night light, notification silencing); **SUPER+ALT** for
  secondary window actions (float, group ops, resize increments). Every binding is
  labeled (Omarchy's `o.bind(mods, description, action)` shows in a keybindings-search
  surface) rather than a bare, undocumented bind.
- Problem it solves: a consistent, memorable modifier-key convention across dozens of
  bindings, discoverable without reading the config.
- Why it is interesting: the modifier-key convention itself (SUPER = primary,
  +SHIFT/+CTRL/+ALT = distinct secondary categories) is a clean, reusable scheme
  independent of what each binding actually dispatches to; labeling every bind for a
  searchable keybindings view is a good habit worth keeping regardless of which tool
  renders that search.
- Coupling to other Omarchy components: many current dispatch targets are shell
  actions (`omarchy-shell` calls for panels, menus, clipboard) — those specific
  bindings don't transfer, but the modifier convention and the "label every bind" habit
  do.
- Better modern alternatives: none needed — Hyprland's own labeled-bind support
  (`bindd`, or the Lua equivalent per the Hyprland config decision above) already
  provides this.
- Our decision: **ADAPT**
- Our implementation: the modifier convention carried through exactly as recorded
  here — `home/hypr/.../bindings.lua` uses SUPER for launcher/terminal/lock/focus,
  SUPER+SHIFT for window-move, SUPER+CTRL for clipboard/QR-capture, and the PRINT
  family for capture. Every bind still lacks Hyprland's optional description
  string (the "label every bind" habit) — not carried over yet, since nothing
  currently renders a keybindings-search surface to show it in; worth adding once
  something does.
- Reason: a naming convention and a labeling habit are free to adopt; the actual
  dispatch targets depend on tool choices this phase doesn't make.
- Related decision: D-0033, D-0034, D-0035

### Terminal
- Omarchy approach: four terminals supported in parallel with matching config —
  Alacritty, Foot, Ghostty, Kitty (`config/{alacritty,foot,ghostty,kitty}/...`), each
  importing a live theme file rendered per-terminal, all sharing JetBrainsMono Nerd
  Font, matching OSC52 clipboard binds, and an identical CSI-u hack so tmux/TUIs can
  distinguish `Shift+Return` from plain `Return`. The default is set via
  `~/.config/xdg-terminals.list`, resolved at launch time by `xdg-terminal-exec`
  (Foot is the current shipped default, switched from Alacritty in v4 "for better
  resource utilization").
- Problem it solves: letting the user pick a terminal without hardcoding it into every
  keybinding or script that launches one.
- Why it is interesting: `xdg-terminal-exec` + a `.list` file is exactly the standard,
  role-based indirection this project already committed to — CLAUDE.md's own
  Liskov-substitution example is "any terminal behind the terminal role supports
  `-e <cmd>`." Omarchy maintaining four terminals' worth of config in lockstep is the
  part not worth copying.
- Coupling to other Omarchy components: theming (each terminal config imports the
  active theme file) — replaced by a matugen template for whichever one terminal is
  chosen.
- Better modern alternatives: one terminal behind the role, not four in parallel —
  `xdg-terminal-exec` already supports this without any of Omarchy's multi-terminal
  scaffolding.
- Our decision: **ADAPT**
- Our implementation: `xdg-terminal-exec` (genuinely AUR-only, D-0030) +
  `home/terminal/.../xdg-terminals.list` → **ghostty** (D-0027,
  `com.mitchellh.ghostty.desktop` — not `ghostty.desktop`, found the hard way by
  actually running `xdg-terminal-exec --print-id`).
- Reason: matches an already-decided project principle; REJECT only the
  parallel-four-terminals scope, which exists for Omarchy's broad user base, not a
  single machine.
- Related decision: D-0027, D-0030

### Clipboard
- Omarchy approach (v4): clipboard history is a shell panel
  (`shell/plugins/clipboard/Clipboard.qml` + `ClipboardHistory.js`), storing history as
  JSON at `~/.local/state/omarchy/clipboard-history.json` (default limit 500 entries),
  opened via `SUPER+CTRL+V`. **wl-clipboard remains the underlying primitive**
  unchanged — `wl-copy`/`wl-paste` still do the actual clipboard I/O underneath the
  shell panel and the CLI helpers (`omarchy-clipboard-paste-text/-file`).
- Problem it solves: clipboard history (not just current-clipboard passthrough), with
  image preview and sensitive-content exclusion (e.g. Omarchy's QR-capture flow marks
  decoded values sensitive so they skip history).
- Why it is interesting: excluding sensitive captured values from clipboard history by
  design is a good, specific idea worth keeping regardless of which tool renders
  history.
- Coupling to other Omarchy components: the history UI is coupled to the shell
  architecture (rejected above); wl-clipboard itself is not.
- Better modern alternatives: **cliphist** — a standard, actively-maintained clipboard-
  history daemon built directly on wl-clipboard, with its own dmenu-style picker
  integration (pairs naturally with whichever launcher is chosen for menus above).
- Our decision: **ADAPT**
- Our implementation: cliphist + wl-clipboard, started via cliphist's own shipped
  systemd `--user` service (confirmed against its real Arch PKGBUILD, D-0031) —
  `clipboard-menu` script (cliphist's own documented fuzzel-dmenu pattern) bound to
  `SUPER+CTRL+V`. Omarchy's sensitive-content-exclusion idea (QR capture skips
  clipboard history) was **not** carried over: `qr-capture` uses plain `wl-copy`,
  and cliphist's watcher picks up everything that goes through the clipboard the
  same as anything else, so a decoded QR value does end up in history. Worth
  fixing later if it matters in practice (cliphist has no built-in
  sensitivity-marking mechanism to hook, unlike Omarchy's own history store) —
  flagged honestly rather than claimed as done.
- Reason: wl-clipboard was never part of the shell rewrite either way; cliphist gives
  the history feature as an independent, standard program.
- Related decision: D-0025, D-0031

### Screenshots / screen recording
- Omarchy approach: the tool chain is standard and largely unchanged by the v4
  rewrite — **grim** (capture) + **slurp** (region selection, with window/monitor-rect
  snapping via `hyprctl clients -j`) + **hyprpicker** (freeze overlay, also used
  standalone for the color-picker binding) + **satty** (annotation) for screenshots;
  **gpu-screen-recorder** (kms backend by default, portal backend opt-in via
  `OMARCHY_SCREENRECORD_USE_PORTAL=true`) for screen recording, post-processed with
  ffmpeg (trim, loudness normalization). Only the region-picker's keyboard navigation
  (Tab/arrows/Enter to select a window instead of dragging) is shell-side polish
  layered on top of slurp, not a replacement for it. QR-code capture
  (`bin/omarchy-capture-qr`, decode straight to clipboard, marked sensitive so it skips
  clipboard history) and OCR text capture (tesseract) round out the set. Saves to
  `${XDG_PICTURES_DIR}/screenshot-<timestamp>.png` and
  `${XDG_VIDEOS_DIR}/screenrecording-<timestamp>.mp4`.
- Problem it solves: region/window/fullscreen screenshots and recordings without a
  heavyweight screen-capture suite.
- Why it is interesting: this whole chain is already the de facto standard Wayland
  screenshot/recording toolset independent of Omarchy; the QR-capture-to-clipboard
  idea (and marking it sensitive so it skips history) is a small, genuinely useful
  addition worth keeping.
- Coupling to other Omarchy components: minimal — clipboard (via wl-copy) and,
  optionally, notification actions for post-capture editing.
- Better modern alternatives: none — this already is the standard toolchain.
- Our decision: **ADOPT**
- Our implementation: `screenshot` (slurp region into `satty --filename - --output-
  filename ... --copy-command wl-copy` piped straight from grim, one pipeline, no
  intermediate file); `screen-record` (gpu-screen-recorder, toggled via `SIGINT` —
  its own documented stop mechanism); `qr-capture` (slurp+grim+zbarimg, decoded
  value never touches disk); color-pick is a direct `hyprpicker -a` bind, no
  wrapper script. Bound to the PRINT family as already recorded here.
  `gpu-screen-recorder` needs no Vulkan (D-0036, resolving D-0032's deferred
  question) and no interactive `sudo` on the native package (a setuid helper
  handles KMS access; the docs' password-prompt caveat is flatpak-only). OCR
  (tesseract) stayed out of scope, as already decided in Phase 3.
- Reason: unlike the other interaction components, this chain was barely touched by
  the shell rewrite — it's already standard, standalone tools doing one job each.
- Related decision: D-0036

### Status bar
- Omarchy approach (v4): waybar is gone (confirmed retired; `config/waybar` 404s on
  the current branch). The bar is now `shell/plugins/bar/Bar.qml` + `BarModel.js`,
  configured via JSON (the `bar:` key of `~/.config/omarchy/shell.json`: position,
  transparency, and a `layout.{left,center,right}` array of module-id objects), with
  first-party widgets (menu, workspaces, clock, media/MPRIS, tray, weather, network,
  bluetooth, power, etc.) plus a real plugin registry
  (`shell/services/BarWidgetRegistry.qml`) supporting both `type: "command"` modules
  (waybar-JSON-compatible stdout — a deliberate compatibility bridge) and `type: "qml"`
  custom modules, installable as third-party plugins.
- Problem it solves: a persistent status/control surface (workspaces, clock, tray,
  system indicators) always visible on screen.
- Why it is interesting: Omarchy's bar plugin format explicitly stays
  waybar-JSON-compatible for `"command"`-type modules — a tacit admission that
  waybar's simple JSON-module protocol is worth keeping compatible with, even inside a
  totally different engine.
- Coupling to other Omarchy components: rendering is coupled to the shell
  architecture (rejected above); the JSON-module protocol note is not.
- Better modern alternatives: **waybar** — the standard, actively-maintained,
  JSON+CSS-configured status bar, themed via a matugen template instead of shell IPC.
- Our decision: **ADAPT**
- Our implementation: waybar, hybrid-themed (the community-standard
  `InioX/matugen-themes` pattern: static `config.jsonc`/`style.css`, a
  matugen-generated `colors.css` `@import`-ed at the top, reloaded live via
  `pkill -SIGUSR2 waybar`) — not fully templated like mako/hyprlock/ghostty/fuzzel,
  since CSS's own `@import` does the color/structure split naturally. Minimal
  module set: `hyprland/workspaces`, `clock`, `wireplumber`, `network`, `tray` — no
  cpu/memory/battery on a desktop VM. Started via its own shipped systemd `--user`
  service, found only after being missed entirely at first (D-0031's addendum).
- Reason: matches D-0025; waybar remains popular and well-documented enough that even
  Omarchy's replacement kept a compatibility bridge for it.
- Related decision: D-0025, D-0031

### Web-app launchers
- Omarchy approach: `bin/omarchy-webapp-install` generates a `~/.local/share/
  applications/<name>.desktop` file (auto-fetching a favicon), and
  `bin/omarchy-launch-webapp` resolves the user's actual default browser
  (`xdg-settings get default-web-browser`) and execs it with the Chromium-family
  `--app=<url>` flag (falling back to `chromium.desktop` for non-Chromium browsers,
  since Firefox-family browsers have no equivalent app-mode flag). Unchanged by the v4
  shell rewrite — confirmed still present and working the same way, now wrapped in
  `setsid uwsm-app --`.
- Problem it solves: launching a website as a borderless, dock/launcher-visible
  pseudo-app, without any PWA manifest or service-worker involvement.
- Why it is interesting: it's conceptually simple — a generated `.desktop` file plus a
  browser flag — and entirely independent of the shell-architecture question, since it
  never touched Walker/Elephant or the bar.
- Coupling to other Omarchy components: the app launcher (the generated `.desktop`
  file needs to be discoverable by whichever launcher we choose) and the default
  browser being Chromium-family (a genuine limitation, not an Omarchy choice).
- Better modern alternatives: none needed — this is already about as simple as the
  mechanism gets.
- Our decision: **ADAPT**
- Our implementation: `webapp-install <url> <name>` (generates the `.desktop` file
  and best-effort favicon) + `webapp-launch <url>` (resolves the current default
  browser at launch time, not baked in at install time — so it stays correct if
  the default browser ever changes) (D-0034).
- Reason: small, self-contained, and unaffected by every other decision in this
  document; the only open question was whether it's a feature we actually want.
- Related decision: D-0034

### Theme system and switching
- Omarchy approach: each theme is a directory (`themes/<name>/`) with `colors.toml` as
  the single source-of-truth palette (24 semantic colors as of v4, expanded from 8 in
  v3 "so btop/nvim/vscode themes can be autogenerated"), plus bundled backgrounds,
  icon theme name, and per-app config fragments. Switching
  (`bin/omarchy-theme-set <name>`) stages a theme directory, renders `.tpl` template
  files (`{{ background }}`-style placeholders with `_strip`/`_rgb` format modifiers)
  against `colors.toml`, atomically swaps it into `~/.config/omarchy/current/theme`,
  then pushes the result live via IPC into the running shell and runs a fixed list of
  per-app setter scripts (`omarchy-theme-set-{gnome,foot,tmux,vscode,browser,...}`).
  Notably: themes installed from git have every executable file type (`.lua`, terminal
  configs, `vscode.json`) stripped before staging, because "installing someone's theme
  should change what your desktop looks like, never what it runs."
- Problem it solves: one palette definition propagating consistently to every themed
  app, without hand-editing N config files per theme change.
- Why it is interesting: the placeholder-template-rendering mechanism
  (`{{ key }}` → real value, with automatic format conversion) is exactly the same
  approach **matugen** takes, independently arrived at; the untrusted-theme
  code-execution guard is a genuinely good security idea worth carrying into however
  imported palettes get handled.
- Coupling to other Omarchy components: the *live-push* half (IPC into the running
  shell) is coupled to the shell architecture (rejected above); the *template
  rendering* half is not — it's just files on disk.
- Better modern alternatives: **matugen** does the same template-rendering job as a
  standalone, actively-maintained tool, with a real templating engine (conditionals,
  loops, filters, automatic hex/rgb/hsl conversion) rather than Omarchy's own
  sed-based renderer, and a community template repository already covering mako,
  waybar, hyprlock, and more.
- Our decision: **ADAPT**
- Our implementation: matugen; but the source-of-truth is the current wallpaper
  itself (`matugen image <path>`), not a saved palette file or a `themes/<name>/`
  library the way Omarchy's `colors.toml`-per-theme is. `wallpaper-set`/
  `wallpaper-random` (`home/hyprpaper/dot-local/bin/`) repoint hyprpaper live and
  re-render every template (mako, hyprlock, ghostty, fuzzel, waybar, GTK3/GTK4) in
  one step; GTK gets no post-hook since neither GTK3 nor libadwaita live-reload
  their stylesheet (read once at process start). Omarchy's untrusted-theme
  code-execution guard doesn't apply here at all -- there's no theme-directory
  import path, just an image file.
- Reason: Omarchy's own theme system needs a *library* of named themes because it
  ships several and lets users install more from git; this system has exactly one
  "theme" at a time -- whatever's on screen -- so the wallpaper itself is a simpler,
  sufficient single source of truth. See D-0025, D-0037.
- Related decision: D-0025, D-0037

### Fonts, GTK/Qt, icons, cursors
- Omarchy approach: default font **JetBrainsMono Nerd Font** (switched to the lighter
  "basic" variant in v4 to save ~200MB); font switching
  (`bin/omarchy-font-set`) rewrites each terminal's config and writes a canonical
  fontconfig override at `~/.config/fontconfig/fonts.conf`, called "the canonical
  source of truth" for the shell and Qt apps. GTK/Qt unification: `QT_QPA_PLATFORMTHEME
  =gtk3` forces Qt apps to read GTK's theme, and theme-switching sets
  `org.gnome.desktop.interface gtk-theme`/`icon-theme` via gsettings. Icon theme
  family is **Yaru**; no dedicated cursor package is shipped — only
  `XCURSOR_SIZE`/`HYPRCURSOR_SIZE` are set, relying on the Hyprland/GTK default cursor.
- Problem it solves: one visual font/icon/widget-theme identity across GTK and Qt
  apps, which otherwise theme completely independently.
- Why it is interesting: `QT_QPA_PLATFORMTHEME=gtk3` is a small, well-known, standard
  trick (not Omarchy-specific) that solves the GTK/Qt split cheaply; a fontconfig
  override as "the" source of truth for monospace is a clean pattern.
- Coupling to other Omarchy components: theme switching (gsettings calls run as part
  of `omarchy-theme-set`) — reimplemented as one more matugen post-hook / small script,
  not shell-coupled.
- Better modern alternatives: none needed — these are already standard mechanisms.
- Our decision: **ADAPT**
- Our implementation: the fontconfig-override pattern (`home/fonts/.../fonts.conf`,
  aliasing `monospace` to JetBrainsMono Nerd Font) and `QT_QPA_PLATFORMTHEME=gtk3`
  adopted as-is. Font: JetBrainsMono Nerd Font (matches Omarchy's own default).
  Icon theme: Papirus-Dark (diverges from Omarchy's Yaru, which is AUR-only on
  Arch with narrower repo support). Cursor: Bibata-Modern-Classic, XCursor format
  (no native hyprcursor port exists for the specific AUR package used, confirmed
  against the real release assets -- `HYPRCURSOR_THEME` left unset, Hyprland falls
  back to `XCURSOR_THEME` automatically). GTK/Qt colors: two new matugen templates
  (`gtk3.css`, `gtk4.css`) rendering each toolkit's own named-color set live from
  the wallpaper-derived palette, going further than Omarchy's own gsettings-based
  theme-set step -- accepting libadwaita's narrower CSS override surface and
  restart-to-reload limitation as a known tradeoff.
- Reason: the mechanism was free to take in Phase 3; the specific visual choices
  are matters of taste, made with the user in Phase 6. Going further than Omarchy's
  gsettings-only approach for GTK/Qt colors keeps this system's "one palette drives
  everything" promise consistent across every themed component, not just some.
- Related decision: D-0038, D-0039, D-0040, D-0041

### Network and Wi-Fi (stack, installer step, bar indicator)
- Omarchy approach: (Read from its current `quattro` source, 2026-09-20.) The
  installed system runs NetworkManager plus `wireless-regdb`; iwd, `impala` and
  systemd-networkd were dropped because enterprise, VPN, hidden and
  captive-portal networks were the pain (its issue tracker: #1414, #2909). It
  masks `NetworkManager-wait-online`, turns Wi-Fi power-save off through a
  `conf.d` drop-in, and sets the regulatory domain at install by appending the
  country for the timezone to `/etc/conf.d/wireless-regdom` (deliberately not
  `iw reg set`, since the install ends in a reboot). Its ISO has **no** Wi-Fi
  step (install is offline; Wi-Fi is set up after first boot); its older
  configurator scanned and joined with `iwctl` and carried the iwd credentials
  over through archinstall. The bar network widget is a Quickshell panel (not
  Waybar) with signal icons, connect / password / forget / radio toggle, and a
  hotkey; a first-run notification appears if there is no link. It also ships
  per-hardware quirk scripts and a "restart Wi-Fi" recovery action.
- Problem it solves: getting a laptop online, with a visible, clickable status.
- Why it is interesting: the NetworkManager choice and its reasons, the
  regulatory-domain-from-timezone idea, the masked wait-online, and the shape
  of the icon states are all sound and directly reusable as ideas.
- Coupling to other Omarchy components: the panel is part of its Quickshell
  shell, which is what D-0025 rejects; the legacy TUIs (`impala`, `bluetui`)
  hang off its floating-terminal launcher.
- Better modern alternatives: Waybar's own `network` module with states and
  click actions; `networkmanager-dmenu` (fuzzel is supported natively) and
  `nm-connection-editor` for the interactive parts.
- Our decision: **ADOPT** NetworkManager and `wireless-regdb` (agrees with
  D-0014) and masking `NetworkManager-wait-online`. **ADAPT** the optional
  Wi-Fi step at install (own GTK page, carrying the live connection to the
  target as a plain connection file, D-0068/D-0069), the regulatory domain from
  the timezone (through the package's own file, D-0072), and the bar's icon
  states, click action and hotkey (`SUPER+CTRL+N`, D-0071). **REJECT** the
  Quickshell panel (D-0025) and the iwd/`impala`/systemd-networkd stack.
  **ADAPT** its per-hardware quirk scripts as two declarative maps and two
  selectors instead: `system/hardware.txt` (PCI ID -> extra packages, D-0074) and
  `system/quirks.txt` (DMI -> kernel parameter, D-0076), consulted by the installer,
  no per-machine scripts. **DEFER** a first-run "set up Wi-Fi" notification (the
  bar already shows the state), a "restart Wi-Fi" recovery action for
  `network-menu`, and automatic captive-portal handling (connectivity check off,
  D-0070).
- Our implementation: NetworkManager on the live ISO and the installed system;
  `gui/installer/wifi.py` and the Wi-Fi page; `copy_network_profiles` and
  `configure_regdom` in `install/configure-base-system`; Waybar's `network` and
  `battery` modules; `network-menu` (through `network-picker`, D-0077, and
  `network-watch`, D-0075).
- Reason: keeps everything Omarchy learned the hard way about the stack while
  staying with small standard tools rather than a bespoke shell, and without an
  iwd credential format to maintain alongside NetworkManager's.
- Related decision: D-0068 to D-0077

### Bluetooth
- Omarchy approach: a Waybar `bluetooth` module (icons for off, on, connected)
  whose click launches `bluetui` in a floating terminal (its later Quickshell
  panel replaces it).
- Problem it solves: pairing and switching headphones, mice and keyboards.
- Why it is interesting: a real, common laptop need.
- Coupling to other Omarchy components: the floating-terminal launcher and its
  window rules.
- Better modern alternatives: `bluez` with `bluetuith`/`bluetui`, or a
  fuzzel-driven menu over `bluetoothctl`.
- Our decision: **DEFER**.
- Our implementation: none yet; the bar has no Bluetooth module.
- Reason: it needs `bluez` and a running daemon, which cuts against "no
  unnecessary daemons", plus a UI choice of its own; it is not part of getting a
  laptop online. Built our own way when taken up, not with Omarchy's packages.
- Related decision: D-0071

### Shell and prompt
- Omarchy approach: **bash** as the login/interactive shell (`default/bashrc` sources
  `default/bash/{env-bootstrap,rc,envs,aliases,functions,init,inputrc}`, with an
  explicit comment warning users not to edit the shipped files directly). Prompt is
  **Starship**, deliberately minimal (`manual/40-prompt.md` calls it out as a design
  choice): `format = "[$directory$git_branch$git_status]($style)$character"`.
- Problem it solves: a fast, portable, low-ceremony interactive shell and prompt.
- Why it is interesting: choosing bash over zsh/fish, and a deliberately minimal
  Starship config over a heavily-decorated one, is a legible, low-maintenance default
  worth weighing against fish's or zsh's usability wins.
- Coupling to other Omarchy components: none significant.
- Better modern alternatives: n/a — this is a taste decision, not a technical one.
- Our decision: **ADAPT**
- Our implementation: bash (D-0043) + Starship (D-0044), Omarchy's own deliberately
  minimal prompt format adapted near-verbatim (directory + git branch + git status,
  nothing else). None of Omarchy's `bash/{envs,aliases,functions,init}` structure
  was carried over wholesale -- `home/bash/dot-bashrc` is a single small file with
  history settings, `eza`/`zoxide`/`fzf`/`bat` aliases, and the starship/mise/zoxide
  activation lines, deliberately without Omarchy's `herdr`-specific functions,
  AI-tool single-letter aliases, or worktree/ssh-reconnect helpers -- none of which
  apply here, though the ssh-reconnect wrapper and worktree functions are worth
  remembering as reference material if a concrete need for either ever comes up.
- Reason: bash won the subjective shell question on zero-friction/already-the-
  default grounds; Starship's minimalism was worth keeping as-is since it's a
  taste choice already well-suited to a single-user machine, not something to
  re-litigate from scratch.
- Related decision: D-0043, D-0044

### Neovim distribution
- Omarchy approach: a separate pacman package, `omarchy-nvim`, built on **LazyVim**.
  Each theme ships a `neovim.lua` colorscheme file so switching the system theme also
  changes Neovim's colors — a community-reported downside (`omacom/omarchy#1803`) is
  that this couples theme-switching to LazyVim specifically, limiting use of a custom
  Neovim config.
- Problem it solves: a batteries-included Neovim setup out of the box.
- Why it is interesting: LazyVim is a solid, popular starting point; the
  theme-coupling issue is a genuine pitfall worth avoiding if we theme Neovim at all —
  don't bake theme-switching assumptions about a specific distribution's internals.
- Coupling to other Omarchy components: theme switching (the pitfall above);
  otherwise self-contained.
- Better modern alternatives: n/a — LazyVim itself is already a reasonable modern
  choice; repackaging it as our own pacman package is the unnecessary part.
- Our decision: **REJECT** building or packaging any curated Neovim distribution at
  all, LazyVim-based or otherwise.
- Our implementation: the user's own long-maintained personal config
  (`github.com/Symphon-y/config.nvim`) is cloned directly to `~/.config/nvim` (plain
  HTTPS `git clone`, no auth needed for this public repo) and tracked only in
  `packages/external.md` -- not a `home/nvim/` stow package, not vendored,
  independently updatable from its own repo (D-0045).
- Reason: confirmed via source read that `omarchy-nvim` is genuinely thin (~400
  lines of custom Lua over stock `LazyVim/starter`) -- so the "curate a small
  layer over a solid starting point" idea was sound, but moot once the user
  clarified they already have their own such layer and specifically didn't want it
  coupled to this repo. This also sidesteps Omarchy's own confirmed pitfall for
  free: its theme hot-reload structurally requires LazyVim's plugin-spec shape
  (`omacom/omarchy#1803`, raised, never fixed upstream) -- not a risk here at all,
  since this project never adopts that mechanism.
- Related decision: D-0045

### Language / tool version management
- Omarchy approach: **mise** (`mise-bin` package) as the single tool for per-project
  language runtime versions, described as "like rbenv/rvm/virtualenv but for multiple
  languages." Omarchy also builds lazy-install CLI wrapper stubs on top of it
  (`bin/omarchy-mise-install <package> [command] [bin]` writes a `~/.local/bin/
  <command>` shim that runs `mise use -g --quiet <package>` then `exec mise x
  <package> -- <bin> "$@"` on first invocation) — used for tools like the Cloudflare
  CLI and, per the v4 changelog, Claude Code and GitHub CLI (switched from npm to
  mise specifically to avoid npm's release-cooldown lag).
- Problem it solves: one version manager instead of asdf/rbenv/nvm/pyenv sprawl, plus
  lazy first-run installs for occasionally-used CLIs.
- Why it is interesting: mise genuinely consolidates what used to be N
  language-specific version managers into one tool with one config format; the
  lazy-install-wrapper pattern is a nice trick for tools that are wanted but not
  worth installing eagerly.
- Coupling to other Omarchy components: the specific lazy-install targets (Claude
  Code, gh) are Omarchy's own choices, not mise's.
- Better modern alternatives: none needed — mise is already the modern consolidated
  choice here.
- Our decision: **ADAPT** the tool; **DEFER** the lazy-install-wrapper mechanism.
- Our implementation: mise, installed and activated in `home/bash/dot-bashrc`
  (D-0046). Omarchy's `omarchy-mise-install` wrapper-generator pattern is a
  genuinely good, reusable idea, but its actual tool roster (Claude Code, gh,
  codex, crush, `hey`/`basecamp`, and a dozen other AI-CLI/Basecamp-specific tools)
  isn't transferable, and there's no concrete tool on this machine to wrap yet --
  building the wrapper infrastructure now would be unused machinery.
- Reason: the tool itself is a strong, low-risk pick, confirmed still current in
  Omarchy's own `quattro` branch; the wrapper pattern is worth remembering and easy
  to add the day a real occasionally-used tool needs it, not worth building
  speculatively.
- Related decision: D-0046

### Containers
- Omarchy approach: Docker installed and enabled by default, but **the install user is
  deliberately not added to the `docker` group** — `install/config/docker.sh`
  documents this outright: the docker group "is equivalent to passwordless root."
  Plain CLI use requires `sudo docker ...`; an explicit opt-in script
  (`omarchy-setup-security-sudoless-docker`) adds the group later "after a warning."
- Problem it solves: making containers available without silently handing out a
  root-equivalent group membership by default.
- Why it is interesting: this is the exact same privilege-model reasoning already
  recorded in this project's own D-0016 (no `NOPASSWD`, no silent privilege
  escalation) — Omarchy independently arrived at the same principle for Docker
  specifically.
- Coupling to other Omarchy components: none significant.
- Better modern alternatives: **Podman** is a rootless-by-default alternative worth
  weighing in Phase 8 against Docker-without-the-group; not resolved here.
- Our decision: **ADOPT** the underlying privilege-model goal; **REJECT** Docker
  and its docker-group-guardrail mechanism; resolved with **rootless Podman**
  instead, in this phase rather than deferred to Phase 8.
- Our implementation: `podman` + `podman-compose` + `podman-docker` (D-0047).
  Confirmed on this VM that `travis` already has subuid/subgid ranges allocated
  from Arch's default `useradd` behavior, so rootless containers need zero extra
  privilege setup at all -- no group to gate, no guardrail script needed.
- Reason: Omarchy's own no-docker-group stance already matches this project's
  D-0016 privilege-escalation policy, but it's still gating a root-equivalent
  daemon after the fact via sudo/polkit. Rootless Podman solves the same problem
  structurally instead -- and Omarchy's own maintainers are independently reaching
  the same conclusion (an open, unmerged PR, `omacom/omarchy#11032`, found during
  research, is actively migrating their own default from Docker to rootless
  Podman). Given a concrete, well-researched answer was already in hand, resolving
  it in Phase 7 rather than deferring to Phase 8 made more sense than leaving a
  known-answer question open.
- Related decision: D-0016, D-0047

### Package selection
- Omarchy approach: two static, flat, uncommented manifests
  (`install/omarchy-base.packages`, `install/omarchy-other.packages`, the latter
  documented only by inline comments like "Vulkan drivers") drive the ISO/base
  install. Beyond that base set, packages are added interactively — `omarchy-pkg-
  install` and `omarchy-pkg-aur-install` open an `fzf` picker directly over `pacman
  -Slq`/`yay -Slqa` and install live against the real repo databases. Optional feature
  bundles (gaming, AI tools, browsers) are separate `omarchy-install-*` scripts run
  from the menu.
- Problem it solves: a repeatable base package set for the ISO, plus a fast way to
  browse and install more.
- Why it is interesting: **this project's own D-0017 (Phase 1) already went further**
  than Omarchy's approach — categorized files with a reason per package
  (`packages/<category>.txt`), one parser (`scripts/pkglist`), and an acceptance test
  that fails if any explicitly-installed package isn't declared. Omarchy's fzf-picker
  installs are, by contrast, invisible to its own package manifests once installed —
  exactly the drift D-0017's test prevents here.
- Coupling to other Omarchy components: Omarchy's own custom package repository and
  Arch mirror (`omacom-io/omarchy-pkgs`, `omacom-io/omarchy-mirror`), built to serve
  those manifests and the ISO.
- Better modern alternatives: our existing `packages/<category>.txt` +
  `scripts/pkglist` design (D-0017) is already the better version of this idea.
- Our decision: **ADAPT** the categorized-list idea (already done, D-0017); **REJECT**
  the custom package repo/mirror and the untracked-interactive-install pattern
- Our implementation: D-0017's categorized lists needed one more thing to stay
  accurate over time: `scripts/pkg-audit` (D-0050), a standalone script checking
  drift in both directions (installed-but-undeclared, declared-but-not-present)
  plus that every foreign/AUR package is declared specifically in
  `packages/desktop.txt`. Found three real drift items on its first real run
  (Phase 8) — proof the categorized-list idea needed an actual auditor, not
  just the acceptance-test spot-checks it had before.
- Reason: operating a custom pacman repository and mirror is unjustified overhead for
  a single machine, and an install path that bypasses the declared-package manifest is
  exactly the drift D-0017 was built to prevent.
- Related decision: D-0017, D-0050

### Update and migration mechanism
- Omarchy approach: ships itself as pacman packages from a custom repo/mirror, with
  four update channels (stable/RC/edge/dev) and a pacman guard
  (`omarchy-update-pacman-guard`) that blocks a direct `pacman -Syu`/`yay -Syu`,
  redirecting to `omarchy update`. Migrations are one timestamped shell script per
  change (`migrations/<unix-timestamp>.sh`, 100+ files), run in order by
  `bin/omarchy-migrate`, which skips any migration whose completion marker already
  exists under `~/.local/state/omarchy/migrations/`. Updates also take a Btrfs/snapper
  snapshot beforehand, so a bad update can be rolled back from the bootloader menu.
- Problem it solves: applying incremental changes to an already-installed system
  exactly once each, in order, safely resumable if interrupted.
- Why it is interesting: the timestamped-script + completion-marker pattern is a
  simple, robust, directly reusable idempotency mechanism — exactly the kind of thing
  Phase 8's "idempotent bootstrap" goal needs, and notably it's also how we already
  found out about the v3→v4 rewrite (`bin/omarchy-upgrade-to-quattro` is itself one
  such migration). The guard-against-direct-pacman idea is a deliberate, opinionated
  safety net worth weighing on its own.
- Coupling to other Omarchy components: the channel system and pacman guard are
  coupled to Omarchy's custom repo/mirror infrastructure; the migration-script pattern
  itself is not — it's just scripts and marker files.
- Better modern alternatives: our own `install/sync-system` (D-0017/D-0020) already
  provides declarative drift-checking for system files; a timestamped-migration layer
  would sit alongside it for one-time changes that aren't just "make this file match,"
  the way `omarchy-migrate` complements Omarchy's own package-based file deployment.
- Our decision: **ADAPT** the migration-script + completion-marker pattern, the
  snapshot-then-update shape, and the daily "update available" check; **REJECT**
  the custom repo/mirror/channel infrastructure and the pacman guard
- Our implementation: `migrations/<unix-timestamp>-<slug>.sh` + `scripts/migrate
  check|apply` (D-0051), completion markers under
  `~/.local/state/symphony/migrations/`. Shipped with one real first migration
  (removing an unintended `yay-debug` package `scripts/pkg-audit` found), not an
  empty directory — a migration needing root calls `sudo` itself, and the user
  runs `apply`, never Claude. The pacman-guard idea was not adopted at all —
  no direct-`pacman`-blocking mechanism exists or is planned. Since Phase 18 the
  OS content itself updates through `symphony-update` (D-0078/D-0079): a signed
  payload tarball on a GitHub Release -- not a package from a repo -- verified
  with minisign, snapshotted, swapped in at the same path, then the appliers and
  migrations; `update-notify` toasts a new release daily (D-0059).
- Reason: the channel/mirror infrastructure solves a distribution-scale problem (many
  machines pulling from one feed) this project doesn't have; the migration pattern
  solves a real problem (one-time changes, applied exactly once, resumable) that Phase
  8 explicitly needed an answer for.
- Related decision: D-0017, D-0051, D-0078, D-0079
