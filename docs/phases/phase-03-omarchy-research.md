# Phase 03 — Omarchy Research

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude |
| **Branch** | `phase/03-omarchy-research` |
| **Started** | 2026-09-14 |
| **Completed** | 2026-09-14 |

## Goal

Every remaining component across all layers (2 through cross-cutting) is classified
ADOPT/ADAPT/REJECT/DEFER in `docs/omarchy-influences.md`, researched from Omarchy's
actual current source, ahead of the phases (4–9) that implement them.

## Scope

**In scope**
- Full `docs/omarchy-influences.md` entries for every row still marked `—` in the
  "Components to research" table: login/session start, Hyprland config structure,
  audio/portals/polkit, notifications, idle management and locking, wallpaper,
  application launcher, menus, keybinding scheme, terminal, clipboard,
  screenshots/screen recording, status bar, web-app launchers, theme system and
  switching, fonts/GTK/Qt/icons/cursors, shell and prompt, Neovim distribution,
  language/tool version management, containers, package selection, update and
  migration mechanism.
- One architectural decision made now rather than deferred: the desktop-shell direction
  (decoupled standard tools + matugen, vs. a unified custom shell).

**Out of scope**
- Any specific tool pick beyond the shell-direction decision (bar, launcher, notification
  daemon, terminal, editor, shell, version manager, etc.) — each stays its own
  implementing phase's plan-mode decision, per the roadmap's existing deferral pattern.
- Any VM change, install, or code. This phase is documentation only.

## Decisions

**Resolved (user, 2026-09-14)**
- Desktop layer: standard, independently-replaceable tools (matches CLAUDE.md's own
  interface-segregation principle), not a unified custom shell (built from scratch, or
  adopting the independent Quickshell-based `Noctalia` project).
- Theming mechanism: **matugen** (single palette → per-tool templates → post-hook
  reload) adopted now as the cross-cutting answer to the "N configs to keep in sync"
  problem Omarchy itself cited, without needing a unified shell process to get it.

**Resolved (plan)**
- Recorded as D-0025 at close-out.

## Acceptance tests

None. This phase produces documentation only; CLAUDE.md's own TDD table already excepts
pure documentation from testing. Verification is a structured read-through instead (see
Exit criteria).

## Tasks

- [x] Branch, tracking doc
- [x] Research desktop-session-layer components (login/session start, Hyprland config
      structure, audio/portals/polkit, notifications, idle/lock, wallpaper)
- [x] Research interaction-layer components (launcher, menus, keybindings, terminal,
      clipboard, screenshots/recording, status bar, web-app launchers)
- [x] Research visual/dev/cross-cutting components (theme system, fonts/GTK/Qt/icons,
      shell/prompt, Neovim, version management, containers, package selection,
      update/migration mechanism)
- [x] **Correction:** discovered Omarchy's v3→v4 ("Quattro") rewrite mid-research; redid
      the desktop-session and interaction-layer research pinned to the current branch
- [x] Resolved the desktop-shell architecture question with the user (matugen +
      decoupled tools over a unified shell)
- [x] Write all `docs/omarchy-influences.md` entries and fill in the summary table
- [x] Record D-0025 in `DECISIONS.md`
- [x] Update `docs/roadmap.md`
- [x] Small CLAUDE.md wording fix (Hyprland config example: `source =` → Lua modules)
- [ ] Close out: exit criteria, merge to `main`

## Implementation log

### 2026-09-14
- Five research passes total. The first three (desktop-session, interaction,
  visual/dev/cross-cutting) ran in parallel via Explore agents reading
  `basecamp/omarchy` (now `omacom/omarchy`) on GitHub.
- **Finding requiring correction:** the desktop-session and interaction-layer passes
  mixed real facts with stale v3-era ones (waybar, mako, hypridle/hyprlock, swaybg,
  walker+elephant, plain `hyprland.conf`) — apparently from cached/off-branch sources.
  Verified directly: the repo's default branch is `quattro` (current stable `v4.0.3`,
  2026-09-08), and all of those tools are confirmed retired
  (`bin/omarchy-upgrade-to-quattro` uninstalls them by name). The third pass
  (visual/dev/cross-cutting) had already used the correct branch and needed no redo.
- Redid the affected research with two new passes, explicit `?ref=quattro` on every
  fetch: one for the shell-owned components (launcher, menus, notifications, idle/lock,
  wallpaper, clipboard, status bar — all now Quickshell/QML plugins in one
  `omarchy-shell` process), one for the Lua-based Hyprland config structure,
  audio/portals/polkit, screenshots/recording, and a spot-check of terminal and
  web-app-launcher facts (both held up unchanged).
- Verified independently that Hyprland's Lua config format is upstream's own change
  (native since 0.55/0.56, hyprlang `.conf` now deprecated), not an Omarchy invention.
- Asked the user how to classify the 7 shell-owned components. Researched Omarchy's own
  stated rationale for consolidating into one shell (from the actual `v4.0.0` GitHub
  release notes and third-party coverage): theming consistency across 8 previously
  separate configs, event-driven vs. polled performance, notification state surviving a
  shell restart (which happens on every update), and a plugin ecosystem. Also researched
  `matugen` (a mature, actively-maintained single-binary templating tool already
  standard in the wider Hyprland community for exactly the "one palette → many configs"
  problem) and `Noctalia` (an independent, non-Omarchy Quickshell-based shell, offered
  as a middle path).
- **User decision:** standard decoupled tools + matugen, not a unified shell. Matugen
  solves the one consistency problem that actually matters for a single-user system,
  at a much smaller lift than building or adopting a whole shell; the performance and
  restart-persistence wins are Omarchy-scale concerns (many users, frequent shell
  restarts on update) that don't apply here, and a plugin ecosystem isn't needed for a
  personal system.
- Wrote all 23 new `docs/omarchy-influences.md` entries (plus the summary table's
  Decision column for every row) and D-0025 in `DECISIONS.md`. Verified: every table row
  has a filled-in Decision cell; every new entry has all nine documented fields (a first
  automated check undercounted 7 entries that phrased the first field as "Omarchy
  approach (v4):" instead of "Omarchy approach:" — confirmed by inspection that all nine
  fields are actually present in each, false alarm from a too-strict grep, not a real
  gap). `docs/roadmap.md` marked complete, its deferred-decisions bullet resolved to
  D-0025. `CLAUDE.md`'s engineering-principles table updated (`source =` → Lua
  `require()` modules, since Hyprland's own upstream config format changed, independent
  of anything Omarchy did).
- `scripts/check`: 71/71 unit tests, shellcheck/shfmt clean, identifier scanner clean
  across all 67 tracked files (including the new tracking doc, once staged). No Omarchy
  install, clone, or execution happened at any point — every fact came from `gh api`,
  WebFetch, or WebSearch reads.

## VM → physical hardware notes

- None — this phase touched no VM state, only documentation.

## Exit criteria

- [x] Every row in `docs/omarchy-influences.md`'s summary table has a filled-in Decision
- [x] Every new component entry has all nine documented fields
- [x] No Omarchy install, clone, or execution occurred (research only)
- [x] `scripts/check` passes (71/71 unit tests; shellcheck/shfmt/identifier-scan clean)
- [x] `DECISIONS.md` updated (D-0025)
- [x] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
