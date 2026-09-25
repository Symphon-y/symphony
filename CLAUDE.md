# symphony — Working Agreement for Claude

symphony is an individually opinionated Arch Linux workstation: **Arch Linux + one
person's system design**. Omarchy is a source of ideas, never a specification.
Never install Omarchy or turn this system into an Omarchy installation.

Each Omarchy idea we look at is classified ADOPT, ADAPT, REJECT or DEFER, and the verdict
is recorded in the `DECISIONS.md` entry that acts on it. **REJECT is final.** Never write
"reject for now". **DEFER** is the only class that can be revisited, and a deferred idea is
always built our own way, never with Omarchy's code or packages.

Read `README.md` for the philosophy and `DECISIONS.md` for why things are the way they
are. **Open work lives in GitHub issues and milestones, not in this repo** — `gh issue
list`, `gh issue view <n>`.

## Current driver

**Claude Code drives from the Alienware itself.** Since 2026-09-20 this session
runs as `travis` on `alien` (the Alienware 14, installed from the release ISO --
D-0063's access model; the VM-and-SSH seat of D-0021 is retired). The machine
is both the dev seat and a real install: the repo checkout at `~/Projects/Arch`
is the source of truth, and the running system uses the root-owned payload at
`/usr/local/share/symphony/current` -- fix things in the checkout, then the user
deploys with `symphony-update apply --from ~/Projects/Arch` (D-0079). Its hardware
is documented in `docs/environment/alienware-14.md`.
Claude never uses `sudo` (enforced by root-owned managed settings); the user
runs any command that needs `sudo` themselves.

## Standing orders

### 1. Every phase gets its own plan mode

1. **Plan mode** — research the phase's area (including how Omarchy approaches it —
   read the source, never install it), ask the user about subjective or
   user-owned decisions, write the plan.
2. **Milestone and issues** — on approval, create a GitHub milestone for the phase and an
   issue per piece of work, each carrying the evidence it rests on. The issues are the
   record of progress; close them as they land. Nothing in this repo tracks open work.
3. **Recovery** — hypervisor snapshots are not part of the lifecycle (D-0008). Recovery
   relies on the system itself (snapper snapshots, fallback kernel, ISO chroot) and on
   rebuilding from this repo.
4. **Red** — write the phase's acceptance tests first and confirm they fail.
5. **Green** — implement issue by issue, closing each with what actually happened.
6. **Close** — a `DECISIONS.md` entry per meaningful choice; hardware facts into
   `docs/environment/`; all tests pass; the milestone closed; merge.

Git flow: one branch per phase (`phase/NN-slug`), small commits, merge to `main` at
phase exit. Anything found along the way that is not this phase's job becomes an issue,
never a note in a file.

### 2. Engineering principles (where applicable)

| Principle | Meaning in this repo |
|---|---|
| **S**ingle responsibility | One component per directory; one script does one job. |
| **O**pen/closed | Extend through drop-ins (Hyprland's Lua `require()` modules, systemd drop-ins, `conf.d/`) rather than editing core files. Machine-specific settings live in drop-ins. |
| **L**iskov substitution | A replaceable component satisfies its role's contract (e.g. any terminal behind the terminal role supports `-e <cmd>`). Prefer existing standards (xdg-terminal-exec, xdg-mime) over custom wrappers. |
| **I**nterface segregation | Many small scripts with narrow jobs, not one monolithic CLI. |
| **D**ependency inversion | Keybindings and menus call *roles* (`$terminal`, `$launcher`), never hardcoded executables. |
| Clean Code | Clear names, small functions, `set -euo pipefail`, shellcheck-clean. The code documents itself; comments stay succinct and explain *why* — a reason, a probe result, a trap someone would otherwise re-enter — never what the next line plainly does. |
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
