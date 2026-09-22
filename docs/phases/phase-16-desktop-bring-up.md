# Phase 16 — Fully automated desktop bring-up

| | |
|---|---|
| **Status** | Complete (2026-09-21; one unattended fresh install from an ISO with the first-login fix still owed, on a second machine) |
| **Driver** | Claude + user |
| **Branch** | `phase/16-desktop-bring-up` |
| **Started** | 2026-09-18 |
| **Completed** | 2026-09-21 |

## Goal

Reboot after a fresh install and land directly in a fully working,
personalized Hyprland desktop -- notifications, idle/lock, wallpaper,
polkit agent, status bar, clipboard history all present -- with zero
manual steps, closing `rebuild.md`'s remaining automatable scope.

**Revised 2026-09-20 (after `2026.09.19-test1` reached the desktop on real
hardware):** the installed machine is also *self-contained* -- no checkout of
this repo, no `~/Projects`, the user's XDG directories in place. See the
2026-09-20 log entry and D-0067 for why.

## Scope

**In scope**
- Enable `sddm.service` and configure SDDM autologin at install time
  (`install/configure-base-system`).
- Give the installed target the OS content it needs (`home/ install/
  migrations/ packages/ scripts/ system/`) as a root-owned payload at
  `/usr/local/share/symphony/current` -- **not** a git checkout, and nothing
  under the user's home (revised 2026-09-20; the original plan copied a
  real checkout to `~/Projects/symphony`).
- Run `install/link-home apply` for the new user at install time, from the payload.
- Create the user's XDG directories (Documents, Downloads, Music, Pictures,
  Videos; never `~/Projects`) via `system/xdg/user-dirs.defaults`.
- Create snapper's root config and enable the root-scope maintenance timers
  (`system/services-root.txt`) at install time, so `scripts/update`'s
  pre-update snapshot has a config to snapshot with.
- Render the palette (matugen) on first login, before any themed service starts.
- Write `~/.gitconfig.local` from the GUI installer's already-collected
  (and currently discarded) `git_name`/`git_email` fields, if provided.
