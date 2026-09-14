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

Red confirmed: _pending_ · Green confirmed: _pending_

## Tasks

- [x] Branch, tracking doc
- [ ] Red: `tests/acceptance/phase-05.bats` (static group); confirm red
- [ ] `packages/desktop.txt` additions, verified against the live pacman database
- [ ] `home/fuzzel/`
- [ ] `home/waybar/` + matugen template, wired into `home/matugen/.../config.toml`
- [ ] Power/system menu script
- [ ] Clipboard wiring (cliphist + wl-clipboard)
- [ ] Capture wiring (grim/slurp/hyprpicker/satty/gpu-screen-recorder), Vulkan
      question checked for real
- [ ] Web-app launcher scripts
- [ ] `bindings.lua` additions; new `windows.lua`
- [ ] Static acceptance tests green
- [ ] Live-session testing (user)
- [ ] Close: `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md`
- [ ] Merge to `main`

## Implementation log

### 2026-09-14
- Plan researched and approved. Two research passes: launcher comparison
  (wofi/fuzzel/rofi) and waybar module conventions + Hyprland workspace/window
  rules. User decisions: fuzzel, web-app launchers included, smart-gaps + PIP
  window rules adopted.

## VM → physical hardware notes

-

## Exit criteria

- [ ] Static and live-session acceptance tests both pass
- [ ] `scripts/check` green
- [ ] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
