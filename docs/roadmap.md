# Roadmap

Each phase gets its own plan mode and tracking document in [`phases/`](phases/)
(lifecycle defined in [`../CLAUDE.md`](../CLAUDE.md)). Phases beyond the current one are
outlines; their scope is finalized in their own plan mode.

| # | Phase | Layer | Driver | Exit signal | Status |
|---|---|---|---|---|---|
| 0 | [Foundation](phases/phase-00-foundation.md) — repo, docs, standing orders, roadmap | — | Claude (Mac, docs only) | Private GitHub repo with core docs | Complete (2026-09-12) |
| 1 | Environment inspection + base Arch install | 1 | **User** (runbook) | Boots to TTY; user login; network + pacman work; `tests/acceptance/phase-01.bats` passes | Complete (2026-09-13) |
| 2 | [Agent handoff + developer bootstrap](phases/phase-02-agent-handoff.md) | 1/5 | User → Claude | Claude Code runs as user in VM; repo cloned; bats/shellcheck/shfmt; deploy mechanism chosen; CI (static + unit) | Complete (2026-09-14) |
| 3 | [Omarchy research](phases/phase-03-omarchy-research.md) | all | Claude | `docs/omarchy-influences.md` classifies components | Complete (2026-09-14) |
| 4 | [Minimal Hyprland session](phases/phase-04-minimal-hyprland-session.md) | 2 | Claude | Hyprland login; terminal, audio, portals, polkit agent, notifications, idle/lock, wallpaper | Complete (2026-09-14) |
| 5 | [Interaction](phases/phase-05-interaction.md) | 3 | Claude | Launcher, keybinding scheme, clipboard, screenshots, workspaces/rules, status bar, power menu | Complete (2026-09-14) |
| 6 | [Visual system](phases/phase-06-visual-system.md) | 4 | Claude | Single palette source → component themes; fonts, GTK/Qt, icons, cursor, wallpapers | Complete (2026-09-14) |
| 7 | [Developer environment](phases/phase-07-developer-environment.md) | 5 | Claude | Shell, prompt, Neovim, version manager, containers, git/gh config | Complete (2026-09-14) |
| 8 | [Packages, reproducibility, recovery](phases/phase-08-packages-reproducibility-recovery.md) | cross-cutting | Claude + user | Categorized package inventory; audit script; idempotent bootstrap; fresh-VM rebuild from repo succeeds; backups | Complete (2026-09-15) |
| 9 | [Personal automation](phases/phase-09-personal-automation.md) | 6 | Claude | Scripts, systemd user services/timers, integrations | Complete (2026-09-16) |
| 10 | [Installable release ISO](phases/phase-10-installable-release-iso.md) | 1, cross-cutting | Claude + user | A tag on `main` produces a bootable installer ISO via GitHub Actions, published as a GitHub Release; `scripts/update` gives already-installed machines a snapshotted update path | In progress |
| 11 | [Default browser and web-app launching](phases/phase-11-default-browser.md) | 3 | Claude + user | A real default browser installed and declared; Phase 5's dormant web-app-launcher mechanism actually works | Complete (2026-09-16) |
| 12 | Physical hardware migration (Alienware 14 / P39G) | 1–4 | Both | Boot the Phase 10 release ISO on real hardware; microcode, power management, Secure Boot/TPM revisited with a real machine; NVIDIA/nouveau attempted as an explicit bonus, not a requirement | Not started |

## Decisions deferred to their phase's plan mode

- **Phase 1:** resolved; see D-0008 to D-0017.
- **Phase 2:** resolved; see D-0018 to D-0024.
- **Phase 3:** resolved; see D-0025.
- **Phase 4:** resolved; see D-0026 to D-0032. Software rendering was never actually
  needed — the VM ended up on Virtio-GPU(3D) (D-0032) after a detour through full
  PCI passthrough broke Unraid's console. GPU passthrough as its own side phase
  wasn't needed either. The VM's audio-device gap (no virtual sound card in Unraid)
  is still open — audio config landed and is statically verified, but not yet heard.
- **Phase 5:** resolved; see D-0033 to D-0036. D-0036 also resolves D-0032's
  deferred Vulkan question directly: `gpu-screen-recorder` needs none.
