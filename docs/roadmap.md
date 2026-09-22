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
| 10 | [Installable release ISO](phases/phase-10-installable-release-iso.md) | 1, cross-cutting | Claude + user | A tag on `main` produces a bootable installer ISO via GitHub Actions, published as a GitHub Release; `scripts/update` gives already-installed machines a snapshotted update path | Complete (2026-09-16) |
| 11 | [Default browser and web-app launching](phases/phase-11-default-browser.md) | 3 | Claude + user | A real default browser installed and declared; Phase 5's dormant web-app-launcher mechanism actually works | Complete (2026-09-16) |
| 12 | [Offline release ISO + physical hardware migration (Alienware 14 / P39G)](phases/phase-12-alienware-migration.md) | 1, cross-cutting, 1–4 | Both | The release ISO installs the full `packages/*.txt` closure with zero network needed; boots and installs on real hardware; microcode, power management, Secure Boot/TPM revisited with a real machine; NVIDIA/nouveau attempted as an explicit bonus, not a requirement | In progress (Phase 14 confirmed the real-hardware install pipeline itself works — a from-scratch, zero-network install now boots to a logged-in base system; ground truth doc and local Claude Code done 2026-09-21, `packages/alienware-14.txt` superseded by D-0074; `rebuild.md` for the payload layout, actual hibernate/resume verification, and GPU/AlienFX bonuses still open) |
| 13 | [Offline-capable release ISO](phases/phase-13-offline-release-iso.md) | 1, cross-cutting | Claude + user | The release ISO installs the full `packages/*.txt` closure with zero network needed, matching a purchased-OS-key install experience | Folded into Phase 12 (2026-09-17) — see that phase's restructuring note. This doc stays as an accurate record of what it built. |
| 14 | [Bake the repo itself into the ISO](phases/phase-14-bake-repo-into-iso.md) | 1 | Claude | Live environment has `install/`/`system/`/`packages/*.txt` with zero GitHub access needed for the core install | Complete (2026-09-18) |
| 15 | [Real GUI guided installer](phases/phase-15-gui-installer.md) | 1 | Claude + user | A real graphical wizard (`cage` + hand-written GTK4/libadwaita, not a TUI), auto-started on `tty1`, collects every field once (including both passwords, via file descriptor) and runs the install fully unattended | Complete (2026-09-18) |
| 16 | [Fully automated desktop bring-up](phases/phase-16-desktop-bring-up.md) | 1, 6 | Claude + user | Reboot after install lands in a working, themed Hyprland desktop with zero manual steps, on a self-contained install (no repo checkout, `~/Projects` never created, XDG directories in place); ISOs can be built locally with `scripts/build-iso` | Complete (2026-09-21) -- the mechanism verified on the Alienware (D-0067); one unattended fresh install from an ISO carrying the first-login fix still owed, on a second machine |
| 17 | [Wi-Fi at install, and an interactive network bar](phases/phase-17-wifi-network-bar.md) | 1, 3 | Claude + user | An optional Wi-Fi step in the installer leaves the laptop online on first boot; the status bar shows network state and offers a picker (left-click) and full settings (right-click); battery indicator | Complete (2026-09-21) -- bar, picker, toasts, `dell_rbtn` blacklist and autoconnect verified on the Alienware (D-0068 to D-0077); the installer's Wi-Fi page cannot join on this laptop (no `wl` in the live ISO) and is smoke-test-verified |
| 18 | [Release payload and update pipeline](phases/phase-18-release-update-pipeline.md) | 1, cross-cutting | Claude + user | An installed machine (no repo on it) can check for and apply the latest release on demand: signed versioned payload, pre-update snapshot, rollback; the repo is public | In progress |

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
- **Phase 10:** resolved; see D-0061, D-0062. Originally scoped as
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
- **Phase 12:** in progress; see D-0063. Device (Alienware 14/P39G),
  base-GPU scope (Intel HD 4600 only, NVIDIA/nouveau attempted as an
  explicit non-blocking bonus), and access model (Claude Code runs
  locally on the machine once base install and networking work) already
  resolved. The first real hardware attempt surfaced that Phase 10's ISO
  was network-dependent for install, which didn't match what the user
  actually wanted -- initially split out as a separate Phase 13, which
  was itself a mistake (see below) later folded back in. Bakes the full
  `packages/*.txt` closure (including the 3 AUR packages) into a
  build-time-only local repo, explicitly distinguished in `DECISIONS.md`
  from the continuously-operated mirror infrastructure D-0050/D-0061
  already rejected. The real built ISO measured over GitHub Releases'
  2 GiB per-file limit on the first try -- confirmed, not assumed from
  the research estimate -- so publishing splits conditionally on the
  actual measured size. Two real regressions during the merge back
  together (an ISO boot fix and the hibernation feature both briefly went
  missing from `main`, twice) are recorded in full in the tracking doc's
  restructuring note and 2026-09-17 log -- the short version: don't split
  one story across two phase branches.
