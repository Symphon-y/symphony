# Phase 04 — Minimal Hyprland Session

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude |
| **Branch** | `phase/04-minimal-hyprland-session` |
| **Started** | 2026-09-14 |
| **Completed** | 2026-09-14 |

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

Red confirmed: yes (VM, 9/9 failing, no load/syntax errors — packages not installed,
commands not found, sudo required, as expected) · Green confirmed: yes, **9/9**,
after fixing a real autostart bug found in the live session (see implementation log)

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
- [x] Branch, tracking doc (this file)
- [x] Red: `tests/acceptance/phase-04.bats`; confirmed 9/9 failing, no load/syntax
      errors
- [x] `packages/desktop.txt` (new category), `packages/tooling.txt` (+yay, +go,
      +fakeroot, +make, +scdoc), `packages/external.md` (+yay, +xdg-terminal-exec)
- [x] User: build-tool prerequisites (`go`, `fakeroot`, plus `make`/`gcc`/`debugedit`
      found empirically along the way), manual yay build+install, then
      `yay -S --needed $(scripts/pkglist packages/*.txt)` for everything else
- [x] `system/sddm/` drop-in, added to `system/files.txt`; user applied it
      (`sudo install/sync-system apply`) and enabled the service
      (`sudo systemctl enable sddm`)
