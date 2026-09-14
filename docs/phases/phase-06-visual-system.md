# Phase 06 — Visual system

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude |
| **Branch** | `phase/06-visual-system` |
| **Started** | 2026-09-14 |
| **Completed** | 2026-09-14 |

## Goal

The desktop gets its actual visual identity: fonts, icons, cursor, and GTK/Qt theming,
all driven live from whatever wallpaper is currently set — no more hardcoded seed
color, no more tofu-box icons, no more placeholder wallpaper.

## Scope

**In scope**
- Packages: `ttf-jetbrains-mono-nerd`, `papirus-icon-theme`, a Bibata cursor package
  (verified against the live pacman/AUR database, not assumed).
- New matugen template(s) for GTK3/GTK4, wired into `home/matugen/.../config.toml`.
- New `home/gtk/` (static `gtk-3.0`/`gtk-4.0` `settings.ini`) and `home/fonts/`
  (fontconfig override) packages.
- Cursor + `QT_QPA_PLATFORMTHEME` env vars in `looknfeel.lua`.
- Wallpaper mechanism: `wallpaper-set`/`wallpaper-random` scripts in
  `home/hyprpaper/dot-local/bin/`, driving matugen via `matugen image <path>` so the
  wallpaper becomes the single live palette source. `hyprpaper.conf` repointed at a
  stable `current.png` symlink; a new generated default image replaces
  `placeholder.png`.
- `bindings.lua` addition for `wallpaper-random`.
- `tests/acceptance/phase-06.bats`, static/live-session split.

**Out of scope**
- Curating/downloading real wallpaper art — procedural generation only.
- A named-theme library/switcher — dynamic wallpaper-driven theming only.
- Claude Code's own theme sync — still deferred.
- Neovim colorscheme theming — Phase 7.

## Decisions

**Resolved (user, 2026-09-14)**
- Icon theme: Papirus / Papirus-Dark.
- Cursor theme: Bibata (Modern Classic/Ice).
- Font: JetBrainsMono Nerd Font.
- Theme model: dynamic-only (palette derived live from the current wallpaper via
  `matugen image`), no named-theme library/switcher.
- Wallpapers: procedurally generated default, user-swappable via `wallpaper-set`.
- GTK theming: live matugen-driven `gtk.css`, not a static pre-built theme.

**Resolved (plan, from Phase 3)**
- Qt: `QT_QPA_PLATFORMTHEME=gtk3`, already recorded as adopted mechanism.
- Recorded in `DECISIONS.md` at close-out, starting at D-0037.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-06.bats`

| Group | What it proves | Who runs it |
|---|---|---|
| static | Packages declared+installed; `home/gtk/`, `home/fonts/` linked; `Hyprland --verify-config` passes; matugen renders the GTK template(s) from an image seed; `fonts.conf`/`settings.ini` valid; `current.png` resolves to a real file | Claude, no live session needed |
| live-session | Font glyphs render (no tofu boxes); Papirus icons show; Bibata cursor visible; `wallpaper-random` changes the wallpaper AND re-themes every app live; GTK apps pick up the theme | User, from Unraid's console |

Red confirmed: · Green confirmed:

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-06.bats`; confirmed 7/7 failing, no load/syntax
      errors
- [x] `packages/desktop.txt` additions, verified against the live pacman/AUR database
      (`ttf-jetbrains-mono-nerd`, `papirus-icon-theme` both official `extra`;
      `bibata-cursor-theme-bin` AUR, exact theme folder name confirmed against the
      real GitHub release asset list rather than assumed)
- [x] `home/fonts/dot-config/fontconfig/fonts.conf`
- [x] `home/gtk/dot-config/{gtk-3.0,gtk-4.0}/settings.ini`
- [x] GTK matugen template(s) (`gtk3.css`, `gtk4.css`) + `config.toml` wiring, GTK3
      vs. libadwaita named-color sets verified against real sources first (no
      post_hook -- neither toolkit live-reloads; apps re-read their stylesheet once
      at process start, confirmed by research, not assumed)
- [x] `looknfeel.lua` env vars (`XCURSOR_THEME`/`XCURSOR_SIZE`,
      `QT_QPA_PLATFORMTHEME=gtk3`), `hl.env()` syntax verified against Hyprland's own
      example config
- [x] Default wallpaper image (procedurally generated, pure Python/zlib, no new
      dependency) + `current.png` symlink + `hyprpaper.conf` rewritten to the
      current block-based syntax
- [x] `wallpaper-set` / `wallpaper-random` scripts, hyprpaper's real IPC wire
      protocol and matugen's `image` mode verified by actually running them (not
      assumed) -- found and fixed two real bugs, see log
- [x] `bindings.lua` addition for `wallpaper-random` (SUPER+CTRL+W)
- [x] `ghostty.conf` template: added `font-family`/`font-size`, explicitly left
      undone by Phase 4/5 ("Phase 6's job")
- [x] Static acceptance tests green (6/7 -- the font test needs the package
      installed); `scripts/check` green; full suite re-run, no regressions in any
      prior phase
- [x] User: installed packages (`ttf-jetbrains-mono-nerd`, `papirus-icon-theme`,
      `bibata-cursor-theme-bin`); full acceptance suite re-run: 73-79/79 green for
      Phase 6, no regressions in any prior phase (the other failing tests are the
      known sudo-requires-a-tty and pre-Phase-4 "no AUR packages" gaps, unrelated to
      this phase)
