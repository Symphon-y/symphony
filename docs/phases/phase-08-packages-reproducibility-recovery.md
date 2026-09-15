# Phase 08 — Packages, reproducibility, recovery

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude + user |
| **Branch** | `phase/08-packages-reproducibility-recovery` |
| **Started** | 2026-09-15 |
| **Completed** | |

## Goal

Everything scattered across seven phases' worth of ad-hoc manual commands gets
consolidated: a real package-drift audit, an idempotent migration mechanism, one
runbook covering the whole post-first-boot setup, and a backup for the one
genuinely unmitigated single point of failure (the LUKS header).

## Scope

**In scope**
- `scripts/pkg-audit`: package drift in both directions (installed-but-
  undeclared, declared-but-not-installed-at-all) plus a check that every
  foreign/AUR package is declared specifically in `packages/desktop.txt`.
- Fix `phase-01.bats`'s stale "no foreign packages" test.
- `system/services-user.txt` + `install/enable-user-services check|apply`.
- `migrations/` + `scripts/migrate check|apply` (Omarchy-inspired
  timestamped-script + completion-marker pattern), shipped with one real first
  migration (removing `yay-debug`, a real drift item `pkg-audit` found).
- `docs/runbooks/rebuild.md`: the consolidated post-first-boot runbook, plus an
  out-of-repo state inventory.
- LUKS header backup (`cryptsetup luksHeaderBackup`, stored on the Unraid host).
- `tests/acceptance/phase-08.bats`, static only.

**Out of scope**
- `base-install.md`'s disk/LUKS/partition steps — unchanged.
- A real second fresh VM — deferred to whenever actually needed.
- A broader personal-data backup strategy — Phase 9's territory, if it ever
  comes up.
- Any pacman-guard-style mechanism — already REJECTed in Phase 3.
- Automating yay's bootstrap, `gh auth login`, or Claude Code's login — stay
  manual by design.

## Decisions

**Resolved (user, 2026-09-15)**
- Rebuild validation: idempotent re-run on this VM, not a real second VM.
- Backups: LUKS header only, not a broader personal-data strategy.