- **Phase 6:** resolved; see D-0037 to D-0042. The palette source turned out to be
  simpler than planned -- the wallpaper itself, not a named-theme library (D-0037).
  D-0042 also fixed a real, previously-silent bug: Phase 4's `hyprpaper.conf` never
  actually rendered a wallpaper at all.
- **Phase 7:** resolved; see D-0043 to D-0049. The roadmap-vs-Phase-3 conflict on
  containers was resolved in favor of Phase 7 owning it (D-0047, rootless Podman,
  not Docker). Neovim ended up out of scope entirely -- the user's own personal
  config is used directly, never packaged by this repo (D-0045). D-0048 records a
  real incident: a personal email was briefly baked into a tracked file, caught by
  CI's identifier scanner, fixed by splitting git config into tracked defaults +
  an untracked local-identity include. D-0049 fixed a latent bug from Phase 6
  (`install/link-home` silently refusing to link *any* package once
  `wallpaper-set` had ever run).
- **Phase 8:** resolved; see D-0050 to D-0053. `scripts/pkg-audit` found three
  real drift items on its first real run (D-0050); `scripts/migrate` shipped
  with one real first migration rather than an empty mechanism (D-0051); the
  LUKS header -- the one genuinely unmitigated single point of failure -- now
  has a real backup on the Unraid host (D-0052); `docs/runbooks/rebuild.md`
  consolidates every manual step Phases 2-7 scattered across their own
  tracking docs, validated by an idempotent re-run against the live VM rather
  than a real from-scratch rebuild (D-0053).
- **Phase 9:** resolved; see D-0054 to D-0059. The user redirected the
  roadmap's open-ended "personal automation" scope toward standard,
  idiomatic Arch upkeep instead (D-0054): mirror freshness (D-0055, reflector
  -- found and fixed a real quoting bug testing it live), btrfs scrub and
  `pacman -F` freshness plus a new root-scope services mechanism mirroring
  Phase 8's user one (D-0056), an explicit journal size cap (D-0057), yay's
  own `cleanAfter` for AUR build-cache growth (D-0058), and `checkupdates`
  wired to a real desktop notification, tested against this VM's actual
  pending updates (D-0059). No `docs/omarchy-influences.md` entries this
  phase -- confirmed none of these topics were ever covered by Omarchy's own
  source. A real, unrelated bug also surfaced mid-phase (the VM hanging on
  guest suspend) -- diagnosed but left open by the user's own choice; see
  the tracking doc's "VM → physical hardware notes."
- **Phase 10:** in progress; see D-0061, D-0062. Originally scoped as
  physical hardware migration; research into three candidate devices (2019
  T2 MacBook Pro — set aside, real GPU/kernel risk; MacBook Pro 7,1 — set
  aside, stacked unknowns; Alienware 14/P39G — chosen) resolved a device,
  then the user redirected mid-plan: build a releasable installer ISO
  instead of manually re-running `base-install.md` on new hardware. The
  hardware migration itself moved to **Phase 12**, unchanged in its already-
  resolved decisions; this phase became the ISO/update-pipeline
  infrastructure that Phase 12 will use.
- **Phase 11:** resolved; see D-0060. Not on the original roadmap -- new,
  user-requested scope closing a real dormant bug: Phase 5 (D-0034) built the
  web-app-launcher mechanism assuming a default browser would exist, but no
  phase ever installed one, and tracing the live, empty `xdg-settings get
  default-web-browser` output confirmed it would have hard-failed if used.
  In passing, added `install/install-packages` after the user pointed out
  the manual `yay -S --needed $(scripts/pkglist packages/*.txt)` command had
  caused two real past mistakes (Phases 8 and 9) from being retyped by hand.
- **Phase 12:** not started. Device (Alienware 14/P39G), base-GPU scope
  (Intel HD 4600 only, NVIDIA/nouveau attempted as an explicit non-blocking
  bonus), and access model (Claude Code runs locally on the machine once
  base install and networking work) already resolved from Phase 10's
  original planning pass; gets its own plan-mode session once Phase 10
  lands, to re-express those decisions in terms of booting the release ISO
  rather than a manual runbook.

## Cross-cutting concerns (checked in every phase)

- Security posture: no unnecessary listening services, no telemetry.
- Secrets stay out of Git.
- Machine-specific config separate from portable config.
- VM → physical hardware notes.