- [x] User: live-session visual confirmation -- "everything looks great" (font
      glyphs render in waybar, Bibata cursor visible, gradient wallpaper actually
      renders for the first time, `wallpaper-random` bind works)
- [x] Close: `DECISIONS.md` (D-0037–D-0042), `docs/omarchy-influences.md` (theme
      system + fonts/GTK/Qt/icons/cursors entries filled in), `docs/roadmap.md`
- [ ] Merge to `main`

## Implementation log

### 2026-09-14
- Plan researched and approved. Two research passes: icon/cursor/font comparison,
  matugen named-theme-switcher pattern survey. User decisions: Papirus/Papirus-Dark,
  Bibata, JetBrainsMono Nerd Font, dynamic wallpaper-driven theming (no named-theme
  library), procedurally-generated-but-swappable wallpapers, live matugen-driven GTK
  theming.
- Branch + tracking doc created. Red: 7/7 failing, confirmed cleanly.
- Verified every package name and CLI/IPC/Lua syntax against real sources before
  writing anything that depends on it (this phase's discipline caught more real bugs
  than any prior phase):
  - **hyprpaper's config syntax has changed** since Phase 4 wrote `hyprpaper.conf`.
    The installed version (0.8.4) parses `wallpaper` as a block special-category
    (`wallpaper { monitor = ...; path = ...; fit_mode = ...; }`); the old flat
    `preload = ...` / `wallpaper = ,path` lines are silently unrecognized -- no
    parse error, but also **no wallpaper was ever actually rendered**, confirmed by
    reading the live journal (`Monitor Virtual-1 has no target: no wp will be
    created`) and `hyprctl hyprpaper listactive` coming back empty. This has been
    silently broken since Phase 4; nobody had visually scrutinized the desktop
    background specifically (other Phase 4/5 checks covered everything else).
    Fixed by reading hyprpaper's actual source (`src/config/ConfigManager.cpp`,
    `WallpaperMatcher.cpp`) rather than trusting stale docs/community posts, which
    also disagreed with each other on the current syntax.
  - **hyprpaper's `hyprctl hyprpaper` IPC is a from-scratch custom wire protocol**
    in this version, not the old plain-text `preload`/`unload`/`reload` commands --
    only `wallpaper` and `listactive` exist now (confirmed against Hyprland's own
    `hyprctl/src/hyprpaper/Hyprpaper.cpp` client source). The config file's
    preferred wildcard spelling (`monitor = *`) does NOT work for the live IPC
    command -- `hyprctl hyprpaper wallpaper "*,path,cover"` fails with "Invalid
    monitor"; the IPC path only accepts an empty monitor field
    (`hyprctl hyprpaper wallpaper ",path,cover"`). Found by actually running it,
    not by reading docs (which don't cover this at all).
  - `matugen image <path>` prompts interactively for a source color when an image
    has multiple viable candidates, which would hang a keybind-triggered script with
    no TTY -- fixed with `--source-color-index 0`, found by actually running it
    without the flag first.
  - XML comments can't contain `--`; `home/fonts/.../fonts.conf`'s header comment
    used it as a separator (matching this repo's own shell-comment convention) and
    fontconfig refused to parse the file (silently falling back to a default font,
    not an error visible in normal use -- caught by the acceptance test instead).
  - Both new scripts (`wallpaper-set`, `wallpaper-random`) initially lacked the
    executable bit -- `Write` doesn't preserve/set it; `chmod +x` fixed it, and the
    live-session acceptance test caught the gap before it shipped.
  - `ghostty.conf`'s template had no font configuration at all -- Phase 4/5 both
    explicitly left it as "Phase 6's job" in a comment; added `font-family`/
    `font-size` (JetBrainsMono Nerd Font) rather than relying on GTK-style generic
    "monospace" fontconfig aliasing, since Ghostty is a native app with its own font
    resolution, not a GTK app.
  - Bibata's exact installed cursor-folder name (`Bibata-Modern-Classic`) confirmed
    against the real GitHub release asset list for the AUR package's pinned version,
    not assumed from the theme's marketing name.
- Full acceptance suite re-run across every phase after implementation: no
  regressions in any prior phase; Phase 6's own static tests 6/7 green (the font
  test needs `ttf-jetbrains-mono-nerd` actually installed -- expected, waiting on
  the user's package install).
- User installed the three packages (`yay -S --needed $(scripts/pkglist
  packages/*.txt)`). Full suite re-run: 73-79/79 green for Phase 6, no regressions
  anywhere else (remaining failures are the pre-existing sudo-requires-a-tty and
  pre-Phase-4 "no AUR packages" gaps, unrelated to this phase).
- User's live-session visual confirmation: "everything looks great" -- font
  glyphs, Bibata cursor, and (for the first time since Phase 4) an actually-visible
  wallpaper all confirmed working.
- Close: `DECISIONS.md` D-0037 (wallpaper-driven theme model, the biggest
  architectural call this phase made -- no named-theme library), D-0038 (Papirus
  icons), D-0039 (Bibata cursor), D-0040 (JetBrainsMono Nerd Font), D-0041 (live
  matugen GTK/Qt theming), D-0042 (the hyprpaper config/IPC bug fix, amending
  D-0028). `docs/omarchy-influences.md`'s two Phase 6 entries filled in.
  `docs/roadmap.md` marked complete.

## VM → physical hardware notes

-

## Exit criteria

- [x] Static and live-session acceptance tests both pass
- [x] `scripts/check` green
- [x] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
