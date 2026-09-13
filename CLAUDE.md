# autarchy — Working Agreement for Claude

autarchy is an individually opinionated Arch Linux workstation: **Arch Linux + one
person's system design**. Omarchy is a source of ideas, never a specification.
Never install Omarchy or turn this system into an Omarchy installation.

Omarchy classifications (`docs/omarchy-influences.md`) apply to its ideas and
implementations. **REJECT is final.** Never write "reject for now". **DEFER** is the only
class that can be revisited, and a deferred idea is always built our own way, never with
Omarchy's code or packages.

Read `README.md` for the philosophy, `DECISIONS.md` for why things are the way they
are, and `docs/roadmap.md` for where we are.

## Current driver

**The user drives the VM** until Claude Code is installed inside Arch (end of
Phase 1 / start of Phase 2, see D-0006). Until then Claude writes runbooks, tests,
and docs on the Mac; the user executes commands in the VM. Do not SSH into or
modify the VM unless the user explicitly asks.

Update this section when the handoff happens.

## Standing orders

### 1. Every phase gets its own plan mode

1. **Plan mode** — research the phase's area (including how Omarchy approaches it —
   read the source, never install it), ask the user about subjective or
   user-owned decisions, write the plan.
2. **Tracking doc** — on approval, record the plan as
   `docs/phases/phase-NN-<slug>.md` from `docs/phases/_template.md`. That file is the
   single record of the phase's progress; keep it current while implementing.
3. **Recovery** — hypervisor snapshots are not part of the lifecycle (D-0008). Recovery
   relies on the system itself (snapper snapshots, fallback kernel, ISO chroot) and on
   rebuilding from this repo. Never make a plan depend on Unraid snapshots.
4. **Red** — write the phase's acceptance tests first and confirm they fail.
5. **Green** — implement task by task, ticking the checklist and logging deviations.
6. **Close** — update `DECISIONS.md`, `docs/omarchy-influences.md`, the VM → hardware
   notes, and `docs/roadmap.md`; all tests pass; mark the phase Complete; merge.

Git flow: one branch per phase (`phase/NN-slug`), small commits, merge to `main` at
phase exit.

### 2. Engineering principles (where applicable)

| Principle | Meaning in this repo |
|---|---|
| **S**ingle responsibility | One component per directory; one script does one job. |
| **O**pen/closed | Extend through drop-ins (Hyprland `source =`, systemd drop-ins, `conf.d/`) rather than editing core files. Machine-specific settings live in drop-ins. |
| **L**iskov substitution | A replaceable component satisfies its role's contract (e.g. any terminal behind the terminal role supports `-e <cmd>`). Prefer existing standards (xdg-terminal-exec, xdg-mime) over custom wrappers. |
| **I**nterface segregation | Many small scripts with narrow jobs, not one monolithic CLI. |
| **D**ependency inversion | Keybindings and menus call *roles* (`$terminal`, `$launcher`), never hardcoded executables. |
| Clean Code | Clear names, small functions, `set -euo pipefail`, comments explain *why*, shellcheck-clean. |
| DRY | Each piece of *knowledge* has one home (package lists, palette, role definitions). Similar-looking text is not automatically duplication. "No custom abstraction when a standard primitive suffices" beats DRY. |
| TDD | **Acceptance:** `tests/acceptance/phase-NN.bats` asserts system state. **Unit:** bats tests with stubbed commands for every script in `scripts/` and `install/`. **Static:** `shellcheck`, `shfmt -d`, `Hyprland --verify-config`, `systemd-analyze verify`, headless nvim startup. |
| Where not applicable | Manual runbooks get acceptance checks, not unit tests. Declarative config gets validators, not mocks. Pure documentation gets no tests. |

### 3. Project rules that are easy to forget

- Every important choice gets a `DECISIONS.md` entry (Decision · Alternatives ·
  Reasoning · Consequences). It is not a changelog.
- For meaningful decisions: explain the problem, give options, recommend one, say when
  it is subjective, then implement and document.
- No `curl | bash` without inspecting the source and recording the decision.
- No unnecessary listening services, daemons, or telemetry.
- Secrets never enter Git. Machine-specific config stays separate from portable config.
- Never overwrite user configuration destructively without explicit intent.
- Build manually first; automate only once the architecture is stable (Phase 8).
- Build layer by layer; do not jump ahead to personal automation.
- Create directories only when a phase needs them (D-0007).
