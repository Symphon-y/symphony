# Phase 07 — Developer environment

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude |
| **Branch** | `phase/07-developer-environment` |
| **Started** | 2026-09-14 |
| **Completed** | 2026-09-14 |

## Goal

The machine becomes one the user actually wants to write code on day to day: a
configured interactive shell and prompt, a version manager, rootless containers, and
a real git identity. Neovim is deliberately *not* part of this: the user's own
pre-existing personal config is used as-is, outside this repo's ownership.

## Scope

**In scope**
- Packages (all official `extra`, verified via `pacman -Si`): `starship`, `mise`,
  `eza`, `zoxide`, `fzf`, `bat`, `podman`, `podman-compose`, `podman-docker`. Added
  to `packages/tooling.txt`.
- `home/bash/dot-bashrc`, `home/starship/dot-config/starship.toml`,
  `home/git/dot-gitconfig`.
- `~/.config/nvim` cloned directly from `github.com/Symphon-y/config.nvim` — not a
  `home/` stow package; documented in `packages/external.md`.
- Rootless Podman verified working with zero extra privilege setup (subuid/subgid
  already allocated).
- `tests/acceptance/phase-07.bats`, static only.

**Out of scope**
- Any curated/packaged Neovim distribution — rejected; the user's own config is used
  as-is.
- Omarchy's lazy-install-wrapper script itself — pattern noted, not built without a
  concrete tool to wrap.
- Docker-group-style guardrail scripting — moot under rootless Podman.
- gh CLI config/auth changes — already done (Phase 2).

## Decisions

**Resolved (user, 2026-09-14)**
- Shell: bash.
- Neovim: not packaged by symphony; user's own `config.nvim` cloned directly,
  out of this repo's ownership.
- Containers: rootless Podman, not Docker.
- Git identity: set globally now (`user.name = Symphon-y`; email kept as whatever
  was already configured on the VM -- see the implementation log; the value itself
  lives in `~/.gitconfig.local`, untracked, per D-0022).

**Resolved (plan, low-stakes/reversible, not asked)**
- Prompt: Starship, Omarchy's minimal format adapted.
- Version manager: mise, package + shell activation only; lazy-install-wrapper
  pattern noted, not built.
- Shell ergonomics: eza/zoxide/fzf/bat aliases.
- git config defaults: Omarchy's shipped defaults adopted near-verbatim, except
  `init.defaultBranch = main` (not `master`).
