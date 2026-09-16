# Phase 11 — Default browser and web-app launching

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude + user |
| **Branch** | `phase/11-default-browser` |
| **Started** | 2026-09-16 |
| **Completed** | 2026-09-16 |

## Goal

A real default browser exists, declared and reproducible, and Phase 5's
`webapp-install`/`webapp-launch` mechanism (previously dormant/broken since
nothing ever installed a browser) actually works end to end.

## Scope

**In scope**
- `chromium` + `xdg-utils` in `packages/desktop.txt`.
- Declarative default-browser registration: `home/xdg/dot-config/mimeapps.list`.
- `webapp-launch` fix: clear, actionable error instead of a cryptic `exec`
  failure when no default browser is resolvable.
- `tests/acceptance/phase-11.bats`, static + live-session.

**Out of scope**
- Any browser other than Chromium.
- Changes to fuzzel (confirmed it needs none).
- General "how to add any GUI app" tooling beyond this one concrete example.

## Decisions

**Resolved (user, 2026-09-16)**
- Browser: Chromium (official repo, FOSS, Chromium-family for webapp-launch's
  app-mode).
- Tracked as a full phase, same lifecycle as everything else in this repo.

**Resolved (plan)**
- Recorded in `DECISIONS.md` at close-out, starting at D-0060.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-11.bats`

| Group | What it proves | Who runs it |
|---|---|---|
| static | chromium+xdg-utils installed; mimeapps.list sets the correct default; `webapp-launch` fails clearly with no args / bad state | Claude, no live session needed |
| live-session | fuzzel finds and launches Chromium; `webapp-install`+`webapp-launch` produce a real app-mode window | User |

Red confirmed: 2026-09-16, 2/5 failing cleanly · Green confirmed: 2026-09-16,
3/3 real checks (2 remain manual live-session skips by design)

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-11.bats`; confirmed 2/5 failing cleanly (2
      already passed -- the `webapp-launch` fix and a manual skip -- no
      load/syntax errors)
- [x] `webapp-launch` fix (clear error on unset default) -- verified against
      the live, currently-broken state before any package was installed
- [x] `packages/desktop.txt`: `chromium`, `xdg-utils`
- [x] `home/xdg/dot-config/mimeapps.list` -- verified against the real format
      `xdg-settings set` produces, not guessed
- [x] In-passing addition: `install/install-packages`, wrapping
      `yay -S --needed $(scripts/pkglist packages/*.txt)` -- the user pointed
      out this exact command has been retyped from memory every phase since
      Phase 4, including two real past slip-ups (Phase 8, Phase 9) where plain
      `pacman -S` got used instead and silently aborted on AUR-only packages.
      `docs/runbooks/rebuild.md` updated to use it.
- [x] Static acceptance tests green (3/3 real checks); `scripts/check` green
      (99/99 unit tests)
- [x] User: installed packages. Verified end to end: `xdg-settings get
      default-web-browser` → `chromium.desktop`; `webapp-install` produced a
      real `.desktop` entry; `webapp-launch` launched a genuine Chromium
      process (confirmed via `hyprctl clients` showing a real window) --
      Chromium's one-time first-run dialog is the only piece needing the
      user's own hands, as scoped
- [x] Close: `DECISIONS.md` (D-0060), `docs/roadmap.md`
- [ ] Merge to `main`

## Implementation log

### 2026-09-16
- Plan researched and approved. One research pass confirmed: no browser
  installed anywhere, no `.desktop` entry, `xdg-settings get
  default-web-browser` empty live -- and traced `webapp-launch`'s actual logic
  with that empty value to confirm it currently hard-fails
  (`exec: : No such file or directory`) rather than degrading gracefully, a
  real dormant bug since Phase 5. Also confirmed fuzzel needs no changes at
  all (standard XDG desktop-file discovery, no app-specific config in its
  template) and that `xdg-utils` is already installed live but only as a
  transitive dependency, never declared.
- Branch, tracking doc created.
- Fixed `webapp-launch`'s empty-default-browser case first, verified directly
  against the live broken state: now exits 1 with
  "no default web browser is set" instead of the old cryptic bash exec error.
- Red confirmed: 2/5 failing cleanly (packages not installed, no default
  browser registered yet).
- User pointed out mid-phase that `yay -S --needed $(scripts/pkglist
  packages/*.txt)` has been manually retyped every phase since Phase 4 --
  added `install/install-packages` as a proper wrapper (+ unit tests, stubbed
  `yay`), updated `docs/runbooks/rebuild.md` to use it. A real testing snag:
  simulating "yay not found" needed a curated minimal `PATH` (just `env` +
  `bash` symlinked in), since an empty `PATH` breaks even the script's own
  `#!/usr/bin/env bash` shebang resolution, and the VM's real `PATH` always has
  yay already installed.
- Added `chromium`+`xdg-utils` to `packages/desktop.txt`; user installed via
  the new `install/install-packages`.
- Verified the real `mimeapps.list` format by actually running
  `xdg-settings set default-web-browser chromium.desktop` and reading the
  result, rather than guessing the format -- wrote `home/xdg/dot-config/
  mimeapps.list` to match exactly (with an explanatory header comment,
  confirmed not to break `xdg-settings get`'s parsing after stowing).
- Verified `webapp-install`+`webapp-launch` for real: `webapp-install` produced
  a working `.desktop` entry (favicon fetch failed for example.com
  specifically, a 404 from the best-effort favicon service -- expected,
  already documented in D-0034 as non-fatal); `webapp-launch` resolved the new
  default browser correctly and launched a genuine Chromium process, confirmed
  via `hyprctl clients -j` showing a real window
  ("Chromium Additional Terms of Service" -- Chromium's own one-time
  first-run dialog on a freshly-installed browser, not a bug). Cleaned up the
  test `.desktop`/icon artifacts afterward.
- Full acceptance suite re-run: 3/3 real Phase 11 checks green, no regressions
  anywhere else (`scripts/pkg-audit`: no drift).

## VM → physical hardware notes

-

## Exit criteria

- [x] Static and live-session acceptance tests both pass
- [x] `scripts/check` green
- [x] `DECISIONS.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