**Resolved (plan, from Phase 3's research)**
- Migration mechanism: timestamped scripts + completion markers, modeled on
  Omarchy's own pattern; its channel/mirror/pacman-guard infrastructure REJECTed.
- Recorded in `DECISIONS.md` at close-out, starting at D-0050.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-08.bats`, static only — no live session needed
anywhere in this phase.

| What it proves |
|---|
| `scripts/pkg-audit` finds zero drift on the live system |
| `scripts/migrate check` reports nothing pending (once the real migration has run) |
| every unit in `system/services-user.txt` is enabled and active |
| `docs/runbooks/rebuild.md` exists and references real, current commands |

Red confirmed: · Green confirmed:

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-08.bats` written after most of Green (a real
      deviation from the usual order -- logged honestly below); confirmed the
      two migration-gated tests fail for the right reason (real pending drift,
      not a bug), the other two already passed since their mechanisms were
      already built and idempotent-clean on the live system
- [x] `scripts/pkg-audit` + unit tests -- found and fixed 3 real drift items
      (`linux-firmware-intel` undeclared since Phase 5, `diffutils` over-strict
      check design, `yay-debug` an unintended yay-build artifact)
- [x] Fixed `phase-01.bats`'s stale foreign-packages test; removed the now-
      redundant `undeclared_packages` helper (superseded by `pkg-audit`)
- [x] `system/services-user.txt` + `install/enable-user-services` + unit tests
      -- found and fixed a real bug (trailing whitespace from comment-stripped
      lines broke exact-match comparisons)
- [x] `migrations/` + `scripts/migrate` + unit tests + a real first migration
      (removing `yay-debug`)
- [x] `docs/runbooks/rebuild.md`
- [x] Static acceptance tests green except the two migration-gated ones (2/4);
      `scripts/check` green (90/90 unit tests)
- [ ] User: run the yay-debug migration, back up the LUKS header, confirm
      idempotent re-run of the consolidated flow
- [ ] Close: `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md`
- [ ] Merge to `main`

## Implementation log

### 2026-09-15
- Plan researched and approved. One thorough repo-survey agent: read every
  `install/*` script, all of `packages/*.txt`, every phase doc's exact manual
  commands, D-0008/D-0009/D-0017, and the existing package-drift tests. Found:
  no bulk-install/service-enable automation exists at all (every phase typed ad
  hoc commands from tracking docs); no audit script exists standalone (only two
  bats functions, one now stale); the migration pattern was already the
  recorded plan for this phase; out-of-repo state was never inventoried in one
  place, and the LUKS header has no backup at all. User decisions: idempotent
  re-run (not a real second VM) for rebuild validation; LUKS header only for
  backups.
- Branch, tracking doc created.
- Built `scripts/pkg-audit` (both drift directions + AUR-in-desktop.txt check).
  Running it against the real system immediately found three genuine issues
  worth fixing rather than dismissing as test noise:
  - `linux-firmware-intel`: installed explicitly since Phase 5 (an optional dep
    of `gpu-screen-recorder`, per D-0036) but never actually added to
    `packages/desktop.txt` -- a real omission, fixed by declaring it.
  - `diffutils`: declared (Phase 2, for `install/sync-system`'s `cmp` use) but
    present only as a dependency of `mkinitcpio`, not "explicitly installed" --
    this revealed the audit script's own "declared but not installed" check was
    too strict (checking explicit-install status rather than mere presence).
    Fixed the script's semantics: this direction now checks presence via
    `pacman -Qq`, not `pacman -Qqe` -- a declared package satisfied by someone
    else's dependency is not drift.
  - `yay-debug`: an unintended side effect of building yay from source
    (`makepkg` splits off detached debug symbols into their own package) --
    never a deliberate choice, never declared. Not something to silently
    declare and keep; written up as this phase's first real migration instead
    (see below).
  - Also found and fixed a locale/`comm` bug while debugging the above: `comm`
    needs its own invocation under the same collation as the `sort` steps
    feeding it, not just the `sort` steps themselves -- fixed by setting
    `LC_ALL=C` once for the whole script rather than per-`sort`-call.
- Fixed `phase-01.bats`'s stale `"packages: no foreign ... are installed"`
  test (a real invariant only until Phase 4 started deliberately using AUR via
  yay) and merged it with the other package-drift test into one delegate call
  to `scripts/pkg-audit`, removing the now-duplicated `undeclared_packages`
  helper function it used to define.
- Built `system/services-user.txt` (the 6 units this repo enables by hand:
  mako, hypridle, hyprpaper, hyprpolkitagent, waybar, cliphist -- confirmed
  against the live `systemctl --user list-unit-files --state=enabled` output,
  which also showed wireplumber/pipewire/p11-kit-server are already
  preset-enabled by their own packages and correctly don't need listing) +
  `install/enable-user-services check|apply`. Found a real bug while writing
  its unit tests: the comment-stripping parser left trailing whitespace from
  the file's own alignment padding, which broke exact unit-name comparisons
  downstream (`read -r` with `IFS=` doesn't trim it) -- fixed by stripping
  trailing whitespace after stripping comments.
- Built `migrations/` + `scripts/migrate check|apply` (timestamped scripts +
  completion markers under `~/.local/state/autarchy/migrations/`, both
  overridable via env vars for testing). Wrote the mechanism's first real
  migration: removing the `yay-debug` package found by `pkg-audit` above --
  genuinely useful, not a synthetic placeholder, but needs `sudo` internally so
  the user runs it (`scripts/migrate apply`), not Claude.
- `scripts/check` extended to lint `migrations/*.sh` (previously only
  `scripts/`, `install/`, and `dot-local/bin/*` scripts were covered).
- Full unit suite: 90/90 green throughout.
- Wrote `docs/runbooks/rebuild.md` (picking up exactly where `base-install.md`
  ends) and the out-of-repo state inventory table inside it (git identity,
  nvim config, gh/Claude auth, the LUKS header, the SSH jump-host private key --
  the last one was already never on the VM at all, per D-0021).
- **Deviation from the plan's stated order:** wrote `tests/acceptance/
  phase-08.bats` (the Red step) only after most of Green was already built,
  rather than before. Not deliberate -- the drift-detection/mechanism work
  naturally came first while investigating what pkg-audit would even need to
  check, and the formal acceptance file came together at the end. Confirmed
  the result is still honest: the two migration-gated tests fail for a real,
  correct reason (the yay-debug migration is genuinely pending, not yet run),
  not because anything is broken; the other two already passed because their
  mechanisms were already built and verified idempotent-clean against the live
  system before the acceptance file existed to check them formally.

## VM → physical hardware notes

-

## Exit criteria

- [ ] Static acceptance tests pass
- [ ] `scripts/check` green
- [ ] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
