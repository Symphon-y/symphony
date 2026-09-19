# Phase 16 — Fully automated desktop bring-up

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/16-desktop-bring-up` |
| **Started** | 2026-09-19 |
| **Completed** | |

## Goal

Reboot after a fresh install and land directly in a fully working,
personalized Hyprland desktop -- notifications, idle/lock, wallpaper,
polkit agent, status bar, clipboard history all present -- with zero
manual steps, closing `rebuild.md`'s remaining automatable scope.

## Scope

**In scope**
- Enable `sddm.service` and configure SDDM autologin at install time
  (`install/configure-base-system`).
- Give the newly installed target a real, permanent, git-backed copy of
  this repo (`~/Projects/autarchy`), so `install/link-home` and future
  `scripts/update` runs have something stable to work against.
- Run `install/link-home apply` for the new user at install time.
- Write `~/.gitconfig.local` from the GUI installer's already-collected
  (and currently discarded) `git_name`/`git_email` fields, if provided.
- A new, dedicated first-login mechanism (marker-gated script, triggered
  once from Hyprland's own `autostart.lua`) for the one thing that
  genuinely needs a live session: `install/enable-user-services apply`.

**Out of scope**
- Adding a git-identity prompt to the terminal fallback
  (`autarchy-install`) -- stays the narrower "collector of last resort."
- Automating `gh auth login`, Claude Code's own login, or the separate
  `config.nvim` clone -- permanently manual by Phase 8/D-0053's own
  decision (OAuth/interactive, can't be scripted).
- Any change to `scripts/migrate`'s existing meaning (manually-run,
  one-time upgrades) -- the first-login mechanism is a separate,
  dedicated concept, not a repurposed migration.

## Decisions

**Resolved**
- SDDM autologin: yes, reversing part of D-0026's original (deliberately
  conservative) choice not to configure it. LUKS is already the real
  gate at boot; matches Omarchy's own real precedent and this phase's
  literal "zero manual steps" goal. Asked directly, not assumed.
- First-login mechanism: a small, dedicated script + single marker
  file, not a repurposed `scripts/migrate` entry -- keeps migrations'
  existing "manually-run" meaning unchanged for future migration
  authors.
- Git identity: complete the GUI's already-collected, currently-
  discarded `git_name`/`git_email` fields by writing
  `~/.gitconfig.local` during install when provided.
- The target gets a real git checkout (`.git` included in the live
  ISO's repo bake-in, not excluded), not a plain file copy -- confirmed
  this is what `scripts/update`'s own existing test ("moves a detached
  HEAD (post-install baked-in repo checkout) onto main") already
  anticipated, not a new idea bolted on.

## Acceptance tests (written before implementation)

File: `tests/unit/configure-base-system.bats` (extended),
`tests/unit/first-login.bats` (new).

| Test | What it proves |
|---|---|
| `configure-base-system` copies the baked-in repo to `~/Projects/autarchy` on the target and chowns it to the new user | The target has a permanent, correctly-owned repo checkout |
| `configure-base-system` runs `install/link-home apply` as the new user against that copy | Dotfiles exist before first boot, not after a manual step |
| `sddm.service` is enabled alongside the existing base services | A display manager actually starts |
| `configure-base-system` writes `/etc/sddm.conf.d/20-autologin.conf` with the right `User=`/`Session=` | Autologin is actually configured, not just SDDM running |
| `configure-base-system` writes `~/.gitconfig.local` only when both `GIT_NAME`/`GIT_EMAIL` are non-empty, with the right content, never otherwise | The half-built GUI feature is completed correctly and stays opt-in |
| `install/first-login` runs `enable-user-services apply` once and marks a completion marker; a second run is a no-op | The session-dependent step actually happens, exactly once |

Red confirmed: 2026-09-19 · Green confirmed: 2026-09-19

## Tasks

- [x] Branch, tracking doc
- [x] Red: unit tests for every new/changed behavior
- [x] Implement: repo bake-in (`.git` included), `configure-base-system`
      changes (repo copy, link-home, sddm service+autologin,
      gitconfig.local), GUI vars-file field, `install/first-login`,
      `autostart.lua` hook
- [x] Green: `scripts/check`
- [ ] Real hardware verification: full loop, install through to a
      working desktop with zero manual steps
- [ ] Close: `DECISIONS.md`, `docs/omarchy-influences.md`,
      `docs/roadmap.md`, merge to `main`

## Implementation log

### 2026-09-19
- Plan mode: three parallel research passes (this repo's own install/
  config pipeline and `rebuild.md`; D-0026's session-start history;
  Omarchy's actual post-install personalization mechanism, read live
  from its current source). Found the desktop package closure and
  static config files are already fully installed at pacstrap/sync-
  system time (Phase 13/14) -- the real gaps are entirely about
  *enabling/running* things, not installing them: `sddm.service` never
  enabled, no autologin configured, `link-home`/`enable-user-services`
  never run for the new account. Found a real, non-obvious blocker:
  `link-home` stows symlinks pointing at the repo's own path, but the
  installed target has no copy of the repo at all -- confirmed the fix
  (bake `.git` into the live ISO's copy, copy it onto the target) is
  not a new idea but something `scripts/update`'s own test suite
  already anticipated (a test literally named for moving a "post-
  install baked-in repo checkout" off a detached HEAD). Confirmed via
  Omarchy's real source that its own approach mirrors this: nearly all
  personalization happens inside the arch-chroot before first reboot,
  with only session-dependent tasks (enabling user services) deferred
  to a marker-gated first-login hook triggered from the compositor's
  own startup, not a systemd unit -- validated against this dev VM's
  actual Hyprland Lua API (`hl.exec_cmd`, confirmed via `/usr/share/
  hypr/stubs/hl.meta.lua`) rather than assumed. User confirmed three
  decisions via AskUserQuestion: SDDM autologin (yes), first-login
  mechanism (dedicated script, not a repurposed migration), and git
  identity (complete it).
- **Implemented.** `install/configure-base-system` gained four new
  steps between `create_user()` and `enable_services()`: `copy_repo()`
  (`cp -a "$REPO_ROOT" "$TARGET/home/$USERNAME/Projects/autarchy"` +
  chown -- `$REPO_ROOT` is the live ISO's own baked-in copy, now
  including `.git` since `.github/workflows/release-iso.yml`'s rsync no
  longer excludes it), `link_home()` (`arch-chroot ... runuser -u
  $USERNAME -- bash -c 'cd ~/Projects/autarchy && install/link-home
  apply'`), `configure_autologin()` (writes `/etc/sddm.conf.d/
  20-autologin.conf` with `User=$USERNAME`/`Session=hyprland-uwsm` --
  the exact session name confirmed by reading `/usr/share/
  wayland-sessions/hyprland-uwsm.desktop` directly on this dev VM, not
  guessed), and `write_git_identity()` (writes `~/.gitconfig.local`
  only when both `GIT_NAME`/`GIT_EMAIL` are non-empty). `sddm.service`
  added to the existing `SERVICES` array. New `install/first-login`:
  marker-gated (`~/.local/state/autarchy/first-login-done`, matching
  D-0051's marker-family convention), calls `install/enable-user-
  services apply` -- its target script swappable via
  `AUTARCHY_ENABLE_USER_SERVICES_SCRIPT`, matching this repo's
  established `AUTARCHY_*_SCRIPT` override pattern
  (`install-base-system`/`run-guided-install` already do the same).
  `home/hypr/dot-config/hypr/autostart.lua` gained one line,
  `hl.exec_cmd("~/Projects/autarchy/install/first-login")` -- verified
  for real, not just by syntax, by running `Hyprland --verify-config`
  against this dev VM's actual Hyprland install: it parsed clean *and*
  actually executed `first-login`, which created a real
  `~/.local/state/autarchy/first-login-done` marker on this dev VM
  (harmless -- `enable-user-services apply` is a no-op on
  already-enabled units -- and genuine, useful end-to-end proof the
  whole chain works beyond the bats stubs). `gui/installer/state.py`'s
  `vars_file_content()` gained `GIT_NAME=`/`GIT_EMAIL=`, shell-quoted
  via stdlib `shlex.quote()` (not hand-rolled escaping) -- caught, via
  my own first attempt at a test fixture, the exact real bug this
  quoting exists to prevent: an unquoted `GIT_NAME=Alice Example` broke
  the vars file (`source`d as bash) at the space. `tests/acceptance/
  phase-14.bats`'s "excludes .git" test updated to match (`.git` is now
  deliberately included; commented as a Phase 16 change, not silently
  dropped). Also caught by `scripts/check`'s own `identifiers` step:
  `alice@example.com` in two new test fixtures matched the email
  scanner -- fixed by switching to `alice@users.noreply.github.com`,
  already on the allowlist (`scripts/lib/identifiers.bash`), the same
  convention `tests/unit/identifiers.bats` itself already uses for fake
  test emails, rather than expanding the allowlist for this test.
  `scripts/check` green throughout (149 bats tests, up from 142; 5 GUI
  unit tests, up from 4).

## VM → physical hardware notes

- Every script-level behavior is bats-verified against stubs (no real
  disk/chroot needed), and the `autostart.lua`/`first-login` chain was
  additionally verified for real on this dev VM's own live Hyprland
  install (`Hyprland --verify-config` actually executed `first-login`
  and produced a real marker file). What can't be verified here: SDDM
  actually rendering and autologging in on real hardware, the full
  install-to-desktop boot sequence end to end, and whether the
  Alienware's real disk/permissions behave identically to the bats
  stubs' assumptions. Real hardware verification is still the standard
  this project has held to since Phase 13.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated
- [ ] `docs/omarchy-influences.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
