# Decisions

Architectural and UX decisions, and why they were made. This is not a changelog.

Each entry: **Decision · Alternatives considered · Reasoning · Consequences.**
Entries are never deleted; a reversed decision gets a new entry that supersedes it,
and the old entry is marked `Superseded by D-XXXX`.

---

## D-0001 — Arch Linux is the foundation, not a derivative distribution

- **Status:** Accepted (2026-09-12, Phase 0)
- **Decision:** Build on standard Arch Linux. Use native packages and well-supported
  AUR packages; prefer upstream software and configuration.
- **Alternatives considered:**
  - Install Omarchy and customize it — inherits someone else's architecture, package
    choices, and update mechanism.
  - Build a derivative distro (custom ISO/repo) — maintenance burden with no benefit
    for a single-user workstation.
  - NixOS — fully declarative, but a different mental model and ecosystem than the one
    wanted here.
- **Reasoning:** Arch gives direct ownership of every layer while staying
  understandable to an experienced Linux user. The value of this project is the
  system design, not a new distribution.
- **Consequences:** We own upgrades and breakage. Reproducibility must be earned through
  this repository (Phase 8) rather than provided by the distro.

## D-0002 — Develop in a lab VM on Unraid

- **Status:** Accepted (2026-09-12, Phase 0)
- **Decision:** Develop in an x86_64 Arch VM on a remote Unraid server (KVM/libvirt),
  using Unraid VM snapshots as rollback points. The Mac is the control host.
- **Alternatives considered:**
  - Local VM on the Mac — Apple Silicon (M2) would require emulating x86_64 or using
    Arch Linux ARM, neither representative of the eventual workstation.
  - Bare metal immediately — no cheap rollback while the architecture is still forming.
- **Reasoning:** A VM is a laboratory: we can break things, snapshot, rebuild, and
  compare alternatives cheaply.
- **Consequences:** The VM does **not** tell us about:
  - GPU acceleration — likely software rendering unless a GPU is passed through, so
    Hyprland performance and visual feel are not representative.
  - Microcode, firmware quirks, Secure Boot/TPM, power management, suspend, laptop
    hardware, multi-monitor/HiDPI behavior.
  - Real audio and input devices.

  Each phase records VM → hardware notes; Phase 10 handles the move.

## D-0003 — Private GitHub repository as the canonical remote

- **Status:** Accepted (2026-09-12, Phase 0)
- **Decision:** Host this repository as a private GitHub repo.
- **Alternatives considered:**
  - Self-hosted Forgejo/Gitea on Unraid — full ownership, but another service to run
    and back up, and only reachable on the home network.
  - Local-only Git — the VM and future hardware could not clone it.
- **Reasoning:** Reachable from the Mac, the VM, and future hardware; integrates with
  `gh` and GitHub Actions for CI.
- **Consequences:** Repository contents sit on a third-party service, so secrets must
  never be committed (enforced by `.gitignore` and review). Self-hosting can be
  revisited without changing the repo itself.

## D-0004 — Phase lifecycle: plan mode, tracking document, snapshot

- **Status:** Accepted (2026-09-12, Phase 0)
- **Decision:** Work proceeds in numbered phases (`docs/roadmap.md`). Every phase
  starts with its own plan mode, and every plan produces a tracking document in
  `docs/phases/` that records implementation progress. Every VM-changing phase starts
  from a named Unraid snapshot. One Git branch per phase. Full lifecycle in `CLAUDE.md`.
- **Alternatives considered:**
  - One big up-front plan — decisions made before the information exists.
  - Ad-hoc work — produces "a pile of dotfiles" with no reasoning trail.
- **Reasoning:** Plans decided at the right moment, with an auditable record of what
  actually happened versus what was planned.
- **Consequences:** Some documentation overhead per phase. The tracking docs become
  the project history; `DECISIONS.md` stays focused on *why*.

## D-0005 — How engineering principles and TDD apply to an OS/dotfiles project

- **Status:** Accepted (2026-09-12, Phase 0)
- **Decision:** Apply SOLID, Clean Code, DRY, and TDD where applicable, as interpreted
  in the principles table in `CLAUDE.md`. TDD happens at three levels: acceptance tests
  per phase (bats, asserting system state), unit tests for scripts (bats with stubbed
  commands), and static validation (shellcheck, shfmt, compositor/systemd/nvim
  validators).
- **Alternatives considered:**
  - Treat principles as aspirational only — no enforcement, drift over time.
  - Force unit tests on everything, including declarative config and runbooks —
    high cost, little value, and pushes toward needless abstraction.
- **Reasoning:** Most of a workstation is declarative config and system state, not
  application code. The useful form of "test first" is: define the phase's observable
  outcome as executable checks, watch them fail, then build until they pass. Scripts
  are real code and get real unit tests.
- **Consequences:** bats-core, shellcheck, and shfmt become required development tools
  (installed in Phases 1–2). When DRY conflicts with "use the standard primitive",
  the standard primitive wins.

## D-0006 — Claude Code is installed immediately after the base Arch install

- **Status:** Accepted (2026-09-12, Phase 0)
- **Decision:** The user drives Phase 1 (base install) by following a runbook. Claude
  Code is installed in the VM, as the normal user, at the start of Phase 2, before any
  desktop exists. From then on Claude drives inside the VM.
- **Alternatives considered:**
  - Hand off after a minimal Hyprland desktop — more manual work, but the user
    experiences the first desktop decisions first-hand.
  - Claude drives the VM over SSH from the Mac — possible, but splits the workstation's
    own tooling from where it runs.
- **Reasoning:** Minimizes manual typing and puts the agent where the system lives.
  The base install is a text-console job and is best understood hands-on.
- **Consequences:** Claude Code's install method and privilege model (normal user,
  password-prompting sudo, no `NOPASSWD`) are decided in Phase 2 under the security
  model. The repo must be cloneable from the VM by the end of Phase 1.

## D-0007 — Repository layout: config lives with its component; directories on demand

- **Status:** Accepted (2026-09-12, Phase 0)
- **Decision:** One top-level directory per component (e.g. `hypr/`, `waybar/`,
  `shell/`), holding that component's config and tests. Shared tooling lives in
  `scripts/`, `install/`, `packages/`, `tests/`. A directory is created by the phase
  that first needs it.
- **Alternatives considered:**
  - Scaffold the full tree up front — empty placeholders imply decisions not yet made
    (e.g. `waybar/` before the status bar is chosen).
  - Mirror `~/.config` exactly — couples repo layout to the deployment mechanism,
    which is not chosen until Phase 2.
- **Reasoning:** Keeps configuration close to the component it configures, keeps
  components replaceable, and avoids committing to choices prematurely.
- **Consequences:** The deployment mechanism (Phase 2) maps component directories to
  their target locations.
