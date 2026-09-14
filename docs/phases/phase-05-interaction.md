# Phase 05 — Interaction

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude |
| **Branch** | `phase/05-interaction` |
| **Started** | 2026-09-14 |
| **Completed** | — |

## Goal

The Hyprland session becomes usable day to day: an app launcher, a real keybinding
scheme, clipboard history, screenshots/recording, a status bar, and a power/system
menu.

## Scope

**In scope**
- Packages (verified against the live pacman database before declaring, same
  discipline as Phase 4): `fuzzel`, `waybar`, `cliphist`, `wl-clipboard`, `grim`,
  `slurp`, `hyprpicker`, `satty`, `gpu-screen-recorder`, a QR-decode tool, and
  whatever `gpu-screen-recorder` actually needs for the Vulkan question D-0032
  flagged as a "revisit in Phase 5" item.
- Home config: `home/fuzzel/`, `home/waybar/` (+ matugen template), a power/system
  menu script, web-app install/launch scripts, capture script(s) wrapping the
  grim/slurp/satty/gpu-screen-recorder chain if a thin wrapper is needed.
- `home/hypr/dot-config/hypr/bindings.lua` extended; a new `windows.lua` for
  smart-gaps + PIP window/workspace rules, `require()`d from `hyprland.lua`.
- `tests/acceptance/phase-05.bats`, static/live-session split like Phase 4.

**Out of scope**
- The full theme system (multiple named themes, a switcher) — Phase 6.
- OCR text capture — mentioned in Omarchy's chain, not adopted; a future add.
- Shell/prompt, Neovim, dev tooling — Phase 7.

## Decisions