- A new, dedicated first-login mechanism (marker-gated script, triggered
  once from Hyprland's own `autostart.lua`) for the one thing that
  genuinely needs a live session: `install/enable-user-services apply`.

**Out of scope**
- Adding a git-identity prompt to the terminal fallback
  (`symphony-install`) -- stays the narrower "collector of last resort."
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
- ~~The target gets a real git checkout at `~/Projects/symphony`~~ --
  **superseded 2026-09-20** (user: "the iso doesn't need an installed
  machine's copy of our repo -- Windows doesn't have a 'windows os' repo
  anywhere either"). The target gets a root-owned payload instead; `.git`
  is back to being excluded from the ISO bake-in (Phase 14's original
  behavior). Updating such a machine (`scripts/update` is git-based today)
  is Phase 17's job, not this phase's.
- Payload location `/usr/local/share/symphony/current`, a **real directory
  at a fixed path**, not a symlink to a versioned directory. Found by
  spiking it: GNU stow records each symlink by the *resolved* path of its
  stow dir, so `releases/<tag>/` behind a `current` symlink makes every
  restow after an update abort ("existing target is not owned by stow").
  Replacing the directory's contents at the same physical path (what an
  update will do, keeping the old one as `previous/`) restows cleanly --
  verified for real in an Arch container.
- No `.git`, `iso/`, `tests/`, `gui/`, `docs/`, and never the GUI's vars
  file in the payload: an allow-list of directories, not an exclude list.
- XDG dirs: our own root-owned `/etc/xdg/user-dirs.defaults` (five dirs).
  Researched: `xdg-user-dirs` 0.20's stock defaults also create `Projects`
  (confirmed against the real package), so installing the package alone
  would recreate the folder this phase removes. Omarchy's approach
  (create everything, then `rmdir` the unwanted) was noted and not taken.
- Snapper config is written straight from snapper's shipped template with
  the settings `base-install.md` already applied by hand, not via
  `snapper create-config` (which insists on making its own `/.snapshots`
  subvolume; `@snapshots` is already mounted there).
- `.bash_profile` and `.bash_logout` from `/etc/skel` are kept; only the
  one file that actually conflicts with a stow package (`.bashrc`) is removed.

## Acceptance tests (written before implementation)

Revised 2026-09-20: this table replaces the original one, whose "copies the
baked-in repo to `~/Projects/symphony`" row went away with that design; the
rows for the self-contained layout and the gaps a review of the branch found
were added.

Files: `tests/unit/configure-base-system.bats`, `first-login.bats`,
`enable-root-services.bats`, `enable-user-services.bats` (all extended),
`tests/acceptance/phase-16.bats` (new, static properties).

| Test | What it proves |
|---|---|
| `configure-base-system` installs a payload at `/usr/local/share/symphony/current` with no `.git`/`iso`/`tests`/`gui`, no `~/Projects`, chowned root | The installed machine is self-contained and the user can't modify the OS layer |
| payload `VERSION` records the live release (or `unreleased`); re-running replaces rather than nests | The payload's identity is known to a later updater; re-run safe |
| `configure-base-system` runs `install/link-home apply` as the new user from the payload | Dotfiles exist before first boot, not after a manual step |
| XDG dirs created via `xdg-user-dirs-update` (as the user, `HOME` set, `LC_ALL=C`) before link-home | `~/Documents` etc. exist; `Projects` never does |
| only `.bashrc` is removed from skel before stow | Login shells (SSH/TTY) still source `.bashrc` |
| snapper root config written from the template (`TIMELINE_CREATE=no`, limits 10), `.snapshots` mode 750, `snapper-cleanup.timer` enabled; missing template fails clearly | `scripts/update`'s pre-update snapshot has a config to use |
| root maintenance timers enabled via `enable-root-services apply --root` | reflector / btrfs-scrub / `pacman -F` timers actually run on a fresh install |
| `enable-user-services apply` continues past a failing unit, then fails | One flaky unit can't leave the rest never enabled |
| `first-login`: theme rendered before services start; services verified (bounded retry) before the marker; no marker on render or verify failure | A login where something failed retries on the next one instead of being marked done |
| git identity is double-quoted with `\` and `"` escaped | A name with quotes/`#` can't corrupt `~/.gitconfig.local` |
| `sddm.service` enabled; `20-autologin.conf` correct; first-login run once and marked (original rows, unchanged) | A display manager starts and logs in; the session-dependent step happens once |
| acceptance: XDG defaults list exactly five dirs, registered in `system/files.txt`; `xdg-user-dirs` in `packages/`; nothing shipped references `~/Projects/symphony`; `.git` not baked into the ISO; installer and `autostart.lua` agree on the payload path | Repo-level guarantees the unit tests can't see |

Red confirmed: 2026-09-18 (original) and 2026-09-20 (revised set: 24 tests
failed before implementation, each for its missing behavior) ·
Green confirmed: 2026-09-20 (`scripts/check` green; `phase-16.bats` 6/6)

## Tasks

- [x] Branch, tracking doc
- [x] Red: unit tests for every new/changed behavior
- [x] Implement (original): `configure-base-system` (link-home, sddm
      service+autologin, gitconfig.local), GUI vars-file field,
      `install/first-login`, `autostart.lua` hook
- [x] Real hardware, round 1 (`2026.09.19-test1`): install through to a
      working desktop reached (user-confirmed 2026-09-20)
- [x] Revise scope: self-contained payload instead of a `~/Projects` checkout
- [x] Red (revised): 24 failing tests written first
- [x] Implement (revised): payload, XDG dirs, `.bashrc`-only skel removal,
      snapper config, root timers (`enable-root-services --root`),
      user-services keep-going, first-login theme render + verify,
      gitconfig escaping, `autostart.lua` path, `.git` bake-in reverted
- [x] Green: `scripts/check`, `tests/acceptance/phase-16.bats`
- [x] Real hardware round 2 (`local-5c8bcf1`, the Alienware): `ls ~` shows only
      the five XDG dirs, the payload is root-owned with `VERSION`, links point
      into it, snapper's root config works (`snapper -c root create` used by
      dev-deploy), SDDM autologs in -- and the desktop was bare, because
      `first-login` never ran (Hyprland ate the `[ -x ]` guard; fixed, see log).
      After deploying the fix and running `first-login` once: themed, bar up,
      all seven user units enabled and active, marker written.