- **Phase 13:** folded into Phase 12 (2026-09-17). Was never actually a
  separate story from the Alienware migration -- splitting it out on
  process convention alone caused two real regressions (the ISO boot fix
  and the hibernation `SWAP_SIZE` feature both briefly went missing from
  `main`, because this phase branched from `main` instead of from
  Phase 12's branch). Its own tracking doc stays as an accurate record of
  what it built (the offline local-repo mechanism, hitting and handling
  GitHub's real 2 GiB Release limit); see D-0063 and Phase 12's own
  restructuring note for the full story of the fold-back.
- **Phase 14:** resolved; see D-0064, D-0065. Phase 13's offline ISO baked
  in the *package* closure but never the *repo itself* driving the
  install -- `autarchy-bootstrap`/`autarchy-install` still needed a
  GitHub clone at boot time, defeating the whole point of an offline
  installer. This phase bakes the checked-out repo straight into the
  live environment at CI build time and retires `autarchy-bootstrap`
  entirely. The real work turned out to be a long real-hardware
  debugging chain (14 build-and-boot cycles on the Alienware), each
  surfacing a genuine bug no static test or VM could have caught: a
  disk-selection prompt that silently accepted a blank disk; the
  executable bit archiso's own `mkarchiso` strips from every baked-in
  file unless explicitly restored via `profiledef.sh`'s
  `file_permissions`; `parted` missing from the live ISO's own package
  list; an explicit `mount -t vfat` needed for modern util-linux's
  stricter FAT-option handling; `pacstrap` hard-failing because
  `[core]`/`[extra]` were left enabled with no reachable mirrorlist,
  which pacman treats as fatal to the *entire* sync, not just those two
  repos (D-0064, correcting D-0063's untested "kept as a fallback"
  claim); and a genuine boot-time deadlock in Phase 12's hibernation
  feature, root-caused directly from `systemd`'s own generator source
  rather than guessed at (D-0065). The last two were diagnosed via
  paired research agents -- one reading this repo's own code, one
  reading upstream source/docs and, where possible, empirically
  reproducing the failure and the fix in an isolated local sandbox
  before ever spending another CI-plus-real-hardware round trip.
  Real verification (`2026.09.17-test14`) confirmed a from-scratch,
  zero-network install completing end-to-end to a rebootable, logged-in
  base system on the actual Alienware -- Phase 1's own original
  acceptance criterion, delivered via a fully automated offline
  installer for the first time. No GUI/Hyprland at that TTY login is
  expected, not a gap: session auto-start is Phase 16's explicit,
  not-yet-started scope.
- **Phase 15:** resolved; see D-0066. Originally planned as a nicer TUI
  (`dialog`/`whiptail`/`gum`); the user pushed back on that framing
  directly, asking for something genuinely comparable to Windows Setup
  / macOS Setup Assistant. Researched real alternatives rather than
  picking the most impressive-looking one: Calamares (the standard
  "real GUI installer" other Arch-based distros use) was a poor fit
  specifically for this project (AUR-only on Arch, no UKI support, its
  biggest win unusable since this project `pacstrap`s from a baked-in
  local repo), landing on `cage` (a minimal wlroots kiosk compositor)
  kiosk-launching a hand-written GTK4/libadwaita app instead, sized
  after a real precedent (Crystal Linux's `jade_gui`). Closed a real,
  pre-existing gap along the way, not just built the new frontend:
  `install-base-system`'s `cryptsetup` calls had never taken a
  `--key-file`, prompting interactively on the TTY even after a
  collector's own review screen already confirmed everything --
  fixed by passing both the account password and the LUKS passphrase
  through dedicated file descriptors, never the vars file or disk.
  Two more real bugs surfaced only by an actual hardware boot, the
  same pattern Phase 14 hit repeatedly: the GUI's install subprocess
  inherited an unusable stdin (under `cage`, the physical keyboard
  never reaches the tty's line discipline), leaving the disk-wipe
  confirmation permanently unanswerable -- confirmed safe (nothing had
  been written yet) and fixed with a real typed-confirmation field on
  the Review page, not a silent pass-through; and `cage` was found to
  implement no keybindings at all, meaning this phase's own "tty2+ is
  the escape hatch" assumption was never actually reachable while the
  GUI has the console. `2026.09.18-test2` confirmed a full real install
  completing end-to-end through the GUI, with `GSK_RENDERER=gl`
  rendering correctly on the Alienware's Haswell/HD 4600 iGPU -- the one
  question only real hardware could answer. A "quick terminal access for
  debugging" feature was explicitly deferred to its own future story,
  not squeezed into this phase's close.

- **Phase 16:** resolved; see D-0067. The plan's `~/Projects/autarchy` checkout
  on the target was dropped mid-phase for a root-owned payload at
  `/usr/local/share/autarchy/current` ("Windows doesn't have a 'windows os' repo
  anywhere either"), SDDM autologin reversed part of D-0026, and one script
  (`install/first-login`) does what the chroot can't. Real hardware then found
  the bug that mattered: Hyprland parsed the hook's `[ -x ]` guard as exec rules,
  so first-login never ran and the desktop came up bare -- diagnosed only once
  Claude Code ran on the machine and read its Hyprland log. `scripts/build-iso`
  (local builds; `sudo podman` on a podman host) and `iso/write-usb.ps1` came
  out of the same phase. What is still owed: one unattended fresh install from
  an ISO carrying the fix, on a machine other than the dev seat.
- **Phase 17:** resolved; see D-0068 to D-0077. Asked for an optional Wi-Fi
  step in the installer and a taskbar where the Wi-Fi icon can be seen and used.
  Research (Omarchy's current line, Windows/macOS, Calamares, Arch and
  NetworkManager's own docs) first, then decisions asked directly: NetworkManager
  on the live ISO too, so carrying the live connection to the installed system is a
  plain file copy (D-0068); `nm-connection-editor` on right-click; battery as the
  only extra indicator; the connectivity check off (D-0070). The bar already
  existed -- Waybar's network module was just display-only. Spikes against a real
  NetworkManager changed the design twice before any code: a hand-written
  connection file is silently mangled unless `\`, tabs and leading/trailing spaces
  are escaped (verified on 16 awkward SSID/password cases, D-0069), and the
  regulatory domain belongs in `wireless-regdb`'s own file, not the kernel command
  line (D-0072). Reading `networkmanager-dmenu`'s source found that fuzzel would
  have shown the Wi-Fi password in plain text without `obscure = True` (D-0071).
  The real GTK page and the real Waybar were run headless, and each found or ruled
  out something the unit tests could not. Hardware verification on the Alienware
  then took three rounds and rewrote the diagnosis twice: the "hardware switch"
  was a missing driver (Broadcom BCM4352 -> `broadcom-wl-dkms` by PCI ID,
  D-0073/D-0074) plus a firmware airplane-mode slider (`dell_rbtn`, blacklisted by
  DMI on the kernel command line, D-0076, proven on all three boot entries); the
  picker that "saved but never connected" was `networkmanager_dmenu` asking for
  SAE on a WPA2/WPA3 network the `wl` driver cannot do, fixed by a one-function
  shim (D-0077) after the fuzzel hypothesis (D-0075) was refuted on the machine.
  Bar, toasts, right-click editor, battery and autoconnect after reboot
  user-confirmed on the laptop.

## Cross-cutting concerns (checked in every phase)

- Security posture: no unnecessary listening services, no telemetry.
- Secrets stay out of Git.
- Machine-specific config separate from portable config.
- VM → physical hardware notes.