**Resolved (user, 2026-09-14)**
- **Launcher: fuzzel** — smallest footprint (no GTK/Qt), fastest to open, plain ini
  config, actively maintained, dedicated dmenu-safety flag. Chosen over rofi
  (heavier, Wayland-in-mainline only since 2025) and wofi (GTK+CSS, "not actively
  maintained" upstream). Its `--dmenu` mode is also the power/system menu's engine.
- **Web-app launchers: included** (Omarchy's `.desktop` + browser `--app=`
  mechanism, ADAPTed in Phase 3, adoption confirmed now).
- **Workspace/window rules: adopted** — smart gaps (no gaps with one window) and
  auto-float+pin for picture-in-picture windows. Idiomatic, low-stakes, reversible.

**Resolved (plan, from Phase 3)**
- Clipboard: cliphist + wl-clipboard (D-0025).
- Screenshots/recording: grim + slurp + hyprpicker + satty + gpu-screen-recorder,
  including QR capture (ADOPT).
- Status bar: waybar (D-0025), matugen-templated
  (`InioX/matugen-themes` pattern: `colors.css` imported into `style.css`,
  `post_hook = 'pkill -SIGUSR2 waybar'`).
- Keybinding modifier convention (from Phase 3 research): SUPER = primary,
  SUPER+SHIFT = move/secondary, SUPER+CTRL = panels/toggles, SUPER+ALT = secondary
  window actions.
- Recorded in `DECISIONS.md` at close-out (likely D-0033 onward): launcher, web-app
  launchers, window rules.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-05.bats`, same two groups as Phase 4:

| Group | What it proves | Who runs it |
|---|---|---|
| static | Packages declared+installed; config files linked; `Hyprland --verify-config` passes; waybar's JSON config is valid; matugen renders the waybar template | Claude, no live session needed |
| live-session | Launcher opens and finds apps; power menu works; clipboard history captures and pastes; a screenshot produces a real file; waybar is visible and themed; workspace/window rules behave as expected | User, from Unraid's console |

Red confirmed: yes (VM, 6/6 failing, no load/syntax errors — nothing installed yet,
as expected) · Green confirmed: yes, automated group 6/6 (full suite across every
phase: 72/72, no regressions); genuinely-interactive checks (launcher finding apps,
power menu, screenshot annotation UI, waybar theme colors, PIP float/pin, web-app
launcher) still need the user's own visual confirmation — see live-session tasks

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-05.bats`; confirmed 6/6 failing, no load/syntax
      errors
- [x] `packages/desktop.txt` additions, verified against the live pacman database
      (also resolved D-0032's Vulkan question for real: gpu-screen-recorder has no
      Vulkan dependency, uses VAAPI via intel-media-driver instead)
- [x] fuzzel — fully matugen-templated (like mako/hyprlock/ghostty in Phase 4),
      not a static `home/fuzzel/` package. Fixed a contrast bug found in passing:
      selection colors used `surface`/`on_surface`, which render nearly identical
      to background/text for this palette -- switched to `surface_variant`/
      `on_surface_variant`. Same bug, same fix, retroactively applied to Phase 4's
      hyprlock template (its `inner_color`/`font_color` had the identical issue).
- [x] `home/waybar/` + matugen template (hybrid pattern: static config.jsonc/
      style.css, matugen-generated colors.css, `@import`-ed, reloaded via
      `pkill -SIGUSR2 waybar`), wired into `home/matugen/.../config.toml`
- [x] Power/system menu script (`power-menu`, fuzzel --dmenu)
- [x] Clipboard wiring: `clipboard-menu` script (cliphist's own documented
      fuzzel-dmenu pattern) + confirmed cliphist ships its own systemd --user
      service (checked the real Arch PKGBUILD) for the wl-paste watcher --
      enable it, don't hand-write an autostart line
- [x] Capture wiring: `screenshot` (slurp+grim+satty pipeline), `screen-record`
      (gpu-screen-recorder, SIGINT toggle), `qr-capture` (slurp+grim+zbarimg);
      color-pick is a direct `hyprpicker -a` bind, no wrapper script needed.
      Vulkan question checked for real: gpu-screen-recorder has no Vulkan
      dependency at all, and its KMS root-access need is handled by a setuid
      helper in the native package (no interactive sudo prompt) -- the
      password-prompt caveat in its docs is flatpak-only.
- [x] Web-app launcher scripts (`webapp-install`, `webapp-launch`)
- [x] `bindings.lua` additions (launcher, menu, clipboard, capture, workspace
      navigation); new `windows.lua` (smart gaps + PIP float/pin) -- both verified
      against `Hyprland --verify-config`
- [x] Found and fixed a real gap: `scripts/check` never linted scripts deployed via
      `home/` (only `scripts/`, `install/`) -- extended it, and extended
      `.editorconfig`'s `switch_case_indent` the same way Phase 2 did for
      `scripts`/`install`
- [x] User: `yay -S --needed $(scripts/pkglist packages/*.txt)`, then enabled
      `cliphist.service` — caught during verification that **waybar was never
      wired up at all** (it also ships its own systemd service, missed entirely
      until "waybar is running" failed); enabled it too
- [x] Static + automated live-session acceptance tests green (72/72, full suite,
      no regressions). Also fixed a real test hang (`wl-copy` forking to
      background kept bats's output pipe open after all 6 results printed)
- [x] Live-session testing (user): launcher, power menu, waybar, clipboard
      confirmed working; two flagged items explained (no audio hardware, no font
      yet — both already-known, out-of-phase-scope gaps, not bugs). Screenshot/
      color-pick/PIP not yet tried; not blocking.
- [ ] Close: `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md`
- [ ] Merge to `main`

## Implementation log

### 2026-09-14
- Plan researched and approved. Two research passes: launcher comparison
  (wofi/fuzzel/rofi) and waybar module conventions + Hyprland workspace/window
  rules. User decisions: fuzzel, web-app launchers included, smart-gaps + PIP
  window rules adopted.
- Branch, tracking doc, Red (6/6 failing, confirmed cleanly).
- Package list verified against the live pacman database; resolved D-0032's
  Vulkan question for real (`gpu-screen-recorder` has none) rather than assuming
  either way.
- Built fuzzel/waybar config, matugen-wired. Found and fixed a real contrast bug
  along the way (`surface`/`on_surface` render nearly identical to
  `background`/`text` for this palette) in both the new fuzzel template and,
  retroactively, Phase 4's already-merged hyprlock template.
- Found a real gap: `scripts/check` never linted `home/`-deployed scripts (only
  `scripts/`/`install/`). Extended it and `.editorconfig`, the same fix shape as
  Phase 2's for extensionless scripts.
- Verified every CLI flag/syntax against real sources before writing scripts
  (satty's `--filename`/`--output-filename`/`--copy-command`, gpu-screen-recorder's
  actual flags and its KMS-root-access story, cliphist's actual PKGBUILD
  confirming it ships its own systemd service) rather than assuming — same
  discipline as Phase 4, which found several bugs exactly this way.
- Hyprland's Lua API for `window_rule` action keys isn't fully typed in this
  system's own installed stub (`/usr/share/hypr/stubs/hl.meta.lua`) — only
  `enabled`/`match`/`name` are statically declared, though the official example
  config clearly uses additional dynamic keys (`no_focus`) the same way.
  `windows.lua` mirrors the pre-Lua `windowrulev2` keyword names for `float`/`pin`
  on that basis; `--verify-config` accepts it (syntax), but whether it actually
  floats+pins a real picture-in-picture window needs live-session confirmation.
- All Lua config changes (`bindings.lua`, `windows.lua`, `hyprland.lua`'s new
  `require`) verified against `Hyprland --verify-config`: config ok.
- Waiting on the user: `yay -S --needed $(scripts/pkglist packages/*.txt)`, then
  enabling `cliphist.service`.
- **Packages installed, cliphist enabled.** Verification found two more real bugs:
  - **waybar was never actually wired up.** Completely missed that it ships its
    own systemd `--user` service like everything else in `autostart.lua`'s
    growing list — only caught because "live-session: waybar is running" failed.
    Enabled `waybar.service` alongside `cliphist.service` (both needed `--now`
    too, since `graphical-session.target` had already been reached before they
    were enabled) and documented it.
  - **The clipboard test hung the whole suite.** `wl-copy` forks to background by
    design; the forked process kept bats's output pipe open even after all 6
    results had printed, so the command never returned control (confirmed by
    reading the background task's own output file: all 6 `ok` lines were there,
    it just hadn't exited). Fixed with `--paste-once` (serve exactly one paste
    request then exit) wrapped in a 5s `timeout`, so a not-yet-running watcher
    fails the test cleanly instead of hanging.
  - Full acceptance suite re-run across every phase: **72/72 green**, no
    regressions.
- **User's visual confirmation:** launcher works, power menu works, waybar shows
  clock/date and `enp1s0` (the real ethernet interface, correct), clipboard works.
  Two things the user flagged as unclear, both already-known/already-scoped gaps,
  not new bugs — confirmed directly rather than assumed:
  - **Audio module shows "0%":** `wpctl status` confirms zero audio sinks/sources/
    devices exist at all on this VM — the already-documented "no audio device" gap
    from Phase 4. The module is correctly reporting there's nothing to report;
    it'll show a real value once a virtual sound card exists.
  - **A square/placeholder icon where a glyph should be:** `fc-list` confirms no
    Nerd Font is installed. The workspace/audio/network module icons use Nerd Font
    glyphs that render as empty boxes ("tofu") without one — expected, since fonts
    are explicitly Phase 6's job, not this phase's. Will render correctly once
    Phase 6 installs a font with those glyphs.
  - Screenshot, color-pick, and picture-in-picture float/pin: not yet tried by the
    user; lower-risk/self-contained pieces, not blocking close-out. Revisit if
    they turn out not to work.

## VM → physical hardware notes

-

## Exit criteria

- [ ] Static and live-session acceptance tests both pass
- [ ] `scripts/check` green
- [ ] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