- [ ] **Owed, on a second machine:** one unattended fresh install from an ISO
      that carries the fix, landing on the themed desktop with nothing typed.
      The Alienware is the dev seat and is not reinstalled.
- [x] Close: `DECISIONS.md` (D-0067), `docs/omarchy-influences.md`,
      `docs/roadmap.md`, `README.md` status refresh, merge to `main`
      (together with Phase 17 -- its branch carries this phase's later commits)

## Implementation log

### 2026-09-18
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
  (`cp -a "$REPO_ROOT" "$TARGET/home/$USERNAME/Projects/symphony"` +
  chown -- `$REPO_ROOT` is the live ISO's own baked-in copy, now
  including `.git` since `.github/workflows/release-iso.yml`'s rsync no
  longer excludes it), `link_home()` (`arch-chroot ... runuser -u
  $USERNAME -- bash -c 'cd ~/Projects/symphony && install/link-home
  apply'`), `configure_autologin()` (writes `/etc/sddm.conf.d/
  20-autologin.conf` with `User=$USERNAME`/`Session=hyprland-uwsm` --
  the exact session name confirmed by reading `/usr/share/
  wayland-sessions/hyprland-uwsm.desktop` directly on this dev VM, not
  guessed), and `write_git_identity()` (writes `~/.gitconfig.local`
  only when both `GIT_NAME`/`GIT_EMAIL` are non-empty). `sddm.service`
  added to the existing `SERVICES` array. New `install/first-login`:
  marker-gated (`~/.local/state/symphony/first-login-done`, matching
  D-0051's marker-family convention), calls `install/enable-user-
  services apply` -- its target script swappable via
  `SYMPHONY_ENABLE_USER_SERVICES_SCRIPT`, matching this repo's
  established `SYMPHONY_*_SCRIPT` override pattern
  (`install-base-system`/`run-guided-install` already do the same).
  `home/hypr/dot-config/hypr/autostart.lua` gained one line,
  `hl.exec_cmd("~/Projects/symphony/install/first-login")` -- verified
  for real, not just by syntax, by running `Hyprland --verify-config`
  against this dev VM's actual Hyprland install: it parsed clean *and*
  actually executed `first-login`, which created a real
  `~/.local/state/symphony/first-login-done` marker on this dev VM
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
  dropped). Also caught by `scripts/check`'s own `identifiers` step: an
  `example.com`-domain fake email in two new test fixtures matched the
  email scanner -- fixed by switching to the `users.noreply.github.com`
  domain, already on the allowlist (`scripts/lib/identifiers.bash`), the
  same convention `tests/unit/identifiers.bats` itself already uses for
  fake test emails, rather than expanding the allowlist for this test.
  (This exact log entry hit the same scanner once already, by literally
  quoting the flagged string -- fixed the same way, described without
  quoting it.)
  `scripts/check` green throughout (149 bats tests, up from 142; 5 GUI
  unit tests, up from 4).
- **Real hardware find: `2026.09.18-test3` installed and booted fine
  but never reached a graphical session.** Root cause: `link_home()`
  runs `install/link-home apply`, which stows `home/bash/dot-bashrc`
  onto `~/.bashrc` -- but `useradd -m` already populates a fresh
  account's home from `/etc/skel`, which ships its own `.bashrc`. GNU
  stow refuses the conflict and aborts its entire combined call
  (reproduced live). Under `set -Eeuo pipefail`, that killed
  `configure-base-system` right there, before `enable_services()`
  (`sddm.service`) ever ran -- everything earlier (partition, LUKS,
  pacstrap, user, boot loader) had already succeeded, so the machine
  still booted, just to a bare TTY. Fixed by removing the stock skel
  files in `link_home()` right before calling `install/link-home apply`
  -- scoped there, not inside `install/link-home` itself, since that
  script also runs by hand against already-customized machines
  (`rebuild.md`), where the same removal would be destructive. Two
  other theories were investigated and ruled out: a missing `systemctl
  set-default graphical.target` (checked directly -- Arch's `systemd`
  package already ships `default.target -> graphical.target`, no
  override needed) and SDDM's Wayland-mode greeter failing (it does
  fail -- confirmed via `journalctl -u sddm` on this dev VM, 34/34
  boots -- but SDDM's own automatic X11 fallback succeeds every time
  and is exactly how this dev VM's Hyprland session has always
  started; not a blocker, left as-is).

### 2026-09-20
- **Real hardware round 1 confirmed:** `2026.09.19-test1` (the `.bashrc`
  stow-conflict fix) installed on the Alienware and reached the desktop --
  user-confirmed. SDDM autologin, `link-home` and `first-login` work
  end to end on real hardware.
- **Scope changed by the user.** Asked what should happen to
  `~/Projects/symphony`, the answer was that an installed machine needs no
  copy of the repo at all ("Windows doesn't have a 'windows os' repo
  anywhere either"), plus: create common-sense XDG directories, and make
  the repo public so a later updater needs no auth. A review pass over the
  branch (read-only agents, each finding spot-checked against the code)
  had also found gaps a hardware boot alone wouldn't show: the baked copy's
  `.git` plus the workflow's `airootfs` exclude left a permanently dirty
  tree that `scripts/update` refuses to run on; `link_home` deleted
  `.bash_profile` (login shells stop sourcing `.bashrc`); `~/Projects`
  itself ended up root-owned; nothing rendered the matugen theme; no
  snapper config existed, so `scripts/update`'s pre-update snapshot would
  fail; `enable-root-services` was wired to nothing. The payload design
  removes the first and third outright; the rest are fixed individually.
- **Research** (three read-only agents, results cross-checked):
  how Omarchy does it (its current 4.x line moved from a `~/.local/share/
  omarchy` git clone to root-owned packages under `/usr/share/omarchy`,
  which needs its own hosted signed pacman repo -- our REJECT'd
  "custom repo/mirror", so only the layout lessons are taken); Arch/other-OS
  best practice for delivering and updating OS config (versioned, root-owned
  payload, atomic switch, snapshot-before-update; sysupdate's `CurrentSymlink=`
  model); and `xdg-user-dirs` (its 0.20 defaults create `Projects`).
- **Spike found a design flaw in the obvious layout**, before any code:
  `releases/<tag>/` behind a `current` symlink (the sysupdate model) does not
  work with GNU stow -- links are recorded by resolved path, so a restow
  after the switch aborts on "existing target is not owned by stow"
  (reproduced in an Arch container). Fixed path, real directory, contents
  replaced in place, is what works; that is what this phase installs.
- **Implemented** (red first: 24 new/changed tests failed, then green;
  `scripts/check` green -- shellcheck, shfmt, all unit tests):
  `install/configure-base-system` (`install_payload`, `create_xdg_dirs`,
  `.bashrc`-only `link_home`, `configure_snapper`, `enable_root_services`,
  quoted+escaped `write_git_identity`, `snapper-cleanup.timer`);
  `install/enable-root-services apply --root DIR`; `install/enable-user-
  services apply` no longer stops at the first failing unit;
  `install/first-login` renders the theme first and verifies (5 tries, 2s
  apart) before writing its marker; `system/xdg/user-dirs.defaults` +
  `system/files.txt` + `xdg-user-dirs` in `packages/desktop.txt`;
  `autostart.lua` calls the payload path behind an `-x` guard (a dev
  checkout, where the services are already enabled, silently skips it);
  `.git` is excluded from the ISO bake-in again (`release-iso.yml`,
  `phase-14.bats` back to their `main` versions).
- **Verified for real, not just against stubs**, in an Arch container:
  the real `xdg-user-dirs-update` with our defaults creates exactly the five
  directories and no `Projects` (the stock defaults do create it);
  `link-home apply`/`check` run as an unprivileged user from a root-owned
  payload, are idempotent, cannot modify the payload, and still work after
  the payload directory is replaced at the same path (the shape an update
  will take).
- **Known, deliberate gap until Phase 17:** `scripts/update` is git-based, so
  it cannot update a payload-only machine yet. Also unverified here:
  snapper's config on real Btrfs (only the template handling is tested), the
  real chroot behavior of `xdg-user-dirs-update` (`HOME` handling under
  `runuser`), and whether `xdg-user-dirs.service` runs under uwsm -- all
  covered by hardware round 2.
- Pre-existing, unrelated: `tests/acceptance/phase-14.bats` "symphony-
  bootstrap is fully retired" fails on this branch's HEAD too (it flags
  `docs/roadmap.md`); acceptance tests aren't part of CI's `scripts/check`.

- **Local ISO builds** (user: skip the 20-40 minute CI round trip and burn
  straight to USB). `scripts/build-iso` runs the release workflow's steps in a
  privileged Arch container on the dev machine -- from a git bundle streamed in,
  not a bind mount of the working tree, because a Windows checkout has CRLF
  endings, flattened symlinks and no file modes that would otherwise ship in the
  ISO -- and `docker cp`s the result out. First real build of `5b1d194`: 11m31s,
  2.9 GB, and it got through `git archive`'s pathspec exclude, the offline repo
  and mkarchiso first time. The one bug only the real host could show: a blanket
  `MSYS_NO_PATHCONV=1` stopped Git Bash translating `/c/Users/...` for native
  `git.exe`; scoped to the container-engine calls now. `iso/write-usb.ps1` is the
  Windows raw-write counterpart of `dd` (USB-only, refuses the system disk, typed
  confirmation, checksum before and read-back after); its write/verify loops were
  tested against a scratch file and its refusals against fake disks -- the raw
  `\\.\PhysicalDriveN` write itself is first exercised on real hardware.
- **Hardware round 2, first result:** the install stopped in `sgdisk` ("could not
  create partition 2 ... unable to set partition 2's name to cryptswap"). Cause:
  a malformed hibernation swap size typed on the Disk page -- user error, not a
  code defect -- but the error names nothing about the size. Recorded as a backlog
  item (validate the swap size in the GUI, the terminal fallback and
  `install-base-system`'s preflight) rather than fixed here.

### 2026-09-20 (round 2, from the machine itself: first-login never ran)
- **Driver seat moved.** Claude Code now runs locally on the Alienware
  (`alien`, installed from `local-5c8bcf1`) with the same no-`sudo` rule, so
  the machine's own journal and files are read directly instead of relayed.
- **The desktop was up but not brought up.** `ls ~` was correct (five XDG dirs,
  no `Projects`), the payload was root-owned with `VERSION`, `link-home` had
  linked everything -- and yet no theme, no bar, every user service
  `disabled`, no `~/.config/{fuzzel,mako}`, no `colors.css`, no
  `first-login-done` marker. Hyprland's own log had the cause on every login:
  `[executor] Executing  && /usr/local/share/symphony/current/install/first-login`
  followed by `Applied rule arguments for exec`. Hyprland reads a leading
  `[...]` on any exec command as its *rule block* and strips it, so the
  `[ -x path ] && path` guard added after the original verification (which
  had tested the bracket-free form) handed the shell a syntax error, silently.
  This also answers Phase 17's open question of why `fuzzel.ini` was never
  rendered on this machine, and why the user saw "no way to connect from the
  GUI" -- there was no bar.
- **Fixed, red first:** `tests/acceptance/phase-16.bats` now refuses any
  `exec_cmd("[` in the Hyprland Lua config; `autostart.lua` uses `test -x`.
- **Also fixed:** `tests/unit/network-watch.bats` "without notify-send" failed
  on this machine because `PATH="$bin:$PATH"` fell through to the real
  `/usr/bin/notify-send` (present on every installed symphony machine, absent
  only in CI's container); the test now gives the script a private PATH.
- Round 2's remaining checks (snapper on real Btrfs, `xdg-user-dirs-update`
  under `runuser`, SDDM autologin, `first-login` on a fresh install) are
  proven by the next locally built ISO; until then the fix is exercised here
  by deploying the checkout over the payload (`docs/runbooks/dev-deploy.md`).

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

- [x] All acceptance tests pass (full suite 204/204 on the Alienware, 2026-09-21)
- [x] Static checks pass (`scripts/check`, 266 unit tests)
- [x] `DECISIONS.md` updated (D-0067)
- [x] `docs/omarchy-influences.md` updated (login entry: autologin adopted)
- [x] `docs/roadmap.md` status updated
- [x] Branch merged to `main` (via `phase/17-wifi-network-bar`)
