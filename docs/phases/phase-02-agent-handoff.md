# Phase 02 — Agent Handoff & Developer Bootstrap

| | |
|---|---|
| **Status** | In progress |
| **Driver** | Claude (Mac preparation) → **User** (runbook in the VM console) → Claude (in the VM) |
| **Branch** | `phase/02-agent-handoff` |
| **Started** | 2026-09-13 |
| **Completed** | — |

## Goal

Claude Code runs in the VM as `travis`, installed from Anthropic's GPG-verified release,
logged in, and able to commit and push. Home and system config deploy from the repo with
stow and a copy script, and CI runs static checks and unit tests on every push.

## Scope

**In scope**
- `install/claude-code` (verified native install), `scripts/gist-relay` (login without paste)
- `install/sync-system` + `system/files.txt`; `install/link-home` + `home/`
- `scripts/check` and GitHub Actions CI; tooling packages
- Runbook [`docs/runbooks/agent-handoff.md`](../runbooks/agent-handoff.md); handoff of the driver role

**Out of scope**
- SSH or Remote Control access (console only until the GUI, per the user)
- Any graphical stack (Phase 4); shell and editor configuration (Phase 7)
- Claude Code sandboxing (deferred)

## Decisions

Recorded in `DECISIONS.md` at close-out.

**Resolved (user, 2026-09-13)**
- Console only until the GUI; work inside tmux
- Claude Code: official native binary, verified against the signed release manifest
- Keep the existing `gh` OAuth login (broad-scope risk recorded)
- GNU stow for home config; a root copy script for system files

**Resolved (plan)**
- Login via tmux paste buffer plus a short-lived secret gist relay (short-lived codes only)
- Claude never uses sudo; deny rules for `sudo` and for reading credential files
- `DISABLE_TELEMETRY` and `DISABLE_ERROR_REPORTING` set (Remote Control unavailable while set)
- `home/<component>/` stow packages and `system/files.txt` manifest (refines D-0007 and D-0017)
- CI in an `archlinux:latest` container, `actions/checkout` pinned by commit SHA