- Recorded in `DECISIONS.md` at close-out, starting at D-0043.

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-07.bats`, static only — no live Hyprland session
needed anywhere in this phase.

| What it proves |
|---|
| Packages declared+installed; `home/bash`, `home/starship`, `home/git` linked |
| `.bashrc` is valid bash syntax; starship/mise/zoxide activation lines present |
| Starship config renders (`starship --version`, `starship config` roundtrip) |
| git global identity/config set as expected |
| `~/.config/nvim` is a real git repo pointed at the right remote; `nvim --headless` starts cleanly |
| Rootless Podman actually runs a container with no group membership |

Red confirmed: · Green confirmed:

## Tasks

- [x] Branch, tracking doc
- [x] Red: `tests/acceptance/phase-07.bats`; confirmed 7/8 failing (1 passed
      trivially -- `nvim --headless` with no config yet -- meaningful once the real
      config is cloned), no load/syntax errors
- [x] `packages/tooling.txt` additions, verified against the live pacman database
      (all official `extra`, no AUR needed)
- [x] `home/bash/dot-bashrc`, `home/starship/dot-config/starship.toml`,
      `home/git/dot-gitconfig`
- [x] Clone `~/.config/nvim`; `packages/external.md` entry
- [x] Found and fixed a real, previously-undiscovered bug in `install/link-home`:
      Phase 6's `wallpaper-set` intentionally repoints `current.png` outside the
      repo, which stow (correctly) refuses to restow over -- but since `apply()`
      stows every package in one combined call, that single conflict aborted
      *every* package's linking, not just hyprpaper's. Fixed with a targeted
      `--ignore='current\.png$'` plus an explicit bootstrap step (seed the symlink
      by hand if absent, since stow will no longer create it on a fresh checkout).
      Updated the one unit test asserting the exact stow command line.
- [x] Extended `scripts/check` to shellcheck/shfmt `home/bash/dot-bashrc` (a real
      bash script that wasn't covered by its existing dot-local/bin-only glob)
- [x] Discovered the VM's global git config already existed (`user.name=Symphon-y`,
      a real email already set, gh's own credential-helper setup) -- not documented
      anywhere, presumably from `gh auth login`'s git integration. Confirmed with
      the user rather than overwriting: kept the existing email (now in
      `~/.gitconfig.local`, untracked -- see the D-0022 incident below), folded the
      existing credential blocks into the tracked `dot-gitconfig` so a
      fresh rebuild reproduces the same working state.
- [x] Static acceptance tests green (6/8 -- the two package-gated tests need the
      user's install); `scripts/check` green; full suite re-run, no regressions in
      any prior phase
- [x] User: installed packages (all 9 confirmed via `pacman -Qi`); full acceptance
      suite re-run: 8/8 green for Phase 7 (including the real Podman
      `run --rm docker.io/library/hello-world` smoke test), no regressions
      anywhere else; user visually confirmed the new prompt and eza-backed
      `ls`/`ll`/`la`/`lt`
- [x] Close: `DECISIONS.md` (D-0043–D-0049), `docs/omarchy-influences.md` (all four
      Phase 7 entries filled in), `docs/roadmap.md`
- [x] Merge to `main`

## Post-merge follow-up (not this phase's scope)

- Merging the phase branch into `main` briefly broke `~/.gitconfig` (a stow
  symlink into this repo's own `home/git/dot-gitconfig`, which didn't exist on
  `main` until the merge landed): checking out `main` mid-merge left the symlink
  dangling, so `git pull`/commit lost the `gh`-backed credential helper and the
  repo's own identity. Worked around with an explicit `git -c user.name=... -c
  user.email=...` for the one merge commit; the symlink self-healed the moment
  the merge completed and the file existed again. Not a bug to fix -- just a
  real bootstrapping quirk of a repo that stows its own tooling's config, worth
  remembering if a future phase ever needs to script cross-branch operations
  instead of doing them by hand.

## Implementation log

### 2026-09-14
- Plan researched and approved. Two research passes: repo-state survey (confirmed
  shell/prompt/nvim-config/mise/git-identity as clean gaps) and a deep Omarchy
  source read (bashrc/bash/* structure, starship.toml, omarchy-nvim's actual
  LazyVim-starter shape, omarchy-mise-install's wrapper script, docker.sh's
  reasoning plus a live unmerged rootless-Podman migration PR, config/git/config's
  shipped defaults). User decisions: bash, personal nvim config decoupled entirely,
  rootless Podman, global git identity set now.
- Confirmed on this VM before committing to the container-engine plan: `travis`
  already has subuid/subgid ranges allocated (`/etc/subuid`/`/etc/subgid`:
  `travis:100000:65536`), so rootless Podman needs no extra privilege setup at all.
- Confirmed `github.com/Symphon-y/config.nvim` is public, default branch `master`,
  reachable without auth.
- Branch, tracking doc created. Red confirmed: 7/8 failing cleanly.
- Discovered the VM already had a real global git config (`user.name=Symphon-y`, a
  real email, gh's credential-helper setup) that the earlier repo survey had missed
  (it only checked for a *tracked* `~/.gitconfig` in `home/`, not the live untracked
  file). Asked the user which email to keep rather than overwriting silently; kept
  the existing one. `home/git/dot-gitconfig` folds in the credential-helper config
  and Omarchy's adopted git defaults; **identity itself was first baked directly
  into that tracked file** -- immediately caught by CI's `check-identifiers`
  (D-0022), exactly as designed. Fixed properly rather than working around the
  scanner: split into `[include] path = ~/.gitconfig.local` in the tracked file,
  with the real `[user]` block living only in that untracked, machine-local file
  (git resolves includes transparently for normal config reads; `--global` alone
  doesn't auto-follow includes, `--includes` does -- relevant only for how the
  acceptance test itself queries it, not for real git usage). Also had to fix the
  acceptance test, which had made the same mistake (asserting the literal email).
- Wrote `home/bash/dot-bashrc`, `home/starship/dot-config/starship.toml`,
  `packages/tooling.txt` additions, cloned `~/.config/nvim`, added the
  `packages/external.md` entry.
- Verified the shell ergonomics tool choices (eza/zoxide/fzf/bat) and mise/starship
  package names against the live pacman database before writing anything that
  depends on them -- all confirmed official `extra`, no AUR needed.
- Confirmed rootless Podman needs no privilege setup on this VM at all: `travis`
  already has subuid/subgid ranges from Arch's default `useradd` behavior
  (`/etc/subuid`/`/etc/subgid`: `travis:100000:65536`).
- Removed the two stock Arch skel files (`~/.bashrc`, `~/.gitconfig`) before
  stowing -- their useful content (color aliases; the existing git identity and
  credential setup) was already folded into the new tracked versions first.
- Ran `install/link-home apply` and hit a real, previously-undiscovered bug: Phase
  6's `wallpaper-set` script deliberately repoints `current.png` to an absolute
  path outside the repo (by design, so the palette source can be any image
  anywhere) -- stow correctly refuses to restow over a target it no longer owns,
  but `install/link-home apply` stows every package in one combined `stow` call,
  so that single conflict aborted *every* package's linking, not just hyprpaper's.
  This had been silently waiting since Phase 6's own wallpaper-set test run; only
  surfaced now because Phase 7 is the first phase since to re-run `apply`.
  Fixed with `--ignore='current\.png$'` (tested a `.stow-local-ignore` file first;
  it didn't take effect for reasons not fully run down, the documented `--ignore`
  CLI flag worked immediately) plus an explicit bootstrap step in `apply()` itself
  (seed the symlink by hand if absent, since stow will no longer create it on a
  fresh checkout). Updated the one unit test asserting the exact stow command line
  to match.
- Extended `scripts/check`'s linted-files list to include `home/bash/dot-bashrc`
  (previously only `dot-local/bin/*` scripts were covered; this is a real bash
  script too, just sourced rather than executed) -- added a
  `# shellcheck shell=bash` directive to fix the one real finding (SC2148, unknown
  target shell for a file with no shebang).
- Static acceptance tests: 6/8 green (the two package-gated tests -- `packages:` and
  `prompt:`/`containers:` -- correctly still fail, nothing installed yet). Full
  suite re-run across every phase: no regressions.
- Waiting on the user: install `packages/tooling.txt`'s new entries, then confirm
  the interactive shell/prompt looks right in a real terminal.
- **User confirmed the D-0022 identifier leak fix should be handled by rewriting
  history**, not left as a forward-only patch. Squashed the branch to one clean
  commit (identity split into `[include] path = ~/.gitconfig.local` from the
  start) and force-pushed with `--force-with-lease` guarded to the exact known
  prior remote SHA -- safe here since the branch was brand new, unmerged, and
  single-developer. CI re-confirmed green on the rewritten history.
- **User installed all 9 new packages.** Full acceptance suite re-run: Phase 7's
  own tests 8/8 green, including the real proof-of-work tests this phase's
  verification section called for -- `podman run --rm
  docker.io/library/hello-world` actually runs a container with `rootless=true`
  and no `docker` group in `groups`' output, and `nvim --headless "+qa"` starts
  cleanly against the user's real cloned config. No regressions in any other
  phase's tests (the only other failures are the same pre-existing
  sudo-requires-a-tty and pre-Phase-4 AUR-policy gaps seen since Phase 6).
- User's visual confirmation: the Starship prompt renders, and `ls`/`ll`/`la`/`lt`
  are visibly eza-backed ("looks different in a good way").

## VM → physical hardware notes

-

## Exit criteria

- [x] Static acceptance tests pass
- [x] `scripts/check` green
- [x] `DECISIONS.md`, `docs/omarchy-influences.md`, `docs/roadmap.md` updated
- [ ] Branch merged to `main`