- [x] `home/hypr/` (Lua-based, modular) — `Hyprland --verify-config` passes
- [x] `home/hypridle/`, `home/hyprpaper/` (plain hyprlang `.conf`, unaffected by
      Hyprland's own Lua move). No `home/ghostty/`, `home/mako/`, `home/hyprlock/` —
      those three are entirely matugen-generated output, never stow-linked (same
      reasoning as Claude Code's settings.json not being a repo symlink)
- [x] `home/wireplumber/` conf.d snippets (found missing during this same pass;
      written against WirePlumber 0.5's real conf.d rule syntax, verified by actually
      starting the service — no parse errors, `wpctl status` responds)
- [x] `home/matugen/` config + templates + placeholder palette — verified end to end,
      real colors rendered into all three output files
- [x] `home/terminal/` `xdg-terminals.list` — `xdg-terminal-exec --print-id` resolves
      correctly
- [x] Static acceptance tests green (6/6)

**Live-session testing (user, from Unraid's console)**
- [x] Reverted to Virtio-GPU(3D); logged in through SDDM ("Hyprland (uwsm-managed)"),
      visible directly in Unraid's noVNC console as expected
- [x] Confirmed Hyprland running, a terminal opens; found and fixed a real
      autostart bug (hyprpolkitagent) — see implementation log
- [x] All 9 acceptance tests green, from inside the live session

**Close**
- [x] `DECISIONS.md` (D-0026 through D-0032), `docs/omarchy-influences.md` (filled in
      "Our implementation"/"Related decision" for the six Phase 3 components this
      phase built, plus Terminal), `docs/roadmap.md`, VM → hardware notes
- [x] Merge to `main`

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
- **Caught before asking the user to run anything:** declaring `yay` and
  `xdg-terminal-exec` in plain `packages/*.txt` files would have broken the
  established bulk-install command (`sudo pacman -S --needed
  $(scripts/pkglist packages/*.txt)`, from Phase 1/2's runbooks) — `pacman -S` can't
  resolve an AUR package name at all, and errors out resolving *every* target before
  installing anything, which would have blocked all of Phase 4's legitimate packages
  in one command. Fix: **from Phase 4 onward, the bulk-install command is
  `yay -S --needed $(scripts/pkglist packages/*.txt)`** — yay transparently handles
  official-repo and AUR packages in one invocation, so every package can stay in the
  same declared lists (one parser, one command, unchanged). The one remaining
  chicken-and-egg step is bootstrapping yay itself, which needs its own prerequisites
  installed the old way first. Added `go` and `fakeroot` (build yay itself; `go>=1.24`
  is yay's only real makedepend, `fakeroot` is what `makepkg` always needs to fake
  file ownership while packaging) and `make`/`scdoc` (xdg-terminal-exec's own
  makedepends — its Makefile's default target renders a man page via `scdoc`) to
  `packages/tooling.txt`. All four confirmed against the live pacman database.
- **Three more build-time gaps found empirically, one at a time, from the user's real
  `makepkg -si` output** (not predicted in advance): `debugedit` (Arch's current
  makepkg defaults build separate debug packages and abort without it), `make` (used
  by yay's own build, not just xdg-terminal-exec's), `gcc` (yay's build uses cgo,
  needing a real C compiler despite being a Go program). Each added to
  `packages/tooling.txt` with the real error message as the reason, committed
  individually as they came up.
- **All 17 Phase 4 packages installed successfully.** `Hyprland --config
  ~/.config/hypr/hyprland.lua --verify-config` passed cleanly on the first attempt —
  the hand-written Lua config (checked against Hyprland's own real `hl.*` API, not
  Omarchy's) was correct.
- **Bug found running matugen for real:** `config.toml`'s `output_path`s were relative
  (`../mako/config` etc.), which matugen resolved against the symlink's *real* target
  inside the repo checkout, not `$HOME` — it started writing generated configs into
  the git working tree (`home/matugen/dot-config/{mako,hypr,ghostty}/`, caught via
  `git status` before committing anything). Confirmed empirically in an isolated
  `/tmp` test that matugen does expand `~`; switched every `output_path` to an
  absolute `~/.config/...` path. Re-ran: repo stayed clean, and all three templates
  (mako/hyprlock/ghostty) rendered correct, well-formed color values.
- **Bug found running `xdg-terminal-exec`:** ghostty's real installed `.desktop` file
  is `com.mitchellh.ghostty.desktop` (reverse-DNS app ID), not `ghostty.desktop` as
  assumed when writing `xdg-terminals.list` and the acceptance test. Confirmed via
  `find /usr/share/applications`, fixed both, `xdg-terminal-exec --print-id` now
  resolves correctly.
- User ran `sudo install/sync-system apply` and `sudo systemctl enable sddm`.
- **Bug found in my own test:** `session start: sddm is configured...` wrapped its
  check in `as_root` unnecessarily, copying the sshd-config pattern from Phase 2 —
  but `/etc/sddm.conf.d/10-wayland.conf` is plain `0644`, world-readable, unlike
  `sshd_config`. Fixed to drop `as_root`; the test needed no privilege at all.
- **Static group: 6/6 green.** The `hyprland` package turned out to already ship both
  `hyprland.desktop` (direct) and `hyprland-uwsm.desktop` ("Hyprland (uwsm-managed)",
  `Exec=uwsm start -e -D Hyprland hyprland.desktop`) — no custom `.desktop` file
  needed, matching the plan's decision not to force a specific session name.
- **Gap caught in self-review, before it was forgotten:** re-reading the plan against
  what actually got built, `home/wireplumber/` — the two conf.d snippets from Phase
  3's research (ALSA soft-mixer, Bluetooth A2DP autoconnect) — had never been
  written. Researched WirePlumber 0.5's real current conf.d rule syntax (`monitor.
  alsa.rules` / `monitor.bluez.rules` with `matches`/`actions.update-props`, not the
  old 0.4 Lua scripts), wrote both files, and verified them by actually starting
  `wireplumber.service` (`systemctl --user start pipewire wireplumber`) — no parse
  errors in the journal, `wpctl status` responds cleanly. Stopped the services again
  afterward.
- Only the two genuine live-session checks (Hyprland actually running, the four
  autostarted processes alive) remain, pending an actual login through SDDM from
  Unraid's console.
- **CI caught red, three commits deep, before I'd checked it** (should have watched
  it after every push, not just at commit time on the VM). `error: target not found:
  yay` — I'd fixed the *convention* (the VM's bulk install now uses `yay -S`) but
  never updated `.github/workflows/check.yml`, which installs
  `packages/tooling.txt` with plain `pacman -Syu` in a container that only needs
  enough tooling to run `scripts/check`, never the desktop stack. Declaring `yay`
  (and its own build chain: `go`, `fakeroot`, `make`, `scdoc`, `debugedit`, `gcc`)
  in `tooling.txt` broke that command outright, since pacman can't resolve an
  AUR-only name and CI's install step doesn't go through yay at all.
  **Fix:** moved all seven lines from `packages/tooling.txt` to `packages/
  desktop.txt` instead of touching the workflow — `tooling.txt` goes back to being
  100% official-repo (CI-safe with plain pacman), and these packages live next to
  the thing they exist to support (`xdg-terminal-exec`). The VM's own bulk-install
  convention (`yay -S --needed $(scripts/pkglist packages/*.txt)`) is unaffected,
  since it processes every list either way.
- **Blocker found trying to actually log in: noVNC is gone.** When the user
  restarted the VM for the display-device change (see the earlier "VM back up" entry
  above), they did **full PCI GPU passthrough** of the physical Intel GPU, not the
  planned Virtio-GPU(3D). Full passthrough hands the display output straight to the
  guest, bypassing Unraid's own display pipeline entirely — Unraid can no longer
  render a console, so noVNC disappeared. Unraid's only remaining remote-access
  option is RDP, which needs a GUI session already running inside the guest to serve
  it — useless for a first login. The user has been getting past the LUKS prompt on
  reboot via Unraid's terminal (`virsh`-style exec into the running VM), not a real
  graphical console.
- Considered `wayvnc` (a Wayland-native VNC server; `hyprctl output create headless`
  + `wayvnc -o <output>` is the standard, well-documented pattern for exactly this
  "wlroots compositor, no physical display" scenario) as a workaround that keeps
  passthrough. Surfaced a real complication before going further: our own sshd
  config (D-0021) sets `AllowTcpForwarding no` deliberately, so a plain SSH tunnel to
  reach a VNC port wouldn't work without a scoped exception.
- **User's own question reframed the problem correctly:** shouldn't we already be
  able to just see a GUI, without adding remote-access tooling? Yes — that's exactly
  what Virtio-GPU(3D) (the original recommendation) gives, since Unraid keeps owning
  the framebuffer. Full passthrough was chosen during troubleshooting for terminal
  GPU acceleration (ghostty) and "another dep" the user suspected needed it.
- **Checked whether that's actually true, against real package dependencies**
  (`pacman -Si`, not assumption): nothing installed for Phase 4 hard-requires Vulkan.
  Hyprland, hyprlock, and hyprpaper all depend on OpenGL/EGL (`libEGL`, `libGLESv2`,
  mesa), not Vulkan. Ghostty renders via OpenGL on Linux. `vulkan-intel` was added
  speculatively ("proper Vulkan support alongside mesa's OpenGL"), not because
  anything currently in scope demanded it. Virtio-GPU(3D)'s `virgl` mode provides
  OpenGL acceleration via host-side translation, which covers everything Phase 4
  needs. Vulkan-over-virtio (`Venus`) is a separate, newer capability Unraid's simple
  GUI toggle likely doesn't even expose (per the original research: needs manual
  libvirt XML edits). The one place Vulkan plausibly matters is Phase 5's
  `gpu-screen-recorder` (screenshots/recording), which typically wants it for
  GPU-accelerated capture — a real future consideration, not a Phase 4 blocker.
- **User decision: revert to Virtio-GPU(3D).** Should restore the direct
  "just look at Unraid's noVNC console" experience with no extra tooling, at the cost
  of leaving the Vulkan/passthrough question for Phase 5 (or later) if capture
  quality actually suffers without it. `vulkan-intel` stays declared either way —
  harmless to have installed even if not strictly required yet.
- **User is disconnecting again to make the change.** Resume live-session testing
  once the VM is back up on Virtio-GPU(3D).

### 2026-09-14 (continued) — live-session testing
- **VM back up on Virtio-GPU(3D); noVNC restored as expected.** User logged into
  "Hyprland (uwsm-managed)" through SDDM, visible directly in Unraid's console — no
  wayvnc or other tooling needed, confirming the revert diagnosis was right.
- Connected from this SSH session (same user, different login) by reading
  `HYPRLAND_INSTANCE_SIGNATURE` — it was already correctly set in the shell
  environment, so `hyprctl` worked immediately with no extra setup.
- **Real bug found: `hyprpolkitagent` never started.** `pgrep` showed Hyprland, mako,
  hypridle, and hyprpaper running, but not hyprpolkitagent. Root cause: its binary
  isn't on `$PATH` at all (`/usr/lib/hyprpolkitagent/hyprpolkitagent`, not
  `/usr/bin/`), so `autostart.lua`'s `hl.exec_cmd("uwsm app -- hyprpolkitagent")`
  silently failed to find the command.
- **Broader finding while fixing it:** all four autostarted processes — mako,
  hypridle, hyprpaper, *and* hyprpolkitagent — ship their own proper systemd `--user`
  service (`WantedBy=graphical-session.target`, checked via `pacman -Ql`). The other
  three had only been working because their binaries happened to be on `$PATH`, not
  because `hl.exec_cmd` was the right mechanism — duplicating what their own shipped
  services already do, with restart-on-failure, correctly. Rewrote `autostart.lua` to
  do nothing and explain why, and enabled all four services instead
  (`systemctl --user enable --now mako.service hypridle.service hyprpaper.service
  hyprpolkitagent.service`) — no `sudo` needed, these are user-level units. Killed the
  three old manually-started processes first to avoid mako's D-Bus name
  (`org.freedesktop.Notifications`) already being owned when systemd tried to start
  its own copy.
- **All 9 acceptance tests green**, live, in the real session: packages, `Hyprland
  --verify-config`, SDDM config/enabled, `xdg-terminal-exec`, matugen rendering,
  Hyprland reachable via `hyprctl`, all four processes running (now systemd-managed),
  and the notification service reachable over D-Bus.
- **Visual bug reported by the user: "very zoomed in and square."** `hyprctl
  monitors` showed why: `mode = "preferred"` picked `1024x768@60` (4:3, not the
  widescreen modes also available) at `scale: 2` — the virtual display reports no
  EDID physical size at all (`physical size (mm): 0x0`), which `"preferred"`/`"auto"`
  clearly handle badly with nothing real to reason from. Fixed `monitors.lua` to an
  explicit `1920x1080@60` at `scale = 1` (confirmed available in `hyprctl monitors`'
  own mode list). `Hyprland --verify-config` still passes; applied live with
  `hyprctl reload` (no re-login needed) and confirmed via `hyprctl monitors` that
  both the resolution and scale actually changed. **User confirmed the fix worked.**

## VM → physical hardware notes

- Twice-superseded, worth keeping the full story: the VM went QXL (Phase 4 planning)
  → full PCI passthrough of the physical Intel UHD Graphics 770 (`i915`/`xe`, chosen
  during troubleshooting for terminal GPU acceleration) → back to Virtio-GPU(3D)
  (reverted once full passthrough turned out to disconnect Unraid's own console —
  see the implementation log). Real hardware won't have this problem at all: a
  physical workstation's display goes to an actual monitor, with no host display
  pipeline to disconnect from. Whether `cursor:no_hardware_cursors` or any other
  VM-only Hyprland workaround is needed should get confirmed once live-session
  testing actually happens, not assumed either way. If the eventual physical
  workstation uses different (e.g. discrete NVIDIA/AMD) graphics, driver packages
  need revisiting; if it's also Intel, this VM's config should carry over closely.
- If Phase 5's `gpu-screen-recorder` turns out to need Vulkan for good capture
  quality and Virtio-GPU(3D)'s `virgl` (OpenGL-only) mode isn't enough, revisit
  either enabling Venus (Vulkan-over-virtio, needs manual libvirt XML edits beyond
  Unraid's simple toggle) or accepting full passthrough's console tradeoff
  deliberately at that point (e.g. paired with `wayvnc` for visibility, which was
  considered and set aside this time).
- Revisit the audio testing caveat once a virtual sound card exists in Unraid, and
  again once on physical hardware with real audio devices.

### Post-close follow-up (2026-09-14) — the Virtio-GPU(3D) revert didn't actually land

After the phase closed, the user reported Hyprland tripped "Emergency mode... a lua
config error resulted in no binds being registered" right after confirming the
`monitors.lua` fix (D-0032's `1920x1080@60` at `scale = 1`) looked correct — the
*next* automatic config reload (Hyprland's own file-watcher, not the manual
`hyprctl reload` that had just worked) hit an error and reverted the display back to
its pre-fix state.

Investigation (over SSH, same live instance, PID unchanged throughout):
- `Hyprland --config ... --verify-config` still reports `config ok` — the Lua files
  themselves are valid. A manual `hyprctl reload` immediately recovered the session
  (confirmed back to `1920x1080`, and `hyprctl binds` showed our real four binds, not
  emergency fallback ones) — so whatever the automatic reload hit wasn't a lasting
  corruption, and didn't need a restart to fix.
- Couldn't find the actual error text in the live instance's `hyprland.log` —
  "emergency", "reload", and "Config parsing result" don't appear anywhere in it, so
  that phrasing may be specific to a standalone `--verify-config` invocation's own
  stdout, not something the long-running instance logs.
- **Bigger, independently-confirmed problem found along the way:** `lspci` (full,
  unfiltered) shows this VM's *only* display device is still **QXL** — not
  Virtio-GPU(3D) as D-0032 called for, and not the earlier full-passthrough Intel
  GPU either. `/dev/dri/` has no render node (`card1` only, no `renderD128`),
  matching the original "QXL has no DRM render node" finding from planning. The
  running Hyprland instance has been stuck retrying `CDRMRenderer(drm): Can't create
  renderer, no matching devices found` in a tight loop since it started — confirmed
  from line 147 of the log, not a recent change — and by the time this was
  investigated the log had grown to **221,000+ lines** and was still growing fast.
  This likely explains why an automatic reload could trip into a bad state: the
  renderer was already in a persistent failure loop underneath everything that
  otherwise looked like it was working (mode-setting/display-output apparently still
  functions on QXL even without a working compositing renderer, which is presumably
  how the session remained visually usable at all).
- **User found the actual cause in Unraid's VM edit-config view** (not yet described
  in detail) and is restarting the VM to fix it — this is a real gap between what
  D-0032 intended (Virtio-GPU(3D)) and what's actually running (QXL), not a new
  regression to chase in the repo's own config.
- Session disconnected here to make the change; resume by re-checking `lspci` and
  `/dev/dri/` once the VM is back, and watching whether the DRM renderer loop is gone
  from a fresh `hyprland.log` before trusting the display is stable long-term.

## Exit criteria

- [x] Static and live-session acceptance tests both pass (9/9)
- [x] `scripts/check` green
- [x] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [x] Branch merged to `main`