**Deferred**
- Bubblewrap sandbox for Claude Code; Remote Control; console font or kmscon (only if needed)

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-02.bats`. `phase-01.bats` runs alongside it as a regression check.

| Group | What it proves |
|---|---|
| tooling | shellcheck, shfmt, stow, tmux, jq, bats, git, gh installed; `scripts/check` passes on the VM |
| system config | installed files match `system/files.txt` (content, mode, root ownership) |
| home config | every file under `home/` is linked; `~/.claude` is a real directory |
| claude code | runs; binary matches its GPG-signed manifest; `claude doctor` passes with auto-updates enabled; settings pin stable channel, telemetry off, deny rules present; authenticated (`claude -p` answers) |
| github | `gh` authenticated; remote reachable; latest CI run on the branch succeeded; no relay gists left |

Red confirmed: _pending (VM, before the runbook)_ · Green confirmed: _pending_

## Tasks

**Mac preparation (Claude)**
- [x] Branch; tracking doc; corrected the "Shift dropped" record (it was typos)
- [x] `sync-system` tests → red (11/11) → implementation → green (11/11); `configure-base-system` refactored onto it (red 1/12 on the changed expectation → green 12/12)
- [x] `link-home` tests → red (6/7) → implementation → green (7/7); `home/tmux`, `home/claude`
- [x] `claude-code` tests → red (12/12) → implementation → green (12/12)
- [x] `gist-relay` tests → red (6/6) → implementation → green (6/6)
- [x] `scripts/check`, CI workflow, tooling packages, `packages/external.md`
- [x] Acceptance tests run on the Mac and fail cleanly, with no errors (50 tests); runbook written
- [ ] Commit; user pushes; CI green on GitHub

**VM (user, following the runbook)**
- [ ] 1. Switch to the branch; red run committed
- [ ] 2–4. Packages, system config check, home links, Claude Code install
- [ ] 5. Login through tmux and the gist relay
- [ ] 6. Green run committed
- [ ] 7. Handoff: Claude in the VM updates `CLAUDE.md` and pushes

## Implementation log

### 2026-09-13
- Research: Claude Code docs (setup, authentication, Remote Control, sandboxing); the
  Anthropic `install.sh` source, which verifies the SHA256 checksum but not the manifest
  signature; the release bucket layout (the `stable` pointer, `manifest.json` with a
  `.sig`); the AUR `claude-code` PKGBUILD; Omarchy's Claude and config-deployment scripts.
- Key constraints found: `claude setup-token` can't start Remote Control sessions, and
  Remote Control needs a full claude.ai login. Logging in from a text console needs a
  URL taken out and a code put back in. The kernel console has no scrollback (removed
  in Linux 5.9), which tmux fills.
- User corrections during planning: Shift is not dropped by the console (earlier cases
  were typos); Omarchy's Claude desktop-app installer is optional, and Omarchy does
  integrate the Claude Code CLI (theme sync, usage panel).
- Mac preparation, all test-first. Red confirmed for every new suite before its script
  existed. In `link-home`, "apply fails when stow reports a conflict" passed during red
  because a missing script also fails; it became meaningful once the script existed.
  Final `scripts/check`: shellcheck, shfmt, and JSON syntax clean; **55/55 unit tests**.
- `install/sync-system` now owns the root-owned file list (`system/files.txt`);
  `configure-base-system` calls it twice: before building UKIs, and again after
  `bootctl install`, which may write its own `loader.conf`.
- **Deviation:** `.editorconfig` gained a `[{scripts,install}/*]` section. shfmt only
  applied `switch_case_indent` to `*.sh`, `*.bash`, and `*.bats`, and the extensionless
  scripts are the first with `case` statements. Fixing the config keeps one formatting
  rule, rather than reformatting the scripts differently.
- `jq` installed on the Mac with Homebrew, alongside the earlier test tooling: the
  `claude-code` unit tests parse a real manifest fixture with it.
- The acceptance suite on the Mac (50 tests) fails cleanly. Some Phase 2 checks pass
  there because the Mac already has Claude Code and `gh`, which usefully confirms that
  the `claude doctor` "Auto-updates … enabled" pattern matches the real output. The
  shared `as_root` helper moved to `tests/helpers/system.bash`.
- **Bug caught by CI (first run, `486322d`, run 34758062316): `cmp: command not found`.**
  6 of 55 unit tests failed in the `archlinux:latest` container. `install/sync-system`
  uses `cmp` from `diffutils`, which is not a dependency of `base` (checked against the
  Arch package database). So the VM could fail the same way. Fix: declare `diffutils`
  in `packages/tooling.txt`, not swap `cmp` for a workaround. That is the one list both
  CI and the VM install; `sync-system` is repo tooling, and pacstrap uses every list.
  The runbook installs declared packages (step 2) before `sync-system` first runs
  (step 3). This is exactly the kind of
  undeclared dependency CI in a clean container exists to catch.
- **Second CI run (`116c29c`, run 34758293997): 54/55.** The `cmp` fix worked. The
  remaining failure was a test bug: "check run as root reports files not owned by root"
  assumed a non-root runner. In the CI container the tests run as real root, so
  installed files really are root-owned and `check` correctly said `in sync`. The test
  now hands the file to uid 65534 when it runs as real root, so it checks the same
  thing on any runner. The script itself was right.
- **Third CI run (`112bcc7`, run 34758550075): 55/55 green.**
- **Red on the VM** (`748af22`): 50 tests; phase-01 36/36 still ok; phase-02 11 not ok,
  3 ok. The 3 are expected: `gh` was already logged in, CI is green, and no relay gists
  exist. No load or syntax errors.
- **Real finding from the red run — `mode: /efi/loader/loader.conf` drift.** The ESP is
  vfat, so file modes come from the mount options (`fmask=0077`), not the file. The
  manifest's `0644` could never match, and `apply` could fail trying to set it. Fix,
  test-first: a manifest mode of `-` means "no per-file permissions: don't check or set
  a mode". Owner checking still applies. The user was asked to pause before runbook
  step 3 until the fix passes CI.

## VM → physical hardware notes

- With a GUI terminal, tmux is optional and the gist relay is unnecessary (normal paste).
- Revisit the `gh` token scope and storage when a keyring exists.
- Revisit telemetry variables if Remote Control becomes useful.

## Exit criteria

- [ ] Acceptance tests green on the VM (phase-01 + phase-02)
- [ ] `scripts/check` green on the Mac, on the VM, and in CI
- [ ] Claude Code in the VM has committed and pushed the `CLAUDE.md` handoff
- [ ] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
