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
  _(Snapshot clause superseded by D-0008.)_
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
  _(Snapshot requirement superseded by D-0008.)_
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

## D-0008 — No hypervisor snapshots: recovery lives inside the system and the repo

- **Status:** Accepted (2026-09-12, Phase 1). Supersedes the snapshot parts of D-0002
  and D-0004.
- **Decision:** Unraid VM snapshots are not part of the phase lifecycle and no plan
  depends on them. Recovery is, in order: snapper snapshots (snap-pac pre/post around
  every pacman transaction); the `linux-lts` and fallback UKI boot entries; the ISO
  recovery chroot in the runbook; reinstalling from the runbook and this repo.
- **Alternatives considered:**
  - Unraid snapshots before each phase. The first attempt failed: `cannot migrate
    domain: State blocked by non-migratable CPU device (invtsc flag)`. The VM's CPU
    is deliberately configured as non-migratable.
  - Make the VM CPU migratable. This changes a deliberate VM setting only to get a
    VM-only safety net.
  - Manual vdisk file copies before each phase. Manual, slow, and with no equivalent on
    physical hardware.
- **Reasoning:** The user's decision is that snapshots are not integral. Recovery that
  also works on physical hardware is worth more than a VM-only one, and relying on
  rebuilds pushes the project toward its reproducibility goal (Phase 8).
- **Consequences:** A failed install in the VM means reinstalling from the runbook.
  Risky in-system changes should be preceded by a manual `snapper create`. Tracking docs
  no longer record snapshot names.

## D-0009 — Manual base install from a runbook, with one scripted step

- **Status:** Accepted (2026-09-13, Phase 1)
- **Decision:** Install by following `docs/runbooks/base-install.md`. The package set
  comes from `packages/*.txt` through `scripts/pkglist`. Step 6 (configuring the new
  system) runs as `install/configure-base-system`: unit-tested, validates every input
  before changing anything, and safe to re-run.
- **Alternatives considered:**
  - archinstall with a saved config: fast, but hides the steps this phase exists to
    understand.
  - Omarchy's ISO configurator and Python orchestrator on archinstall: REJECT (see
    `docs/omarchy-influences.md`).
  - Script the whole install now: premature; install automation belongs to Phase 8.
- **Reasoning:** "Build manually first." Step 6 was scripted at the user's request: it
  was the longest, most error-prone typing, done through a console without paste.
- **Consequences:** Running the runbook for real found three bugs, all now guarded: zsh
  not splitting variables into words, a stacked top-level mount that caused duplicate
  fstab entries, and silently disabled compression. Phase 8 builds on these pieces.
  Follow-up: `configure-base-system` should validate the fstab.

## D-0010 — Disk layout: GPT, 2 GiB ESP at /efi, LUKS2 root

- **Status:** Accepted (2026-09-13, Phase 1)
- **Decision:** GPT with partition labels `ESP` and `cryptroot`. A 2 GiB vfat ESP
  mounted at `/efi` (`fmask/dmask=0077`); the rest is LUKS2 (default argon2id) with
  discards persistently allowed, unlocked by `sd-encrypt` from `rd.luks.name` in the UKI
  command line. Constants live in `system/storage/layout.conf`.
- **Alternatives considered:**
  - ESP at `/boot`: kernel images would sit outside Btrfs snapshots, so a rollback
    pairs new kernels with old modules.
  - No encryption in the VM: faster reboots, but the real layout is never rehearsed.
  - LVM on LUKS: unnecessary with Btrfs subvolumes.
  - 1 GiB ESP: tight for four UKIs.
- **Reasoning:** The workstation will hold sensitive and financial data. Labels avoid
  guessing partition numbers.
- **Consequences:** The passphrase is typed at every boot. TPM2 unlock and Secure Boot
  are Phase 10. Partition labels must be unique across attached disks.

## D-0011 — Btrfs subvolumes with snapper and snap-pac

- **Status:** Accepted (2026-09-13, Phase 1)
- **Decision:** Subvolumes `@ @home @log @pkg @snapshots` (`system/storage/subvolumes.txt`),
  mounted `noatime,compress=zstd:1`. Snapper `root` config with numbered cleanup (limit 10),
  timeline snapshots off, and the cleanup timer. `snap-pac` takes pre/post snapshots around
  every pacman transaction.
- **Alternatives considered:**
  - ext4: no snapshots.
  - Hourly timeline snapshots: noise and space for little value (Omarchy also turns
    them off).
  - Timeshift: a second tool for what snapper and snap-pac already do.
  - Bootable snapshot menu entries: DEFER, as an idea only.
- **Reasoning:** In-system rollback is the primary recovery path (D-0008) and works the
  same on physical hardware.
- **Consequences:** Rollback is a manual procedure from the ISO (to document in Phase 8).
  Compression is filesystem-wide and set by the first mount, so a leftover mount during
  install silently disables it (the runbook now checks).

## D-0012 — systemd-boot with unified kernel images; linux and linux-lts

- **Status:** Accepted (2026-09-13, Phase 1)
- **Decision:** systemd-boot (`editor no`, `timeout 3`). mkinitcpio presets build default
  and fallback UKIs into `/efi/EFI/Linux` for `linux` and `linux-lts`. Initramfs hooks are
  systemd-based, set in a drop-in (`system/mkinitcpio/10-autarchy.conf`).
  `systemd-boot-update.service` keeps the loader current.
- **Alternatives considered:**
  - Limine with `limine-snapper-sync`: Omarchy's approach; REJECT.
  - GRUB with grub-btrfs: snapshot boot entries, but the heaviest option.
  - A single kernel: no fallback when an update breaks boot.
- **Reasoning:** Part of systemd; finds UKIs automatically; the cleanest path to Secure
  Boot (sign the UKIs) and TPM2 unlock. The LTS kernel is a cheap fallback.
- **Consequences:** No snapshot entries in the boot menu. Editing the kernel command
  line at boot is impossible by design.

## D-0013 — Swap: zram only

- **Status:** Accepted (2026-09-13, Phase 1)
- **Decision:** `zram-generator`, half of RAM capped at 8 GiB, zstd compression.
- **Alternatives considered:** a swap partition (must be encrypted and sized); a swapfile
  on Btrfs (needs a no-COW subvolume); no swap.
- **Reasoning:** Headroom under memory pressure with nothing on disk to manage.
- **Consequences:** No hibernation. Revisit for laptops in Phase 10.

## D-0014 — Network stack: NetworkManager, systemd-resolved, timesyncd

- **Status:** Accepted (2026-09-13, Phase 1)
- **Decision:** NetworkManager for all interfaces. systemd-resolved behind the stub
  `resolv.conf`, with LLMNR and multicast DNS disabled (`system/resolved/10-autarchy.conf`).
  Time sync by systemd-timesyncd.
- **Alternatives considered:** systemd-networkd (excellent on servers, weaker for Wi-Fi
  and VPN on a workstation); iwd alone; a local caching resolver (unneeded); chrony
  (unneeded precision).
- **Reasoning:** One stack for the VM and real hardware. resolved gives per-link DNS for
  VPNs later. LLMNR and mDNS open listeners on every interface and let LAN hosts spoof
  name answers.
- **Consequences:** `.local` hostname discovery doesn't work until deliberately enabled.

## D-0015 — Network exposure: nftables denies inbound; no SSH server

- **Status:** Accepted (2026-09-13, Phase 1). _(SSH clause superseded by D-0021.)_
- **Decision:** `/etc/nftables.conf` drops unsolicited inbound traffic. It allows
  established/related, loopback, ICMP/ICMPv6, and DHCPv6 replies; forwarding is dropped
  and outbound traffic is allowed. `openssh` is not installed. An acceptance test forbids
  any listener beyond loopback except DHCP clients.
- **Alternatives considered:**
  - ufw: Omarchy's choice, a wrapper over the same kernel firewall.
  - firewalld: zones are useful on laptops, but heavier.
  - No firewall, relying on having no listeners: no defense in depth.
  - Key-only sshd for remote convenience: declined by the user (console only).
- **Reasoning:** Use the standard primitive directly (engineering rule 19). A workstation
  offers no services.
- **Consequences:** Arch's `nftables.service` is a oneshot without `RemainAfterExit`, so
  `inactive` is its normal state; the tests check the live ruleset instead. Any future
  inbound port is a per-tool decision recorded here. Console-only access means no paste
  into the VM (a Phase 2 question).

## D-0016 — Privilege model: password sudo for wheel; root locked

- **Status:** Accepted (2026-09-13, Phase 1)
- **Decision:** `/etc/sudoers.d/10-wheel` grants `%wheel ALL=(ALL:ALL) ALL`. No
  `NOPASSWD` or `!authenticate` anywhere. The root account is locked; recovery goes
  through the ISO chroot. Login names are lowercase (the first account was renamed
  `Travis` → `travis`).
- **Alternatives considered:** a root password (one more credential, and an emergency
  shell); `doas` or `run0` (less tooling support).
- **Reasoning:** Neither a compromised session nor an agent acting as the user should
  silently become root.
- **Consequences:** No emergency shell at boot, so recovery needs the ISO. Claude Code's
  use of sudo will require the user's password (Phase 2). `usermod -l` leaves
  `/etc/subuid` and `/etc/subgid` unchanged, so renames need a manual fix.

## D-0017 — Repository structure for system config and the package inventory

- **Status:** Accepted (2026-09-13, Phase 1). Refines D-0007.
- **Decision:** Root-owned config lives in `system/<component>/`, and each file names its
  target path in a header. `packages/<category>.txt` lists one package per line with its
  reason, parsed only by `scripts/pkglist`. An acceptance test fails if any explicitly
  installed package is undeclared.
- **Alternatives considered:** mirroring the `/etc` tree (couples the layout to a
  deployment mechanism); editing package-owned files in place (`.pacnew` churn); dumps
  of `pacman -Qqe` (no reasons recorded).
- **Reasoning:** Config stays next to its component, the inventory can't drift, and there
  is one parser (DRY).
- **Consequences:** `system/` files are deployed explicitly by `configure-base-system`
  until Phase 2 chooses a mechanism. Choosing lists per machine (`vm.txt` or hardware
  lists) is Phase 8/10 work.

## D-0018 — Claude Code: native binary, verified manifest, sudo denied by root-owned policy

- **Status:** Accepted (2026-09-13, Phase 2)
- **Decision:** Install Claude Code with Anthropic's official native installer. An
  acceptance test checks the installed binary against the release's signed manifest
  (the installer itself verifies only the SHA256 checksum, not the manifest's detached
  signature — a gap found in `install.sh`, worth knowing about rather than trusting
  blindly). Claude runs as the normal user with `DISABLE_TELEMETRY` and
  `DISABLE_ERROR_REPORTING` set. Its policy — auto-update channel, telemetry, and deny
  rules for `Bash(sudo *)` and for reading `~/.claude/.credentials.json` and
  `~/.config/gh/**` — lives in `/etc/claude-code/managed-settings.json`, root-owned and
  0644, installed by `sync-system`. Managed settings outrank user settings and merge
  permission lists across levels, so the deny rules always apply.
- **Alternatives considered:**
  - The AUR `claude-code` package: a third-party build step, not the vendor's signed
    artifact.
  - npm global install: adds Node as a standing dependency for no benefit here.
  - Keeping the policy in `~/.claude/settings.json`: the account Claude runs as could
    edit its own restrictions.
- **Reasoning:** D-0016 already established that neither a compromised session nor an
  agent acting as the user should silently gain privilege. A root-owned file Claude
  cannot write is what makes "Claude never uses `sudo`" enforced rather than merely
  agreed to.
- **Consequences:** Remote Control is unavailable while telemetry is disabled (see
  D-0024). `claude doctor` and the acceptance suite are the ongoing check that the
  binary and manifest still match after auto-updates.

## D-0019 — `gh` authentication: keep the existing broad-scope OAuth login

- **Status:** Accepted (2026-09-13, Phase 2)
- **Decision:** Keep the `gh` OAuth login set up in Phase 1, rather than re-scoping it
  for Claude's use.
- **Alternatives considered:** A fine-grained personal access token scoped to just this
  repo — safer, but more setup and rotation overhead than the phase needed to resolve.
- **Reasoning:** The user accepted the broad-scope risk for now to keep the handoff
  moving. The token lives in `gh`'s own storage, which Claude's managed settings already
  deny reading (`Read(~/.config/gh/**)`, D-0018).
- **Consequences:** Revisit the token's scope and storage once a keyring exists (VM →
  hardware notes, `docs/phases/phase-02-agent-handoff.md`).

## D-0020 — Config deployment: GNU stow for home, a root-owned copy script for system files

- **Status:** Accepted (2026-09-13, Phase 2). Refines D-0007 and D-0017.
- **Decision:** `home/<component>/` stow packages, applied by `install/link-home`, link
  dotfiles into `$HOME` with no folding. Root-owned files are managed by
  `install/sync-system` against a manifest (`system/files.txt`, with per-host manifests
  at `system/hosts/<hostname>/files.txt`), which checks and applies content, mode, and
  ownership. A manifest mode of `-` means "no per-file permissions: don't check or set a
  mode," for filesystems that have none (the vfat ESP).
- **Alternatives considered:**
  - chezmoi: templating not needed yet, and another tool to trust.
  - A hand-rolled symlink script for home config: stow already solves conflict
    detection and folding.
  - Deploying system files the same way as home files: system files need root ownership
    and mode checks that stow doesn't do.
- **Reasoning:** Two different trust boundaries — the user's own files and root-owned
  system config — get two narrowly-scoped tools rather than one tool stretched to cover
  both (interface segregation).
- **Consequences:** `~/.claude/settings.json` must never be a stow link (see D-0018).
  `link-home apply` needs a stale link removed first when a package's ownership model
  changes, or Claude would write through the dangling link back into the repo.

## D-0021 — On-demand SSH from Unraid as the copy/paste jump host

- **Status:** Accepted (2026-09-13, Phase 2). Supersedes the SSH clause of D-0015.
  _(Retired as the driver seat 2026-09-20: Claude Code now runs locally on the
  Alienware, Phase 12's access model; the mechanism stays available for a VM.)_
- **Decision:** sshd starts on demand, not at boot, reached only from Unraid's LAN
  address. `install/ssh-jump-host <address>` writes both the firewall rule
  (`/etc/nftables.d/ssh-jump-host.nft`) and root-owned `authorized_keys`, with every key
  restricted `from="<address>",restrict,pty`. The drop-in (`system/ssh/10-autarchy.conf`)
  allows keys only, no root login, no forwarding. The passphrase-protected private key
  lives on Unraid's flash, never in the VM or the repo; the repo keeps only the public
  key (`system/hosts/autarchy-vm/ssh/authorized_keys.travis`).
- **Alternatives considered:**
  - A short-lived secret-gist relay for copy/paste: the original Phase 2 plan, dropped
    once SSH from Unraid was on the table.
  - SSH from the Mac directly: the Mac is remote on a subnet that overlaps the home LAN,
    and Unraid advertises no routes, so this path doesn't route cleanly; it would also
    mean trusting a remote network path instead of a LAN-only one.
  - RDP-style clipboard sharing: needs a desktop, which is Phase 4.
- **Reasoning:** copy/paste without opening the VM to the internet or standing up a
  desktop early. Restricting both the firewall rule and every key's `from=` to one known
  LAN address keeps the exposure to "reachable only from a machine already inside the
  house."
- **Consequences:** `docs/environment/vm-lab.md` and `scripts/system-report` mask
  addresses before anything reaches git (D-0022). No SSH or remote-desktop access beyond
  this jump-host path until Phase 4.

## D-0022 — No network or personal identifiers in git — automated scanner, and a rewritten history

- **Status:** Accepted (2026-09-13, Phase 2)
- **Decision:** `scripts/check-identifiers` scans every tracked file and the full commit
  history (contents and messages) for IPv4/IPv6/MAC addresses and email addresses,
  allowing only loopback, unspecified, and documentation ranges plus SSH algorithm names,
  and never prints the matched value. It fails closed: no git repository, or nothing to
  scan, is an error rather than a silent pass. It runs in `scripts/check` and in CI (which
  installs git before `actions/checkout`, or the checkout is a tarball with no `.git` and
  the scanner would wrongly report nothing to check). `scripts/system-report` masks the
  same patterns in its own output (`scripts/lib/identifiers.bash`). When an audit found
  Unraid's LAN address and a VM MAC address already committed — some already pushed — and
  all 28 prior commits carrying the user's personal email, `git filter-repo` rewrote every
  literal address and internal domain name and remapped every author/committer email to
  the GitHub noreply address, across `main` and both phase branches, after a full local
  bundle backup and a guard check that GitHub's branch heads hadn't moved since the
  backup.
- **Alternatives considered:**
  - Scrubbing only new commits going forward, leaving the already-pushed leak: rejected
    by the user — a private repo is not a reason to accept an identifier leak.
  - A pre-commit hook alone, no CI enforcement: wouldn't have caught branches already
    pushed, and a hook can be skipped.
- **Reasoning:** the user's standing rule that no network identifiers belong in git, even
  privately. A scanner that fails open — as the first CI attempt did (D-0023) — is worse
  than no scanner, because it looks like protection.
- **Consequences:** commit hashes quoted in tracking docs before the rewrite were
  remapped to the new history; hashes quoted inside commit messages were left as they
  are. The force-push used `--force-with-lease` after verifying every replaced branch
  head matched the backup, confirmed again against GitHub afterward. GitHub may serve
  old commits by hash from cache for a while.

## D-0023 — CI hardening: pinned checkout, git available for the identifier scanner

- **Status:** Accepted (2026-09-13, Phase 2)
- **Decision:** CI runs in an `archlinux:latest` container. `actions/checkout` is pinned
  by commit SHA, not a floating tag. git is installed in the container before the
  checkout step, so `actions/checkout` produces a real repository the identifier scanner
  (D-0022) can walk, instead of a tarball with no `.git`.
- **Alternatives considered:**
  - Pinning `actions/checkout` by version tag: a tag can be moved.
  - Running the identifier scan only locally, never in CI: already shown to miss commits
    the user hadn't scanned by hand (D-0022's audit).
- **Reasoning:** a pinned SHA can't be silently retagged. Catching an undeclared
  dependency or a silently-passing check in a clean container is exactly what CI in a
  minimal base image is for — the same run also caught a missing `diffutils` dependency
  (`cmp`) this way.
- **Consequences:** any new script dependency must be declared in `packages/tooling.txt`,
  the one list both CI and the VM installer use.

## D-0024 — Claude Code sandboxing, Remote Control, and console font: deferred

- **Status:** Accepted (2026-09-13, Phase 2)
- **Decision:** Not built in Phase 2: a bubblewrap sandbox around Claude Code's tool
  execution; Remote Control (needs a full claude.ai login, which conflicts with the
  telemetry variables set in D-0018); a console font or kmscon for the text console.
- **Alternatives considered:** n/a — these are scoped out of this phase, not chosen
  against.
- **Reasoning:** each depends on groundwork this phase doesn't build. Sandboxing needs a
  threat model beyond "no `sudo`"; Remote Control needs telemetry back on; a console font
  is only worth it if the default console proves hard to read.
- **Consequences:** revisit bubblewrap once Claude's tool surface is better understood;
  revisit Remote Control if telemetry is ever turned back on; leave the console font
  alone unless legibility becomes a real problem.

## D-0025 — Desktop shell: standard decoupled tools + matugen, not a unified shell

- **Status:** Accepted (2026-09-14, Phase 3)
- **Decision:** autarchy's desktop layer (status bar, notifications, idle/lock,
  wallpaper, launcher, menus, clipboard, polkit agent) is built from standard,
  independently-replaceable Linux desktop tools, each behind its own role — not a single
  unified shell process. The one real problem a unified shell solves for a personal
  system — keeping one visual identity across every component instead of hand-editing N
  configs — is solved instead by **matugen**: a single palette is the source of truth,
  rendered per-tool through matugen templates, with a post-hook reload command per tool.
  Specific tool picks (which bar, which launcher, etc.) stay each implementing phase's
  (4/5) own decision.
- **Alternatives considered:**
  - A unified custom shell built from scratch, matching Omarchy v4's own architecture
    (one Quickshell/QML process owning the bar, notifications, launcher, menus,
    idle/lock, wallpaper, clipboard, and polkit agent, IPC-scriptable, with a plugin
    system). Omarchy's own stated reasons for building it: one theming surface instead
    of eight independent configs; event-driven updates instead of polling; notification
    state surviving a shell restart (which happens on every Omarchy update); and a
    plugin ecosystem. All real engineering wins, but sized for a multi-user open-source
    project with a team of contributors and its own plugin marketplace, not a one-person
    workstation — and it cuts directly against this project's own stated
    interface-segregation and "no custom abstraction over a standard primitive"
    principles.
  - Adopting **Noctalia**, an independent (non-Omarchy) Quickshell-based shell project —
    gets most of the same consolidation without writing it ourselves, at the cost of a
    younger, more opinionated dependency than mature standalone tools, and still a
    monolith relative to the rest of this repo's component-by-component design.
  - No propagation layer at all, hand-editing each tool's theme file — reintroduces
    exactly the "N configs to keep in sync" complaint that motivated Omarchy's rewrite
    in the first place.
- **Reasoning:** of Omarchy's stated motivations, only the consistency problem actually
  bites a single-user system — the performance win (avoiding waybar-style polling) and
  the plugin ecosystem matter far more at Omarchy's scale, and the persistence-across-
  restart problem doesn't exist here in the first place, since nothing forces every
  desktop component to restart together the way a monolithic shell does on every update.
  matugen is a mature, actively-maintained, single-binary, no-daemon tool that already
  displaced the same fragmentation problem community-wide for exactly this "one palette,
  many configs" need, at a far smaller lift than building or adopting a shell, while
  preserving full swap-one-component-without-touching-the-others flexibility.
- **Consequences:** every themed component needs a matugen template and a reload
  post-hook, decided alongside that component's own tool pick in Phase 4/5/6. No native
  video wallpaper support the way Omarchy's shell has, unless deliberately added later
  (DEFER, not REJECT). This can be revisited if the decoupled-tools experience proves
  disjointed in practice — Noctalia or a from-scratch shell stay on the table then, not
  ruled out permanently.

## D-0026 — Session start: SDDM + uwsm

- **Status:** Accepted (2026-09-14, Phase 4)
- **Decision:** A conventional graphical greeter (SDDM), configured for Wayland only,
  autologin into one uwsm-managed session — `/etc/sddm.conf.d/10-wayland.conf` sets
  `DisplayServer=wayland` and nothing else; no forced default session name. The
  `hyprland` package ships its own `hyprland-uwsm.desktop` ("Hyprland (uwsm-managed)",
  `Exec=uwsm start -e -D Hyprland hyprland.desktop`), so no custom session file was
  needed.
- **Alternatives considered:** `greetd`+`tuigreet` (smaller footprint, idiomatic in the
  Hyprland/wlroots community, no reported uwsm friction); `ly` (very small, ~1.8MB,
  minimal deps); plain TTY autologin + uwsm (the only option with zero extra
  always-on daemon, matching this project's general minimalism, but needs manual PAM
  tuning a display manager gives for free). All three researched and compared in the
  phase's plan mode.
- **Reasoning:** the most conventional, best-documented path, and what Omarchy itself
  ships — worth the heavier footprint and extra daemon for the reduced friction on a
  system that's still being built out. Revisit if the daemon footprint or uwsm-DM
  interop friction reported elsewhere actually bites.
- **Consequences:** an always-on `sddm.service`. Session picking happens at the
  greeter, not forced by config — verified by confirming `hyprland-uwsm.desktop` was
  already correct rather than assuming a custom file was needed.

## D-0027 — Terminal: ghostty

- **Status:** Accepted (2026-09-14, Phase 4)
- **Decision:** ghostty behind the `$terminal` role, resolved via `xdg-terminal-exec`
  + `~/.config/xdg-terminals.list` (already CLAUDE.md's own Liskov-substitution
  example) — never hardcoded into a keybinding or script.
- **Alternatives considered:** foot (software-rendered by design, no GPU dependency
  at all, Omarchy's current default specifically for resource efficiency); alacritty
  (GPU, very mature, lowest RAM among GPU terminals); kitty (GPU, feature-rich, decent
  software-rendering fallback). All four researched and compared, including
  specifically how each behaves without GPU acceleration, before the VM had a real
  render node.
- **Reasoning:** user preference, made viable by the Virtio-GPU(3D) display fix
  landing first — ghostty has no robust software-rendering fallback, so this pick
  depended on that groundwork.
- **Consequences:** none beyond the role indirection already established; swapping
  terminals later is a one-line change to `xdg-terminals.list`.

## D-0028 — Wallpaper: hyprpaper

- **Status:** Accepted (2026-09-14, Phase 4)
- **Decision:** hyprpaper, IPC-controlled, pointed at a generated solid-color
  placeholder PNG (`~/.local/share/backgrounds/placeholder.png`, hand-crafted via
  Python's `zlib`+`struct` since neither ImageMagick nor PIL were available) — proves
  the mechanism; real curated wallpapers are Phase 6's job.
- **Alternatives considered:** swaybg (the Phase 3 placeholder pick — simpler, no
  IPC, kill+respawn to change wallpaper, which the theme-switching pattern would need
  anyway).
- **Reasoning:** hyprpaper is Hyprland-authored, same ecosystem family as
  hypridle/hyprlock/hyprpolkitagent — the same "native over generic" reasoning
  already applied to the polkit agent (D-0029) — and its IPC control avoids the
  kill+respawn cycle swaybg needs to change wallpaper.
- **Consequences:** wallpaper needs an actual image file to reference (unlike
  swaybg, which can fill a solid color with no file at all) — hence the generated
  placeholder PNG. Video wallpaper support (which Omarchy's shell had) stays
  deferred, not ruled out.

## D-0029 — Polkit agent: hyprpolkitagent

- **Status:** Accepted (2026-09-14, Phase 4)
- **Decision:** hyprpolkitagent, Hyprland's own native polkit authentication agent,
  enabled as its shipped systemd `--user` service (see D-0031) rather than a
  standalone `exec-once`-style launch.
- **Alternatives considered:** polkit-gnome (older, GTK2, what Omarchy v3 used, still
  packaged); polkit-kde-agent; lxqt-policykit; mate-polkit. All four researched and
  compared (dependency footprint, launch style, Arch packaging status) before
  hyprpolkitagent was found as a fifth option not in the original comparison.
- **Reasoning:** no legacy GTK2/KDE toolkit dependency, and it's the idiomatic choice
  for a bare Hyprland session with no other desktop-environment libraries pulled in.
- **Consequences:** none beyond the general "prefer native ecosystem tools" pattern
  this also applied to hyprpaper.

## D-0030 — AUR helper: yay, adopted for a real need

- **Status:** Accepted (2026-09-14, Phase 4). Supersedes the Phase 4 planning-time
  deferral (matugen's AUR-only claim turned out to be wrong).
- **Decision:** yay, bootstrapped manually (`git clone` + `makepkg -si`, a user-run
  step since the final `pacman -U` needs `sudo`) because `xdg-terminal-exec` — the
  exact mechanism CLAUDE.md already names for the `$terminal` role — is genuinely
  AUR-only, confirmed against both the live pacman database and its AUR PKGBUILD.
  From here on, the VM's bulk-install command is `yay -S --needed
  $(scripts/pkglist packages/*.txt)`, not plain `pacman -S` — yay handles official
  and AUR packages identically, so every package stays in the same declared lists.
- **Alternatives considered:** vendoring `xdg-terminal-exec` like `install/claude-code`
  (a small, source-reviewed installer for a ~1500-line POSIX script) — reuses an
  established pattern, no AUR helper needed, but doesn't generalize to any other
  AUR-only tool that comes up later; one-off `makepkg -si` per AUR package with no
  persistent helper — repeats manual work indefinitely.
- **Reasoning:** the standing "AUR helper or none" question (flagged in Phase 2,
  never resolved) needed answering once a real, unavoidable AUR-only dependency
  showed up, rather than solving this one case narrowly and leaving the general
  question open again for the next one.
- **Consequences:** `yay` and `xdg-terminal-exec`, plus yay's own build chain (`go`,
  `fakeroot`, `make`, `scdoc`, `debugedit`, `gcc` — found one at a time from real
  `makepkg -si` failures, not predicted in advance), are declared in
  `packages/desktop.txt`, not `packages/tooling.txt` — CI installs only
  `tooling.txt` with plain `pacman`, in a container that never touches the desktop
  stack, and an AUR-only name there breaks that command outright (caught this the
  hard way: CI red on "target not found: yay" before catching and fixing it).
  `packages/external.md` documents both.

## D-0031 — Autostart via shipped systemd `--user` services, not `exec-once`/`hl.exec_cmd`

- **Status:** Accepted (2026-09-14, Phase 4)
- **Decision:** mako, hypridle, hyprpaper, and hyprpolkitagent are started by
  enabling their own shipped systemd `--user` services
  (`WantedBy=graphical-session.target`, confirmed present for all four via
  `pacman -Ql`), not by launching them from Hyprland's `autostart.lua`.
- **Alternatives considered:** the initial implementation used
  `hl.exec_cmd("uwsm app -- <name>")` for all four, copying the `exec-once` pattern
  common in Hyprland dotfiles (Omarchy's own included). This silently failed for
  hyprpolkitagent, whose binary isn't on `$PATH` at all
  (`/usr/lib/hyprpolkitagent/hyprpolkitagent`) — found by actually logging in and
  running `pgrep`, not by inspection. The other three only "worked" by coincidence of
  being on `$PATH`, duplicating what their own services already do correctly
  (restart-on-failure included).
- **Reasoning:** prefer the standard primitive a package already ships over
  reimplementing process supervision by hand (this project's general DRY/no-custom-
  abstraction stance) — systemd already knows the right path, restart policy, and
  target dependency for each of these.
- **Consequences:** `autostart.lua` is now an explanatory comment with nothing to
  run. Any future Hyprland-ecosystem component should be checked for a shipped
  `systemd/user/*.service` file (`pacman -Ql <pkg> | grep systemd/user`) before
  writing a manual autostart line for it.
  _(The lesson didn't fully stick: Phase 5 added waybar and cliphist without
  checking either, and waybar's own shipped service was missed entirely until
  "waybar is running" failed in the live session — cliphist's was at least checked
  against its real PKGBUILD first. Both are now enabled the same way.)_

## D-0032 — VM display device: Virtio-GPU(3D), not full PCI GPU passthrough

- **Status:** Accepted (2026-09-14, Phase 4). Supersedes the mid-phase detour into
  full passthrough.
- **Decision:** the VM's display device is Virtio-GPU(3D) (Unraid's Graphics
  Card=Virtual, Video Driver=Virtio(3D) — paravirtualized, host-rendered via
  `virgl`), not full PCI passthrough of the physical Intel GPU.
- **Alternatives considered:** full PCI passthrough — tried first during
  troubleshooting (for terminal GPU acceleration and a suspected other dependency),
  and it does give a real DRM render node, but it also hands the display output
  straight to the guest, bypassing Unraid's own display pipeline entirely: noVNC
  console access disappeared, leaving only RDP (useless with no GUI session yet
  running to serve it). Considered pairing passthrough with `wayvnc` (a Wayland-
  native VNC server; well-documented for exactly this scenario) to work around the
  lost console, but that runs into `AllowTcpForwarding no` (D-0021, deliberate) for
  reaching it from outside the VM, and is a workaround for a self-inflicted
  complication rather than the direct path.
- **Reasoning:** checked what Phase 4 actually needs against real package
  dependencies (`pacman -Si`), not assumption: Hyprland, hyprlock, hyprpaper, and
  ghostty all depend on OpenGL/EGL, not Vulkan — `virgl`'s OpenGL-only
  paravirtualization covers everything currently in scope. Virtio-GPU(3D) restores
  the plain "look at Unraid's noVNC console" experience with zero extra tooling,
  which is what should have been true from the start.
- **Consequences:** if Phase 5's `gpu-screen-recorder` turns out to need Vulkan for
  good capture quality, revisit then — either enabling Venus (Vulkan-over-virtio,
  needs manual libvirt XML edits beyond Unraid's simple toggle) or accepting full
  passthrough's console tradeoff deliberately, paired with `wayvnc` this time. Real
  hardware won't have this problem at all — a physical display has no host display
  pipeline to disconnect from.
  _(Resolved: checked directly in Phase 5 — `gpu-screen-recorder` has no Vulkan
  dependency at all; see D-0036.)_

## D-0033 — Launcher: fuzzel

- **Status:** Accepted (2026-09-14, Phase 5)
- **Decision:** fuzzel behind the launcher role, also used as the `--dmenu` engine
  behind the power/system menu (D-0025's plan: ADAPT the menu idea, REJECT a
  bespoke plugin engine).
- **Alternatives considered:** rofi (most mature dmenu/scripting ecosystem and
  `.rasi` theming language, but native Wayland support only merged into mainline in
  2025 — the community relied on a fork, `lbonn/rofi`, before that); wofi (GTK3 +
  CSS theming, the most visually flexible of the three, but upstream explicitly
  says it's "not actively maintained"). All three have working community matugen
  templates (`InioX/matugen-themes`).
- **Reasoning:** smallest dependency footprint (no GTK/Qt, a custom C renderer),
  widely cited as the fastest of the three to open, a plain ini config (no CSS to
  maintain), actively maintained, and a dedicated dmenu-safety flag
  (`--only-match`) the others don't have. Fits this project's stated minimalism
  better than the alternatives, without giving up dmenu scriptability.
- **Consequences:** `home/matugen/.../templates/fuzzel.ini` themes it (fully
  templated, like mako/hyprlock/ghostty in Phase 4 — every visible color needs the
  palette). If rofi's theming ecosystem or wofi's CSS flexibility is ever
  genuinely needed, swapping the launcher is a contained change (one template,
  one binding target, one `power-menu` script's `fuzzel --dmenu` calls).

## D-0034 — Web-app launchers: included

- **Status:** Accepted (2026-09-14, Phase 5)
- **Decision:** Omarchy's web-app mechanism (generate a `.desktop` file, launch via
  the default browser's `--app=` flag) is adopted — `webapp-install`/
  `webapp-launch` scripts, resolving the browser at launch time rather than baking
  it in at install time.
- **Alternatives considered:** skip the feature entirely (deferred as the default
  in Phase 3's classification, pending this phase's own decision) — it's small and
  fully self-contained, so deferring it further would only have delayed a feature
  with no coupling cost either way.
- **Reasoning:** the mechanism is genuinely simple (a generated `.desktop` file
  plus a browser flag, no PWA manifest or service-worker machinery) and useful
  whenever a website is better used as its own launcher entry/window (chat,
  webmail, etc.).
- **Consequences:** true app-mode needs a Chromium-family default browser
  (`webapp-launch` falls back to a plain window for Firefox-family browsers, which
  have no equivalent flag). Favicon fetching depends on a third-party endpoint
  (Google's public favicon service, the same source Omarchy's own version uses) —
  best-effort, a missing icon isn't fatal.

## D-0035 — Workspace/window rules: smart gaps + picture-in-picture float/pin

- **Status:** Accepted (2026-09-14, Phase 5)
- **Decision:** two idiomatic Hyprland-community defaults, written in Lua and
  verified against `Hyprland --verify-config`: smart gaps (no border/gap clutter
  when a workspace has only one window) and auto-float+pin for windows matching
  `Picture-in-Picture` in their title.
- **Alternatives considered:** skip window/workspace rules entirely for this phase,
  revisit once actual daily use surfaces real friction — rejected by the user as
  the phase's plan was reviewed, in favor of adopting both now since they're
  low-stakes and easy to remove.
- **Reasoning:** both patterns are common across Hyprland dotfiles independent of
  Omarchy, cheap to adopt, and directly address a real annoyance (gap clutter with
  one window; picture-in-picture windows needing to float and stay on top to be
  useful at all).
- **Consequences:** `windows.lua`'s `window_rule` action keys (`float`, `pin`)
  aren't statically typed in this system's own installed Lua API stub
  (`/usr/share/hypr/stubs/hl.meta.lua` — only `enabled`/`match`/`name` are) and
  were written by mirroring the pre-Lua `windowrulev2` keyword pattern from
  Hyprland's own official example config, which uses the same kind of untyped
  dynamic key (`no_focus`) the same way. `--verify-config` confirms the syntax is
  accepted; whether the PIP rule actually floats+pins a real picture-in-picture
  window still needs a live confirmation with an actual PIP window, not yet done.

## D-0036 — `gpu-screen-recorder` needs no Vulkan; resolves D-0032's Phase 5 revisit

- **Status:** Accepted (2026-09-14, Phase 5)
- **Decision:** no Vulkan driver is required for screen recording. `intel-media-
  driver` (VAAPI) is declared instead, alongside `gpu-screen-recorder` itself.
- **Alternatives considered:** none — this is a factual resolution of an open
  question D-0032 explicitly deferred, not a choice between options.
- **Reasoning:** checked `gpu-screen-recorder`'s actual `Depends On` list
  (`pacman -Si`) directly rather than assuming either way: no `vulkan-*` package
  anywhere in it. Its optional deps for Intel point to `intel-media-driver`
  ("Required to record your screen on Intel Broadwell or later iGPUs") and
  `linux-firmware-intel` — VAAPI, not Vulkan. Also checked the often-cited "needs
  root to record a monitor" caveat: reading the project's own README, that root
  requirement is handled by a small setuid helper baked into the native package
  build (confirmed via the actual PKGBUILD's `package()` step), and the
  interactive password-prompt caveat mentioned in its docs is specific to the
  flatpak distribution — the Arch package needs no `sudo` and no prompt.
- **Consequences:** `vulkan-intel` (installed speculatively in Phase 4, D-0032)
  remains harmlessly unused by this — nothing currently in the repo's package list
  actually depends on it. Left declared rather than removed, since removing an
  installed package the user might still want is a bigger, unrelated decision.

## D-0037 — Theme model: wallpaper-driven, no named-theme library

- **Status:** Accepted (2026-09-14, Phase 6)
- **Decision:** the palette is always derived live from whatever the current
  wallpaper is (`matugen image <path>`), not from a library of pre-defined named
  themes. Changing the wallpaper *is* changing the theme — `wallpaper-set <path>` /
  `wallpaper-random [dir]` (`home/hyprpaper/dot-local/bin/`) repoint hyprpaper live
  and re-render every matugen template in one step.
- **Alternatives considered:** curated named themes, a `themes/<name>/` directory
  per theme (seed/wallpaper pair) with a switcher script — the pattern every real
  matugen-based dotfiles repo converges on (researched directly: `ethanlaeltan/
  dotfiles-theming`, `AnanyTanwar/hyprland-dotfiles`, `Javatrix/hyprtheme`). Rejected
  by the user in favor of the simpler model.
- **Reasoning:** matugen itself has no concept of a saved theme library — every
  example found bolts a wrapper on top. A named-theme library adds a real piece of
  state management (which theme is "current," a directory-per-theme convention, a
  switcher script) for a single-user system that doesn't need to switch between
  curated looks; deriving the palette from the wallpaper directly satisfies the
  roadmap's "single palette source → component themes" framing without that extra
  layer.
- **Consequences:** no way to name/save/recall a specific look independent of a
  wallpaper file; reverting to an old palette means keeping the old wallpaper image
  around. If a named-theme library is ever wanted, it layers on top of this
  mechanism cleanly (a `themes/<name>/wallpaper.png` convention feeding the same
  `wallpaper-set` script) rather than replacing it.

## D-0038 — Icon theme: Papirus / Papirus-Dark

- **Status:** Accepted (2026-09-14, Phase 6)
- **Decision:** Papirus-Dark, set in `home/gtk/.../settings.ini`
  (`gtk-icon-theme-name`).
- **Alternatives considered:** Yaru (Omarchy's own pick — AUR-only on Arch, no
  official-repo package); Adwaita (zero extra package, ships with GTK, but a
  narrower icon set than Papirus).
- **Reasoning:** official `extra` repo, actively maintained, widest icon coverage of
  the three, ships a dark variant natively. A deliberate divergence from Omarchy's
  Yaru — better Arch-repo support, not an oversight.
- **Consequences:** none of note; a static settings.ini key, swappable without
  touching the theming pipeline.

## D-0039 — Cursor theme: Bibata-Modern-Classic

- **Status:** Accepted (2026-09-14, Phase 6)
- **Decision:** `bibata-cursor-theme-bin` (AUR, prebuilt), theme name
  `Bibata-Modern-Classic`, set via `XCURSOR_THEME`/`XCURSOR_SIZE` env vars in
  `looknfeel.lua` and `gtk-cursor-theme-name`/`-size` in `home/gtk/.../settings.ini`.
- **Alternatives considered:** Adwaita (the no-package fallback); Capitaine Cursors
  (official `extra` repo, but no hyprcursor-native port and less community traction
  in the Hyprland ecosystem than Bibata).
- **Reasoning:** most popular cursor theme in the Hyprland community. No native
  hyprcursor-format port exists for this specific AUR package (confirmed against the
  real GitHub release asset list before declaring it — only XCursor-format tarballs
  are published), so `HYPRCURSOR_THEME` is deliberately left unset; Hyprland falls
  back to XCursor via `XCURSOR_THEME` automatically.
- **Consequences:** slightly larger on-disk footprint and slower cursor loading than
  a native hyprcursor theme would give (unquantified, not measured — XCursor is the
  universally-compatible baseline every Wayland/X11 app already supports, which
  matters more here than shaving hyprcursor's load time). A native hyprcursor Bibata
  port exists via separate community projects, not the official/AUR-official
  package; revisit only if cursor load time is ever an observed problem, not
  preemptively.

## D-0040 — Font: JetBrainsMono Nerd Font, fontconfig canonical alias

- **Status:** Accepted (2026-09-14, Phase 6)
- **Decision:** `ttf-jetbrains-mono-nerd` (official `extra`), aliased as the
  `monospace` generic family via `home/fonts/.../fontconfig/fonts.conf`; Ghostty's
  matugen template sets `font-family`/`font-size` explicitly rather than relying on
  the generic alias, since it's a native app with its own font resolution, not a GTK
  app.
- **Alternatives considered:** FiraCode Nerd Font (ligatures, popular for code), 
  CascadiaCode Nerd Font (Microsoft's terminal font) — both also official-repo,
  equally viable; JetBrainsMono chosen on preference, matching Omarchy's own default.
- **Reasoning:** fixes waybar's workspace/audio/network module icons, which
  rendered as empty "tofu" boxes with no Nerd Font installed at all (flagged during
  Phase 5's live-session check). The fontconfig-override pattern was already
  recorded as adopted in Phase 3 (`docs/omarchy-influences.md`); this phase makes
  the actual font choice.
- **Consequences:** any app that reads the generic `monospace` family automatically
  gets Nerd Font glyph coverage; apps with their own font-resolution logic (Ghostty)
  need it set explicitly per-app, as done here.

## D-0041 — GTK/Qt theming: live matugen-rendered `gtk.css`, `QT_QPA_PLATFORMTHEME=gtk3`

- **Status:** Accepted (2026-09-14, Phase 6)
- **Decision:** two new matugen templates, `gtk3.css` → `~/.config/gtk-3.0/gtk.css`
  and `gtk4.css` → `~/.config/gtk-4.0/gtk.css`, each rendering the two toolkits'
  different named-color sets (GTK3's `theme_*_color` variables vs. libadwaita's
  `accent_color`/`window_bg_color`/etc.) from the same palette roles used
  everywhere else (`surface_variant`/`on_surface_variant` for base/text colors, the
  same Phase 5 contrast-bug fix applied proactively here). `QT_QPA_PLATFORMTHEME=gtk3`
  set in `looknfeel.lua` so Qt apps read the GTK3 theme, per Phase 3's
  already-adopted mechanism.
- **Alternatives considered:** a static pre-built GTK theme (e.g. a
  Catppuccin/Nord GTK theme package) — simpler, more visually polished out of the
  box, but breaks the "one palette drives everything" premise for GTK apps
  specifically. Rejected by the user in favor of staying consistent with every other
  themed component.
- **Reasoning:** matches D-0025's single cross-cutting theming mechanism; the
  tradeoff (libadwaita's CSS overrides are narrower/more fragile than GTK3's, and
  neither toolkit live-reloads — both read their stylesheet once at process start,
  confirmed by research before writing the templates) is accepted as known, not
  discovered later as a surprise.
- **Consequences:** GTK apps need restarting after a `wallpaper-set`/
  `wallpaper-random` call to pick up new colors — unlike mako/hyprlock/ghostty/
  fuzzel/waybar, which all reload live via their post_hooks. No post_hook is
  attached to either GTK template for this reason.

## D-0042 — hyprpaper's config and IPC syntax corrected (amends D-0028)

- **Status:** Accepted (2026-09-14, Phase 6)
- **Decision:** `hyprpaper.conf` rewritten to the current block-based config syntax
  (`wallpaper { monitor = *; path = ...; fit_mode = cover; }`); `wallpaper-set` uses
  `hyprctl hyprpaper wallpaper ",<path>,cover"` (empty monitor field) for the live
  IPC push.
- **Alternatives considered:** none — this is a factual bug fix, not a choice
  between options.
- **Reasoning:** Phase 4's original `hyprpaper.conf` used the *old* flat
  `preload = ...` / `wallpaper = ,path` syntax. hyprpaper 0.8.4 (installed) parses
  `wallpaper` as a block special-category and silently ignores unrecognized flat
  keys — no parse error, but also no wallpaper was ever actually rendered
  (confirmed live: `Monitor Virtual-1 has no target: no wp will be created` in the
  journal, `hyprctl hyprpaper listactive` empty). This had been silently broken
  since Phase 4. Found by reading hyprpaper's actual source
  (`src/config/ConfigManager.cpp`, `WallpaperMatcher.cpp`) rather than trusting
  docs/community posts, which disagreed with each other on the current syntax. The
  live IPC path turned out to be a separate custom wire protocol in this version
  (confirmed against Hyprland's own `hyprctl/src/hyprpaper/Hyprpaper.cpp` client
  source) with its own quirk: the config file's wildcard spelling (`monitor = *`)
  is rejected by the IPC path specifically ("Invalid monitor"), which only accepts
  an empty monitor field for "all monitors" — found by actually running it.
- **Consequences:** the wallpaper now actually renders for the first time since
  Phase 4 introduced hyprpaper. `tests/acceptance/phase-06.bats` includes a
  regression guard against reintroducing the old flat syntax.

## D-0043 — Shell: bash

- **Status:** Accepted (2026-09-14, Phase 7)
- **Decision:** bash as the interactive shell, configured via `home/bash/dot-bashrc`.
- **Alternatives considered:** zsh (largest plugin/theme ecosystem, most commonly
  customized shell); fish (modern out-of-the-box ergonomics -- autosuggestions,
  syntax highlighting, no plugins needed -- but not POSIX-compatible).
- **Reasoning:** already Arch's default, zero extra package, matches every script
  convention already used throughout this repo. Omarchy's own research (Phase 3)
  called this a taste choice, not a technical one, and the user's taste was bash.
- **Consequences:** none of note; a straightforward pick with no coupling to
  anything else in the repo.

## D-0044 — Prompt: Starship

- **Status:** Accepted (2026-09-14, Phase 7)
- **Decision:** Starship, `home/starship/dot-config/starship.toml`, adapted from
  Omarchy's own deliberately minimal format (directory + git branch + git status,
  nothing else -- no time, no username/hostname, no language-runtime version
  clutter).
- **Alternatives considered:** none seriously -- Starship is the de facto
  cross-shell standard for exactly this, and Omarchy's own minimal-format
  philosophy (recorded in Phase 3's research) was worth keeping rather than
  building a more decorated prompt from scratch.
- **Reasoning:** low-stakes, reversible, no real controversy -- resolved without a
  question to the user, per the plan's own "resolved by research" framing.
- **Consequences:** none of note.

## D-0045 — Neovim: not packaged by autarchy; personal config used directly

- **Status:** Accepted (2026-09-14, Phase 7)
- **Decision:** no `home/nvim/` stow package, no curated distribution of any kind.
  The user's own long-maintained personal config
  (`github.com/Symphon-y/config.nvim`, public, default branch `master`) is cloned
  directly to `~/.config/nvim` via plain HTTPS `git clone` and tracked in
  `packages/external.md` as an out-of-repo dependency -- the same way Claude Code
  itself is tracked there, not vendored.
- **Alternatives considered:** a thin LazyVim-starter-based config of our own
  (mirroring `omarchy-nvim`'s actual shape -- confirmed via source read to be
  genuinely thin, ~400 lines over stock `LazyVim/starter`); kickstart.nvim (a
  single-file, fully transparent config, no plugin-manager magic); building fully
  custom from scratch. All rejected once the user clarified they already have their
  own config and specifically didn't want it coupled to this distro's repo.
- **Reasoning:** the user's existing config is genuinely personal content, not
  "system design" -- coupling it to autarchy's own repo would mean either forking
  it (drifting from the source they actually maintain) or making this repo own
  something it has no business owning. This also sidesteps a real, confirmed
  Omarchy pitfall for free: `omarchy-nvim`'s theme hot-reload structurally requires
  LazyVim's plugin-spec shape (`omacom/omarchy#1803`, raised and never fixed
  upstream) -- not this project's problem, since it never adopts that mechanism at
  all.
- **Consequences:** `~/.config/nvim` is genuinely outside this repo's
  reproducibility story -- Phase 8's fresh-rebuild needs the clone command
  documented in `packages/external.md`, not a `home/` package. If the user's config
  itself changes, that happens in its own repo, untouched by anything here. The
  `neovim` package itself is unaffected (already installed, `packages/base.txt`,
  Phase 1).

## D-0046 — Version manager: mise

- **Status:** Accepted (2026-09-14, Phase 7)
- **Decision:** mise, installed and activated in `home/bash/dot-bashrc`
  (`eval "$(mise activate bash)"`). Omarchy's lazy-install-wrapper pattern
  (`omarchy-mise-install`, generating a `~/.local/bin/<command>` shim per tool) is
  noted as a genuinely good, reusable idea but **not implemented** -- its actual
  tool roster is almost entirely Omarchy/Basecamp-specific (AI-CLI wrappers,
  `hey`/`basecamp`) and there's no concrete tool to wrap yet on this machine.
- **Alternatives considered:** none seriously -- mise already consolidates what
  used to be N language-specific version managers (asdf/rbenv/nvm/pyenv) into one
  tool, and Phase 3's research had already flagged it as the likely pick.
- **Reasoning:** the tool itself is a strong, low-risk pick independent of Omarchy;
  building the lazy-install wrapper infrastructure now, with nothing concrete to
  wrap, would be unused machinery -- add it the day a real tool needs it, not
  speculatively.
- **Consequences:** no per-project language runtimes are pinned yet -- that happens
  organically as real projects need it. The wrapper pattern is documented here for
  whenever it's actually needed.

## D-0047 — Containers: rootless Podman, not Docker

- **Status:** Accepted (2026-09-14, Phase 7)
- **Decision:** `podman` + `podman-compose` + `podman-docker` (CLI-compat shim), no
  Docker at all. Confirmed on this VM before deciding: `travis` already has
  subuid/subgid ranges allocated (`/etc/subuid`/`/etc/subgid`:
  `travis:100000:65536`, from Arch's default `useradd`/`login.defs` behavior), so
  rootless containers work with zero extra privilege setup -- no group-or-sudo
  dance to build at all.
- **Alternatives considered:** Docker Engine + Omarchy's own no-docker-group
  guardrail pattern (`install/config/docker.sh`: install+enable Docker, but never
  add the install user to the `docker` group, since that's "equivalent to
  passwordless root"; explicit opt-in script if ever wanted, polkit-gated GUI
  access). This matches this project's own D-0016 privilege-escalation stance and
  was a real contender. Deferring the whole container question to Phase 8 (Phase
  3's original research note) was also considered and rejected -- resolved now
  instead, since the roadmap already scoped it to Phase 7.
- **Reasoning:** rootless Podman solves the "docker-group = passwordless root"
  problem structurally (no daemon, no privileged group, ever) rather than gating
  it behind sudo/polkit after the fact -- a strictly stronger version of D-0016's
  own no-silent-escalation stance than Omarchy's current guardrail achieves.
  Omarchy's own maintainers are independently reaching the same conclusion: an
  open, unmerged PR found during research (`omacom/omarchy` PR #11032, "Make
  Podman native with optional Docker compatibility") is actively migrating their
  default from Docker to rootless Podman, with Docker Compose retained as a
  frontend and `podman-docker` CLI-compat made optional -- not yet shipped as of
  this research, but a strong signal in the same direction.
- **Consequences:** `docker`-branded muscle memory and Compose files work via
  `podman-docker`'s shim and `podman-compose`, but anything that specifically
  assumes a root-owned Docker daemon socket (rare, but real for some GUI tools)
  won't work unmodified. Resolves the roadmap-vs-Phase-3-research scope conflict
  (roadmap listed containers under Phase 7; Phase 3's research note said the tool
  choice belonged to Phase 8) in favor of Phase 7 owning it, since a concrete,
  well-researched answer was already in hand.

## D-0048 — Git identity: split into tracked defaults + untracked local identity

- **Status:** Accepted (2026-09-14, Phase 7)
- **Decision:** `home/git/dot-gitconfig` (tracked, portable: Omarchy's own shipped
  git defaults adopted near-verbatim -- histogram diff, `rerere`, `autoSetupRemote`,
  verbose commit, branch/tag sort by recency, `co`/`br`/`ci`/`st` aliases -- plus
  `init.defaultBranch = main`, not Omarchy's `master`, matching this repo's own
  convention; and the `gh auth git-credential` helper blocks, mechanical and
  reproducible) includes `~/.gitconfig.local` (untracked, machine-local, holding
  only the real `[user]` block) via `[include] path = ~/.gitconfig.local`.
- **Alternatives considered:** baking `user.name`/`user.email` directly into the
  tracked `dot-gitconfig` -- tried first, immediately caught by CI's
  `check-identifiers` (D-0022) exactly as designed, since it's a real email address
  in a tracked file. Not a hypothetical to weigh; a real mistake, fixed once found.
- **Reasoning:** D-0022's no-personal-identifiers policy applies to file *content*,
  not just commit authorship metadata -- a stowed gitconfig with a real email baked
  in is exactly the kind of leak that policy exists to catch, private repo or not.
  `[include]` is the standard git mechanism for exactly this split (portable
  defaults vs. machine-local identity), already anticipated in the roadmap's own
  cross-cutting concern ("machine-specific config separate from portable config")
  but not applied here on the first attempt.
- **Consequences:** a fresh rebuild (Phase 8) needs `~/.gitconfig.local` created by
  hand (or a small documented step) with the real identity -- it's genuinely
  outside this repo's reproducibility story, same as any other personal secret.
  `git config --global` alone doesn't resolve included values (needs
  `--includes`, or no scope flag at all) -- relevant for anyone querying config by
  hand, not for git's own normal operation, which follows includes automatically.
  Also found and fixed in passing: the VM already had a real, undocumented global
  git config (this same identity, plus `gh auth login`'s own credential-helper
  setup) that an earlier repo survey had missed by only checking for a *tracked*
  `~/.gitconfig`, not the live untracked file -- confirmed with the user which
  email to keep rather than silently overwriting it.
- **Incident:** the first version of this commit, pushed to the phase branch,
  had the real email baked into the tracked file (caught by CI). Since the branch
  was brand new, unmerged, and single-developer, it was squashed to one clean
  commit and force-pushed (`--force-with-lease`, guarded to the known prior remote
  head) rather than leaving the leak sitting in history for a `--no-ff` merge to
  make permanent in `main` -- consistent with D-0022's own precedent that a
  private repo doesn't excuse an identifier leak.

## D-0049 — `install/link-home` no longer aborts entirely on one package's conflict

- **Status:** Accepted (2026-09-14, Phase 7)
- **Decision:** `install/link-home apply` passes `--ignore='current\.png$'` to its
  single combined `stow` call, and separately seeds
  `~/.local/share/backgrounds/current.png` by hand if absent (since stow will no
  longer create it).
- **Alternatives considered:** a `.stow-local-ignore` file in `home/hyprpaper/` --
  tried first, didn't take effect for reasons not fully run down; the documented
  `--ignore` CLI flag worked immediately and was used instead.
- **Reasoning:** Phase 6's `wallpaper-set` script deliberately repoints
  `current.png` to an arbitrary absolute path outside the repo (by design -- the
  palette source can be any image anywhere). Stow correctly refuses to restow a
  package over a target it no longer owns, but because `apply()` stows every
  package in one combined invocation, that single conflict aborted *every*
  package's linking, not just hyprpaper's -- a real bug that had been silently
  waiting since Phase 6's own `wallpaper-set` test run, only discovered now because
  Phase 7 was the first phase since to re-run `install/link-home apply`.
- **Consequences:** `current.png` is now permanently outside stow's management
  (by design, not an oversight) -- `wallpaper-set`/`wallpaper-random` own its
  entire lifecycle after the initial bootstrap. The one unit test asserting the
  exact `stow` command line was updated to match.

## D-0050 — Package drift audit: `scripts/pkg-audit`

- **Status:** Accepted (2026-09-15, Phase 8)
- **Decision:** a standalone, unit-tested script checking package drift in both
  directions -- explicitly-installed-but-undeclared (`pacman -Qqe` vs.
  `packages/*.txt`), declared-but-not-present-at-all (checked against `pacman
  -Qq`, any install reason, not just explicit -- a declared package satisfied
  by someone else's dependency isn't drift), and every foreign/AUR package
  (`pacman -Qqm`) declared specifically in `packages/desktop.txt`.
- **Alternatives considered:** leaving package drift as two bats functions
  embedded in `phase-01.bats` (the prior state) -- no standalone script,
  no CI-independent way to run it, and one of the two checks ("no foreign
  packages at all") was already stale by Phase 4.
- **Reasoning:** running the very first version of this script against the
  live system immediately found three real, previously-invisible issues: an
  undeclared optional dependency (`linux-firmware-intel`, present since Phase
  5), an over-strict check design of my own making (flagging `diffutils` as
  "not installed" when it was present only as `mkinitcpio`'s dependency --
  fixed by checking presence, not install reason), and an unintended build
  artifact (`yay-debug`, resolved via D-0051's migration mechanism). A tool
  that finds real problems on its first real run is exactly the point.
- **Consequences:** `phase-01.bats`'s two original package tests were merged
  into one delegate call to this script, and its now-redundant
  `undeclared_packages()` helper removed (D-0053 amends this further).

## D-0051 — Idempotent migrations: `migrations/` + `scripts/migrate`

- **Status:** Accepted (2026-09-15, Phase 8)
- **Decision:** `migrations/<unix-timestamp>-<slug>.sh` scripts, run in
  filename order by `scripts/migrate check|apply`, each marked complete (an
  empty file under `~/.local/state/autarchy/migrations/`) only after it exits
  `0`. A migration needing root calls `sudo` itself; the user runs `scripts/
  migrate apply`, never Claude. Shipped with one real first migration
  (removing the `yay-debug` package D-0050 found), not a synthetic
  placeholder.
- **Alternatives considered:** Omarchy's full mechanism (timestamped scripts +
  completion markers, ADAPTed here) plus its channel/mirror/pacman-guard
  infrastructure (REJECTed already in Phase 3's research, not revisited).
- **Reasoning:** this exact pattern was already the recorded plan for Phase 8
  (`docs/omarchy-influences.md`, "Update and migration mechanism") before this
  phase started -- Phase 3's research had already concluded it was "a strong
  candidate for 'idempotent bootstrap.'" Giving it one real migration instead
  of an empty directory proves the mechanism end-to-end rather than leaving it
  untested infrastructure.
- **Consequences:** future one-time changes to an already-configured system
  (as opposed to ordinary `home/`/`system/` config edits, which apply the
  normal way) get a migration script instead of an ad hoc runbook note. A
  migration is never renumbered or edited once shipped, matching database
  migration conventions, since it may have already run somewhere.

## D-0052 — Backups: LUKS header only, on the Unraid host

- **Status:** Accepted (2026-09-15, Phase 8)
- **Decision:** `cryptsetup luksHeaderBackup` to a file, moved off the VM
  entirely to the Unraid host (via the existing on-demand SSH jump host,
  D-0021) and deleted from the VM once confirmed there. Nothing else gets a
  backup mechanism this phase.
- **Alternatives considered:** a broader personal-data backup strategy --
  rejected as premature; there's no real personal data on this machine yet
  (Phase 9, personal automation, hasn't happened), so designing for it now
  would be speculative.
- **Reasoning:** the LUKS header was the one genuinely unmitigated single
  point of failure found during this phase's survey -- if it's corrupted, the
  passphrase alone can't recover the disk, and nothing about D-0008's existing
  recovery chain (snapper → LTS/fallback kernel → ISO chroot → rebuild from
  repo) touches it at all. Everything else out-of-repo
  (`~/.gitconfig.local`, D-0048; the nvim config clone, D-0045; `gh`/Claude
  Code's own auth) is either trivially re-creatable by hand or already
  durable in its own separate store, so none of it needed a backup
  mechanism, just documentation (`docs/runbooks/rebuild.md`'s inventory
  table).
- **Consequences:** found and fixed two real snags taking the backup for
  real, not hypothetically: `sshd` needed starting on-demand first (D-0021),
  and the backup file's `root:root` mode-`400` ownership (an artifact of
  running the backup command via `sudo`) blocked the `travis`-authenticated
  jump-host session from reading it for the `scp` pull -- fixed with `sudo
  chown travis:travis` before retrying. If the LUKS key is ever rotated, the
  header backup needs retaking -- not automated, a manual reminder for
  whoever does that.

## D-0053 — Consolidated rebuild runbook and user-services list

- **Status:** Accepted (2026-09-15, Phase 8)
- **Decision:** `docs/runbooks/rebuild.md`, picking up exactly where
  `base-install.md` ends, consolidating every manual command Phases 2-7
  scattered across their own tracking docs into one repeatable sequence, plus
  an out-of-repo state inventory table. `system/services-user.txt` +
  `install/enable-user-services check|apply` replaces the scattered
  `systemctl --user enable --now X Y Z` commands from Phases 4-5 specifically.
- **Alternatives considered:** a real second fresh VM to validate this end to
  end -- the user chose an idempotent re-run against the already-configured
  VM instead (see the phase's own tracking doc), deferring a true
  from-scratch test to whenever Phase 10's hardware migration or a real
  disaster actually needs one.
- **Reasoning:** every phase from 2 onward required retyping install/enable
  commands by hand from a tracking doc -- fine once, but each phase since has
  made that list longer and more error-prone to reconstruct from memory or by
  re-reading seven separate docs. One authoritative runbook, backed by real
  idempotent scripts rather than prose alone, is what "idempotent bootstrap"
  in the roadmap's exit signal actually meant.
- **Consequences:** validated for real, not just read and trusted: every
  no-sudo piece (`install/link-home apply`, `install/enable-user-services
  apply`, `scripts/migrate apply`) was re-run against the live, already-
  configured VM and reported zero changes; the one sudo-gated piece
  (`install/sync-system check`/`apply`) was re-run by the user directly,
  reporting "in sync[,] applied 0 updated 12 unchanged." A real
  from-scratch rebuild has never been exercised end-to-end -- if one is ever
  needed for real and finds a gap this runbook missed, that's the moment to
  fix it, not a hypothetical to solve preemptively now.

## D-0054 — Phase 9 scope: standard Arch upkeep, not bespoke personal automation

- **Status:** Accepted (2026-09-15, Phase 9)
- **Decision:** Phase 9's roadmap wording ("Personal automation") was
  redirected by the user toward standard, idiomatic Arch system-upkeep
  automation instead — the gap between this system and what a well-maintained
  Arch install would already have, not bespoke personal scripts, media
  management, or third-party integrations.
- **Alternatives considered:** the roadmap's own open-ended framing, which
  would have left the phase's scope entirely to Claude's guessing at what
  "personal" automation the user might want with no concrete signal either
  way.
- **Reasoning:** "an Arch distribution, not a pile of personal scripts" is a
  more concrete, verifiable target than an open-ended one — every gap this
  phase closed (D-0055 through D-0059) was confirmed against the live system
  first, not invented speculatively.
- **Consequences:** genuinely personal automation (if ever wanted) stays
  unscoped and undesigned; revisit only if a concrete need shows up.

## D-0055 — Mirror freshness: reflector

- **Status:** Accepted (2026-09-15, Phase 9)
- **Decision:** `reflector` (official `extra`), configured via
  `system/reflector/reflector.conf` (`--save /etc/pacman.d/mirrorlist
  --protocol https --country "United States" --latest 5 --sort rate`),
  enabled via its own shipped `reflector.timer`.
- **Alternatives considered:** leaving the mirrorlist as the static
  install-media snapshot it had been since Phase 1 — confirmed genuinely
  stale (dated 2026-09-01, never refreshed).
- **Reasoning:** reflector's Arch package already ships both
  `reflector.service` and `reflector.timer` — this is an install-and-enable,
  not a from-scratch unit. Country inferred from the VM's already-configured
  timezone (`America/Chicago` → United States) rather than asking a redundant
  question.
- **Consequences:** found and fixed a real bug testing this for real, not
  hypothetically: `--country "United States"` needs its value quoted, since
  reflector's config parser (Python's `shlex`) splits unquoted words the same
  way a shell would — the unquoted form silently broke into two arguments,
  reflector only consuming the first (`United`) and erroring on the stray
  second (`States`). Confirmed fixed by actually running `reflector.service`
  and inspecting the regenerated mirrorlist's fresh timestamp, not by reading
  the config and assuming it was right.

## D-0056 — Btrfs scrub, `pacman -F` freshness, and a root-level services mechanism

- **Status:** Accepted (2026-09-15, Phase 9)
- **Decision:** enabled `btrfs-scrub@-.timer` (`btrfs-progs`, already
  installed; `-` is `systemd-escape --path /`, covering this machine's single
  Btrfs filesystem in one instance) and `pacman-filesdb-refresh.timer`
  (`pacman-contrib`, already installed) — both package-shipped, found disabled.
  Enabling them (plus reflector.timer, D-0055) needed a new mechanism:
  `system/services-root.txt` + `install/enable-root-services check|apply`,
  mirroring Phase 8's `system/services-user.txt` + `install/
  enable-user-services` exactly, at root scope (needs root, so the user runs
  `apply`, never Claude).
- **Alternatives considered:** continuing to enable root-scope timers as ad hoc
  inline `systemctl enable` calls (the prior pattern, inside
  `install/configure-base-system`) — workable for a handful of enables at
  install time, but this phase alone added three more, past the point where a
  flat declared list plus a real `check` command is worth having.
- **Reasoning:** both timers were sitting disabled despite being fully
  package-shipped — genuine, low-cost gaps, not judgment calls. The mechanism
  itself was worth building once there were three new root timers to enable in
  one phase, not just one.
- **Consequences:** any future root-scope timer this repo wants to enable goes
  through this same declared-list mechanism instead of another ad hoc
  `systemctl enable` call.

## D-0057 — Journal size: an explicit cap, not the compiled-in default

- **Status:** Accepted (2026-09-15, Phase 9)
- **Decision:** `system/journald/10-autarchy.conf` →
  `/etc/systemd/journald.conf.d/10-autarchy.conf`, setting `SystemMaxUse=500M`.
- **Alternatives considered:** a periodic `journalctl --vacuum-*` timer —
  rejected once confirmed that journald already self-limits continuously as it
  writes (a boundary it enforces itself, not a periodic job); the actual gap
  was that the boundary was journald's own large, unreasoned compiled-in
  default (roughly 10% of the journal's filesystem) rather than an explicit,
  sized one.
- **Reasoning:** an explicit cap is a one-line, no-timer fix for exactly the
  problem "unbounded-feeling log growth" describes, matching how journald
  itself is designed to be configured.
- **Consequences:** none of note; a config value, changeable in one place if
  500M ever proves wrong in either direction.

## D-0058 — AUR build cache: yay's own `cleanAfter`, not a periodic clean timer

- **Status:** Accepted (2026-09-15, Phase 9)
- **Decision:** `home/yay/dot-config/yay/config.json` (`{"cleanAfter": true}`)
  — yay deletes each package's build sources immediately after a successful
  build, so `~/.cache/yay` (59M and growing at the time this was checked)
  never accumulates in the first place.
- **Alternatives considered:** a custom oneshot service + timer running
  `yay -Sc --noconfirm` periodically — the user chose `cleanAfter` instead,
  trading away reusable build caches on a rebuild (which happens rarely here)
  for not needing a new custom unit at all.
- **Reasoning:** yay has no systemd integration of its own for cache cleanup;
  its own persistent-config mechanism already solves the actual problem more
  simply than a new timer would.
- **Consequences:** found a real gotcha verifying this empirically before
  writing it: yay's `--config` flag is pacman's own config-file flag (for an
  alternate `pacman.conf`), not a way to point at yay's *own* settings file —
  confirmed by testing directly (`yay --config <file>` on a JSON file produced
  a pacman-style INI parse error). yay's own settings are only ever
  auto-discovered at `~/.config/yay/config.json`, confirmed by testing a
  minimal file there directly and observing no error.

## D-0059 — Update visibility: `checkupdates` + notification, never auto-applying

- **Status:** Accepted (2026-09-15, Phase 9)
- **Decision:** `home/update-notify/` — a `systemd --user` timer (daily) running
  a script that calls `checkupdates --change` (`pacman-contrib`, already
  installed) and sends a desktop notification only when the set of pending
  updates is new, never applying anything itself.
- **Alternatives considered:** an unattended `pacman -Syu` timer — the
  well-known Arch anti-pattern (partial-upgrade risk from an unattended,
  unreviewed upgrade); never seriously considered.
- **Reasoning:** `checkupdates` is the standard, safe way to list pending
  updates without touching the live pacman database (no lock contention, no
  risk to an in-progress transaction). Its own `--change` flag already solves
  notification-spam (only prints when the pending set differs from last time)
  — confirmed from its actual source after the man page's prose describing it
  proved ambiguous on a first empirical test.
- **Consequences:** tested end-to-end against this VM's real pending updates
  (13, at the time), not a synthetic fixture: the first run produced a genuine
  mako notification (confirmed via `makoctl history`), and a second run
  correctly produced no duplicate. Also fixed a real, narrow false positive
  found in `scripts/check-identifiers` along the way: systemd's
  escaped-root-path instance units (`btrfs-scrub@-.timer`, from D-0056)
  coincidentally match the email-address detection pattern, the same class of
  issue already handled for SSH algorithm names.

## D-0060 — Default browser: Chromium, and closing a dormant Phase 5 gap

- **Status:** Accepted (2026-09-16, Phase 11)
- **Decision:** `chromium` (official `extra`, FOSS) as the system default
  browser, registered declaratively via `home/xdg/dot-config/mimeapps.list`
  (content verified by actually running `xdg-settings set
  default-web-browser chromium.desktop` and reading the real result, not
  guessed). `xdg-utils` also declared explicitly (it was already installed as
  a transitive dependency, never declared). `webapp-launch` (Phase 5, D-0034)
  fixed to fail with a clear, actionable error instead of a cryptic bash
  `exec` failure when no default browser is resolvable.
- **Alternatives considered:** Firefox (official, FOSS, but `webapp-launch`'s
  app-mode `--app=<url>` only works with a Chromium-family browser — Firefox
  falls back to a plain tab); Google Chrome (the named example, but AUR-only
  and proprietary, with no functional advantage over Chromium for this
  project's actual need).
- **Reasoning:** research confirmed no browser had ever been installed by any
  phase — Phase 5 built the web-app-launcher mechanism on the assumption one
  would exist by the time anyone used it, but that dependency was never
  closed. Tracing `webapp-launch`'s actual logic with the live, empty
  `xdg-settings get default-web-browser` output confirmed it would hard-fail
  if invoked — a real, previously-undiscovered dormant bug, not a
  hypothetical one. fuzzel (the launcher) needed no changes at all: confirmed
  via its actual config that it already does standard XDG desktop-file
  discovery, so any new GUI package's `.desktop` entry becomes launchable
  automatically.
- **Consequences:** verified end to end, not just configured: `webapp-install`
  produces a real, working `.desktop` entry, and `webapp-launch` launches a
  genuine Chromium process resolved through the new default (confirmed via
  `hyprctl clients` showing a real window). In passing, added
  `install/install-packages` (wrapping `yay -S --needed
  $(scripts/pkglist packages/*.txt)`) after the user pointed out this exact
  command had been retyped from memory every phase since Phase 4, including
  two real past mistakes (Phase 8, Phase 9) where plain `pacman -S` silently
  aborted on AUR-only packages — `docs/runbooks/rebuild.md` updated to use it.

## D-0061 — Installable release ISO: our own archiso profile, no custom mirror

- **Status:** Accepted (2026-09-16, Phase 10)
- **Decision:** `iso/profile/` is a standard `archiso` profile (based on
  upstream `releng`), built and published by `.github/workflows/
  release-iso.yml` on a date-shaped tag push to `main` (e.g. `2026.09.16`,
  matching Arch's own official ISO naming convention). The ISO stays a thin
  network installer: `packages.x86_64` covers only what the live environment
  itself needs (git, github-cli, bats, disk-management tools); the desktop
  stack and everything else still comes from `packages/*.txt` via
  `pacstrap`/`install/install-packages`, exactly as before. No AUR packages
  are pre-built into the ISO and no custom pacman repo or mirror backs it.
  `install/install-base-system` (new) covers `base-install.md` steps 4–6
  (partition/LUKS/Btrfs/pacstrap/configure) in one script, driven by the
  existing `base-install.local.vars` and gated by one typed disk-path
  confirmation before anything destructive happens — the same
  collect-once-then-run-unattended shape Windows and macOS installers use,
  built our own way.
- **Alternatives considered:** keep manually re-running `base-install.md` by
  hand on each new machine (the original Phase 10 scope, rejected by the
  user mid-planning: "make a base ISO off this as opposed to having to do a
  manual set up again"); a full offline/desktop-preloaded ISO the way
  Omarchy's own `omarchy-iso` works — REJECTed, since research confirmed it
  depends on a self-hosted package mirror and custom repo to work around
  archiso's real limitation (no AUR during a build), exactly the shape
  `docs/omarchy-influences.md` already REJECTed (D-0050); pre-building this
  project's own small AUR footprint (`yay`, `xdg-terminal-exec`,
  `bibata-cursor-theme-bin`) into a local repo baked into the ISO —
  structurally the same rejected shape even at three packages, so left for
  post-boot instead, unchanged from today.
- **Reasoning:** D-0009's REJECT, re-read carefully for this decision,
  targets Omarchy's specific mechanism — "a custom ISO with a gum TUI
  configurator... feeding a Python orchestrator built on archinstall" — not
  custom bootable media in general. A stock-`archiso`-based profile, our own
  plain-bash scripts, no archinstall, no TUI, no custom mirror, doesn't
  re-open that REJECT; it's recorded explicitly here rather than assumed
  silently, since the two sit close enough in shape to need saying out loud.
  `archiso` itself (root/privileged `mkarchiso`, no AUR during a build) is
  Arch's own standard tool, confirmed via its real upstream source, not
  invented for this project.
- **Consequences:** `docs/runbooks/base-install.md` now documents two
  equivalent paths (release ISO, kept-as-fallback manual runbook) rather
  than one. `packages/tooling.txt` gained `yq` (YAML syntax checking for
  `.github/workflows/*.yml`, mirroring the existing `jq`/JSON check in
  `scripts/check`). The Alienware 14/P39G physical migration (device,
  Intel-HD-4600-base/NVIDIA-bonus scope, and local-Claude-Code access model
  already resolved in earlier planning) moves to **Phase 12**, using this
  ISO instead of a manual runbook replay.

## D-0062 — `scripts/update` takes an unconditional pre-update snapshot (extends D-0011)

- **Status:** Accepted (2026-09-16, Phase 10)
- **Decision:** `scripts/update apply` runs `snapper -c root create`
  unconditionally, before touching anything, then reapplies the repo's
  existing appliers in order (`install/install-packages`, `sudo install/
  sync-system apply`, `install/link-home apply`, `install/
  enable-user-services apply`, `scripts/migrate apply`), recording the newly
  applied release tag only once every step succeeds.
- **Alternatives considered:** keep relying on `snap-pac`'s automatic
  pre/post pacman-transaction snapshots (D-0011) as the only safety net —
  real, but blind to a config-only update (a login-screen tweak, a migration,
  a `home/` change with no new package), which is exactly the gap the user
  flagged directly while this phase's plan was still being drafted; require
  a manual `snapper create` before every update, as the runbook already
  documented — works, but depends on remembering it every time, the same
  class of problem `install/install-packages` (D-0060) already solved for
  the package-install command.
- **Reasoning:** `snap-pac` only fires on pacman transactions; nothing
  equivalent existed for the config-only reapply cycle `docs/runbooks/
  rebuild.md` already documents. An unconditional snapshot on every
  `scripts/update apply` run — package changes included, since it runs
  before `install/install-packages` too — makes an update exactly as
  recoverable as a plain `pacman -S` already is, with no judgment call about
  which updates "need" a snapshot.
- **Consequences:** D-0011's original consequence ("rollback is a manual
  procedure from the ISO") still holds — this doesn't automate the rollback
  itself, only guarantees a snapshot exists to roll back to. `scripts/update`
  refuses to run against a dirty working tree or a branch other than `main`,
  validated before the snapshot is taken, matching this repo's established
  "validate everything before touching anything" pattern
  (`install/configure-base-system`, `install/install-base-system`).
  `docs/runbooks/update.md` documents the normal update flow and the
  rollback path if a mid-update step fails.

## D-0063 — Offline-capable release ISO: a build-time-only local repo, extends D-0061

- **Status:** Accepted (2026-09-17, Phase 13)
- **Decision:** The release ISO bakes in the *entire* `packages/*.txt`
  closure — every official-repo package plus the 3 AUR-only ones (`yay`,
  `xdg-terminal-exec`, `bibata-cursor-theme-bin`) — so installing needs zero
  network connectivity, matching the "buy a Windows key, plug in a USB"
  experience the user asked for. `iso/build-offline-repo` (new) downloads
  the official closure via `pacman -Syw` against a throwaway blank dbpath
  (the Arch Wiki's own documented fix for a real dependency-resolution
  gotcha: the build container's own dbpath resolves wrong), builds the 3
  AUR packages via `makepkg` as a non-root user, and `repo-add`s both sets
  into one local repo baked into `iso/profile/airootfs/var/lib/
  autarchy-repo` — gitignored, regenerated fresh by every CI run, never
  committed. A **new** `iso/profile/airootfs/etc/pacman.conf` (distinct
  from the already-existing, still build-time-only `iso/profile/
  pacman.conf`) makes this the live/install-time environment's real
  `/etc/pacman.conf`, with `[localrepo]` (`SigLevel = Optional TrustAll`)
  ranked above `[core]`/`[extra]`, which stay enabled as a network
  fallback. `install/install-base-system`'s existing `pacstrap` call needed
  zero changes — it already just resolves through whatever `/etc/
  pacman.conf` the live environment has.
- **Alternatives considered:** keep the thin network-installer ISO from
  D-0061 (real gap surfaced when Phase 12's first physical-hardware attempt
  had no network connection at all — a brand-new machine on WiFi isn't
  connected until someone explicitly associates it, same as any OS
  installer); ship an already-installed, pre-configured live filesystem
  where "install" means copying/unsquashing it to disk, ArcoLinux's actual
  approach (confirmed via a real forum thread that its offline-*looking*
  ISOs don't do a package-based offline install either) — would likely
  compress smaller, but abandons "`install-base-system` runs `pacstrap`
  against a declared package list" as the install mechanism, a much bigger,
  more invasive redesign not warranted just to solve a file-size problem
  GitHub Releases already accommodates via multiple files.
- **Reasoning:** D-0050's and D-0061's REJECTs both target Omarchy's
  *continuously-operated* mirror/repo service (`omarchy-pkgs`,
  `omarchy-mirror`) and its interactive, manifest-bypassing install
  pattern — real, standing infrastructure with its own maintenance and
  availability burden. A repo built fresh inside this phase's own CI job,
  baked into one versioned release artifact, and discarded when the job
  ends is a materially different thing: no server, nothing to maintain, no
  ongoing availability commitment. Two real, non-Omarchy precedent projects
  (`Torxed/archoffline`, `Dogcatfee/Archiso_XFCE4`) do exactly this shape.
  This distinction is real but close enough to the letter of D-0050/D-0061
  that it needs to be recorded explicitly, the same discipline D-0061
  itself applied to D-0009.
- **Consequences:** the built ISO measured **2,439,299,072 bytes (≈2.27
  GiB)** on its first successful real build — confirmed, not the ~2.5-2.8GB
  estimate research produced beforehand — which is at or over GitHub
  Releases' 2 GiB per-file limit. `release-iso.yml` now measures the real
  built file's size and only splits it (`split -d -b 1800M`, numbered
  `.NN.part` files) when it actually needs to; a future smaller build still
  publishes as a single file exactly like D-0061's original ISO did.
  `docs/runbooks/base-install.md` documents reassembly (`cat` the parts,
  `sha256sum -c` the result) before writing to USB. Disk space on the
  GitHub-hosted runner was never actually the constraint research flagged
  as a real risk (72 GB total, peaked at 33 GB used, well under the
  guaranteed-14GB floor's worst case) — worth knowing for any future,
  heavier build, but not something this phase needed to work around.

## D-0064 — core/extra disabled, not "kept as a fallback": corrects D-0063

- **Status:** Accepted (2026-09-18, Phase 14)
- **Decision:** `iso/profile/airootfs/etc/pacman.conf`'s `[core]` and
  `[extra]` sections are commented out (`#[core]`, not deleted), not left
  enabled as D-0063 originally stated. `iso/build-offline-repo`'s
  `repo-add` output is renamed `localrepo.db.tar.zst`, matching the
  `[localrepo]` pacman.conf section name exactly (was `autarchy.db.tar.zst`
  — a mismatch pacman doesn't tolerate for a bare `Server = file://` URL,
  since it derives the expected database filename from the section name).
  `install/install-base-system`'s `pacstrap` call gets `-M`, so the
  installed system doesn't inherit the live ISO's own blank mirrorlist.
- **Alternatives considered:** leave `[core]`/`[extra]` enabled and ship a
  placeholder `/etc/pacman.d/mirrorlist` with something syntactically
  valid but unreachable — doesn't help; pacman's `-Sy` fails identically
  on a configured-but-unreachable server as on a missing one, so this
  only trades one error message for another. Scope `pacstrap` to sync only
  `[localrepo]` — no such flag exists in pacman or `pacstrap.in`; `-Sy` is
  hardcoded and always refreshes every enabled repo. `Usage = Install`
  (keeps the sections active but exempts them from `-Sy`) — real,
  source-confirmed working option, but not the well-trodden path (the Arch
  Wiki's own "Offline installation" article and the one comparable real
  project checked, `Torxed/archoffline`, both just comment out or omit
  core/extra entirely); kept as a known escape hatch, not used here.
- **Reasoning:** D-0063's original claim — "core/extra stay enabled as a
  network fallback, never removed, so nothing is worse off than today if
  a network happens to be available" — was never validated against a real
  `pacstrap` run. It's wrong, confirmed directly against pacman's own
  source (`lib/libalpm/be_sync.c`, `alpm_db_update()`): every sync-enabled
  repo is asserted to have `servers != NULL` in a loop that aborts the
  **entire** sync call on the first repo that fails that assertion — not
  just that one repo. Since this ISO ships no `/etc/pacman.d/mirrorlist`,
  `[core]`/`[extra]` always have zero configured servers here, and left
  enabled they don't degrade gracefully to "just use `[localrepo]`" — they
  take the whole install down before `[localrepo]`, correctly configured
  and ranked first, is ever reached. A real hardware boot test hit exactly
  this: `error: no servers configured for repository` / `failed to
  synchronize all databases` / `ERROR: failed to install packages to new
  root`, at `pacstrap` inside `install-base-system`. Diagnosed via two
  parallel research passes (one reading every relevant file in this repo,
  one researching and locally reproducing — via `unshare -r` and a
  throwaway pacman sandbox, no sudo, no system state touched — both the
  failure and the fix against upstream pacman/`pacstrap.in`/`mkarchiso`
  source and the Arch Wiki), independently converging on the same root
  cause and citing `pacman.conf(5)`'s own documented section-name-to-
  database-filename convention for the second, latent `autarchy.db` vs
  `[localrepo]` mismatch bug found alongside it.
- **Consequences:** `core`/`extra` are now genuinely inert on this ISO —
  correctly reflecting that a real, working network-fallback install path
  was never actually built or tested, not a regression. If a future phase
  wants a real "install with network if available, offline otherwise"
  mode, `Usage = Install` (the escape hatch identified above) is the
  documented way to re-enable them without the current fatal interaction,
  not simply uncommenting the sections back in. Verified locally before
  the next real hardware attempt: reproduced both the original failure and
  the fix in an isolated `unshare -r` pacman sandbox against this repo's
  actual `iso/build-offline-repo` naming and the corrected `pacman.conf`
  shape, byte-for-byte matching the error text seen on real hardware for
  the broken shape and a clean `exit 0` + correct package resolution for
  the fixed one.

## D-0065 — Hibernation's `resume=` needs its own `rd.luks.name=`, or it deadlocks boot

- **Status:** Accepted (2026-09-18, Phase 14, closes an open item from
  Phase 12)
- **Decision:** `install/configure-base-system`'s `configure_boot()`
  adds a second `rd.luks.name=$swap_uuid=$swap_mapper` to the kernel
  cmdline (alongside root's existing one) whenever hibernation swap is
  configured, plus `resumeflags=x-systemd.device-timeout=30s`.
  `install/install-base-system` renames the swap keyfile from
  `/etc/cryptsetup-keys.d/swap.key` to `/etc/cryptsetup-keys.d/
  cryptswap.key` (matching `crypttab(5)`'s automatic per-mapper keyfile
  discovery, so `sd-encrypt` finds it from inside the initramfs with no
  extra `rd.luks.key=` parameter) and adds `x-initrd.attach` to the
  swap `/etc/crypttab` entry's options (correct shutdown-ordering now
  that the initramfs does the real unlock, not this entry).
- **Alternatives considered:** defer hibernation entirely (stop
  appending `resume=`, keep encrypted swap for memory-pressure relief
  only) — genuinely simpler and was the initially recommended path, but
  the user explicitly wanted real, working hibernation delivered now,
  not deferred; a swap *file* on the encrypted root instead of a
  dedicated LUKS2 partition — Phase 12 already rejected this for real,
  documented `resume_offset=`-on-Btrfs fragility found during that
  phase's own research, unrelated to this bug.
- **Reasoning:** a real hardware boot hung indefinitely
  (`A start job is running for /dev/mapper/cryptswap ... no limit`)
  after a fully successful install. Root-caused by reading
  `systemd-hibernate-resume-generator`'s and `systemd-cryptsetup-
  generator`'s actual C source directly (not secondary docs):
  `systemd-hibernate-resume.service` runs *only inside the initramfs*,
  ordered `Before=local-fs-pre.target` (before the real root is even
  mounted) and `BindsTo=`/`After=` the resume device's unit. That
  device could only be created by unlocking `/etc/crypttab`'s
  `cryptswap` entry — but crypttab lives on the not-yet-mounted real
  root, only processed by `systemd-cryptsetup-generator` *after* root
  mounts, which was itself blocked on the resume service. A genuine,
  airtight circular dependency, not a slow race: `JobTimeoutSec=
  infinity` applies whenever `resume=` comes from the kernel cmdline
  and no `x-systemd.device-timeout` is set (via `resumeflags=` or
  `rootflags=`), which was the case here — it was never going to
  time out, not at 27 minutes, not ever. The embedded swap keyfile
  (`FILES=` in the mkinitcpio conf.d drop-in) was never the problem or
  the fix: present in the initramfs, but nothing there ever read it,
  since no `rd.luks.*` entry told `sd-encrypt` the swap device existed
  at all. The Arch Wiki's own "dm-crypt/Swap encryption" article states
  the fix's requirement unambiguously: *"To resume from an encrypted
  swap partition, the encrypted partition must be unlocked in the
  initramfs."* Confirmed against a real, working reference setup using
  the identical `sd-encrypt`/systemd-boot/UKI shape this repo already
  uses ([orhun's gist](https://gist.github.com/orhun/02102b3af3acfdaf9a5a2164bea7c3d6)),
  and matches real, independently-reported instances of the exact same
  symptom ([systemd#7242](https://github.com/systemd/systemd/issues/7242)
  — origin of the infinite-timeout behavior and the `resumeflags=` fix;
  [pop-os/pop#316](https://github.com/pop-os/pop/issues/316) — identical
  "no limit" hang; [Arch BBS #309114](https://bbs.archlinux.org/viewtopic.php?id=309114)
  — same root-cause class, "swap partition decrypted too late").
- **Consequences:** this class of bug — systemd generator/unit ordering
  during a real kernel boot — cannot be verified in a local sandbox the
  way D-0064's pacman fix was (`unshare -r` can simulate a userspace
  pacman sync; nothing safely simulates initramfs/PID1 behavior without
  sudo or a real boot). Confidence here comes from reading systemd's
  actual generator source directly and matching a real, confirmed-
  working setup, but real verification is still only a real hardware
  boot plus an actual `systemctl hibernate` + resume cycle — Phase 12's
  own hardware acceptance test (`hardware: hibernate and resume works`,
  `tests/acceptance/phase-12.bats`) has been a `skip "manual: ..."` stub
  since it was written, and stays that way until that real cycle is run
  and confirmed; this decision closes the *boot-hang* half of that open
  item, not the full hibernate-then-resume verification itself. Also
  worth recording: this exact interaction (`resume=` set unconditionally
  whenever a swap mapper exists, with no `rd.luks.name=` counterpart)
  was never discussed in `docs/phases/phase-12-alienware-migration.md`
  or tested by any acceptance/unit test before this — every existing
  test in this area was a stub-based string/content assertion,
  structurally incapable of catching a boot-time ordering bug like this
  one (it can only prove "the right strings landed in the right files").
  The new `configure-base-system.bats` test added alongside this fix
  encodes the actual invariant that was violated (`resume=/dev/mapper/X`
  implies `rd.luks.name=...=X` in the same cmdline) rather than only a
  brittle full-string match, so a future regression here is more likely
  to be caught even though the deeper boot-ordering behavior itself
  still can't be.

## D-0066 — A real GUI guided installer: `cage` + hand-written GTK4/libadwaita, secrets via file descriptor

- **Status:** Accepted (2026-09-18, Phase 15)
- **Decision:** The release ISO's primary guided installer is a
  hand-written GTK4/libadwaita Python app (`gui/`), kiosk-launched via
  `cage` (a 66 KiB wlroots compositor, "run one fullscreen app, exit
  when it exits") auto-started on `tty1` login, with `GSK_RENDERER=gl`
  pinned explicitly. The terminal flow (`autarchy-install`) stays as the
  boot fallback / manual-recovery path on `tty2`+, not replaced. Both
  frontends are pure collectors: they gather every field once (including
  both the account password and the LUKS root passphrase, typed and
  confirmed) and hand off to `install/run-guided-install` /
  `install-base-system`, the single unattended runner. Neither password
  ever touches the vars file or disk — each is passed through a
  dedicated file descriptor (fd 8: account password, fd 9: LUKS
  passphrase) read once into a shell variable and piped to each
  consumer via stdin, since a fd's read offset is shared once inherited
  across processes and `cryptsetup` needs the passphrase twice (format,
  then open). `install-base-system`'s own destructive-action
  confirmation (typing the disk path back, not just clicking a button)
  is kept as a second, independent layer for both frontends — the GUI's
  Review page has its own required "type the disk path to confirm"
  field, and its answer is forwarded over the install process's stdin.
- **Alternatives considered:** Calamares, the standard "real GUI
  installer framework" other Arch-based distros use — AUR-only on Arch
  (this project's `mkarchiso` pipeline has no AUR path), its biggest win
  (`unpackfs`, copying a prebuilt image) is useless since this project
  `pacstrap`s from a baked-in local repo, zero UKI support in its
  bootloader module (this project's whole boot design is UKIs —
  EndeavourOS had to fork Calamares itself to make Arch work at all),
  heaviest option measured (+876 MiB) for the least usable logic, and
  philosophically the same shape D-0009 already REJECTed (a config
  wrapper around someone else's orchestrator). A webview-based UI —
  rejected without deep investigation; adds a whole browser-engine
  dependency for no benefit over a native toolkit already available in
  `extra`. Passing secrets via `--key-file`/environment variables
  instead of a dedicated fd — rejected: a key-file path means a plaintext
  secret briefly exists on disk; environment variables are visible to
  any process that can read `/proc/<pid>/environ` on the same system,
  a real local-attacker surface a fd (only inherited by the exact
  processes it's explicitly passed to) doesn't have. A silent,
  programmatic answer to `confirm_destructive()`'s typed-disk-path
  prompt (the GUI writing `$DISK` back to itself) — considered when a
  real hardware boot found the prompt unanswerable and the machine
  hung; rejected by the user in favor of keeping it a genuine
  confirmation, since a value compared to itself provides no real
  protection against confirming the wrong disk.
- **Reasoning:** the user explicitly asked for something comparable to
  Windows Setup / macOS Setup Assistant, not a prettier terminal prompt.
  Researched a real, right-sized precedent (Crystal Linux's
  `jade`/`jade_gui` — a hand-written Rust backend + GTK4/libadwaita
  Python frontend, ~160 KB total, forked and reused as-is by blendOS)
  rather than picking the option that merely looked most impressive.
  `install-base-system`'s `cryptsetup luksFormat`/`open` calls had never
  taken a `--key-file` before this phase — they prompted interactively
  on the TTY, *after* whichever collector's own review/confirmation
  screen already ran, breaking the "fully unattended after confirm"
  promise `autarchy-install`'s own header already claimed; this is a
  real, pre-existing gap this phase closed for both frontends, not just
  the new GUI. A real hardware boot of the first Milestone C build found
  the destructive-confirmation gate genuinely unanswerable: with no
  `stdin=` set on the install subprocess, it inherited the GUI's own
  stdin, which under `cage` is a tty whose keyboard input `libinput`
  takes over directly — the prompt blocked forever, though confirmed
  safe (that prompt is the very first thing that touches the disk, so
  nothing was written). The same boot also found `cage` implements no
  keybindings at all, including no VT-switching, so this phase's
  original assumption that `tty2`+ was always reachable as an escape
  hatch while the GUI has the console was wrong and is corrected here,
  not repeated.
- **Consequences:** a future "quick access to a terminal for debugging
  from inside the GUI" feature is a real, deferred idea (noted in
  `docs/phases/phase-15-gui-installer.md`), not yet designed — `cage`'s
  lack of any keybindings means it needs its own mechanism, not a
  keyboard shortcut assumed to already work. `GSK_RENDERER=gl` is
  pinned because GTK ≥4.16 defaults to a Vulkan renderer on Wayland and
  the Alienware's Haswell/HD 4600 iGPU has documented blank-window bugs
  on exactly this GPU generation; the live ISO deliberately carries no
  Vulkan driver at all as a result, keeping Phase 10's "deliberately
  thin" live package list thin. Automated desktop/Hyprland session
  bring-up after the installed system first boots to a TTY is explicitly
  out of scope here — that is Phase 16's job, not this one.

## D-0068 — One network stack: NetworkManager on the live ISO too (extends D-0014, D-0061)

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** The live installer ISO runs NetworkManager (with
  systemd-resolved), the same stack as the installed system (D-0014). `iwd`
  and `dhcpcd` are removed from the ISO, not left disabled. On the installed
  system `NetworkManager-wait-online.service` is masked, after the enable.
- **Alternatives considered:** Keep iwd on the live ISO and translate its
  credentials into a NetworkManager connection file at install — a second
  format to own and test, and the terminal fallback would still need the
  undocumented `iwctl`. Run both — a second manager on the same interface
  fights NetworkManager for it. No Wi-Fi on the live ISO at all, connecting
  only after first boot — Omarchy's current ISO does exactly this; it costs
  nothing when skipped, but leaves the installed laptop offline on first boot,
  which is what this phase set out to avoid.
- **Reasoning:** With one stack, whatever the live session saves is already a
  connection file the installed system understands, so carrying it over is a
  plain copy (Calamares' `networkcfg` module does the same), and the terminal
  fallback gets `nmtui` for free. Omarchy's current line moved to
  NetworkManager for the reasons that would bite here later (enterprise, VPN,
  hidden and captive-portal networks were the pain on iwd/networkd). Checked
  against the real package: `systemctl enable NetworkManager` also links
  `NetworkManager-wait-online` into `network-online.target`, which holds boot
  for anything ordered after the network — a laptop that is simply off Wi-Fi.
  Masking must come after the enable, since enabling a masked unit fails.
- **Consequences:** The ISO is slightly larger (NetworkManager and
  wpa_supplicant). The old `iwctl` route is gone and the login banner says
  `nmtui`. The live session stays in the world regulatory domain (D-0072).
  `tests/acceptance/phase-12.bats` asserted the old dhcpcd/iwd links and now
  asserts NetworkManager's.

## D-0069 — Wi-Fi hand-off: copy the connection file; the passphrase never in argv, a log, or the vars file

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** The installer's Wi-Fi page joins a network by writing a
  NetworkManager connection file (`autarchy-wifi.nmconnection`, mode 0600)
  and asking NetworkManager to reload it — never `nmcli … password X`.
  `keyfile_for()` in `gui/installer/wifi.py` is the one place that knows the
  file format: the secret is stored in the file (`psk-flags=0`), there is no
  `permissions=` line, and a failed join deletes the file. `configure-base-system`
  then copies whatever `*.nmconnection` files the live session saved to the
  target, 0600 root, without knowing their format. The page's `Answers` field
  is display-only; no password is held anywhere in the vars file or `Answers`.
- **Alternatives considered:** `nmcli device wifi connect … password X` —
  the password is then in the process list, readable through `/proc`.
  Handing the passphrase to the install over a file descriptor like the two
  passwords (D-0066) — pointless here: the connection is made live on the
  page, and the target needs a file regardless. libnm through PyGObject —
  keeps secrets off argv too and gives signal-driven lists, but its objects
  are hard to fake in unit tests; recorded as the fallback if hand-escaping
  ever proves fragile (the hand-off contract would not change, since
  NetworkManager writes the same file). Copying iwd credentials —
  archinstall's "copy ISO config" copies networkd files, not NetworkManager
  or iwd state, and mixing iwd with NetworkManager causes conflicts.
- **Reasoning:** Secret hygiene consistent with D-0066, and a hand-off that
  also carries connections made with `nmtui` from a shell. Written raw, the
  file is silently mangled by NetworkManager — a backslash in an SSID became
  a space, a password containing backslashes came back empty, leading spaces
  were trimmed — so the escaping was verified against a real NetworkManager
  1.58.1: `\` → `\\`, tab/newline/CR → `\t` `\n` `\r`, a leading or trailing
  space → `\s`, and nothing else (`;` `#` `"` `=` `[` and Unicode round-trip
  unchanged). The production output for 16 awkward SSID/password cases read
  back exactly. NetworkManager also ignores any connection file other users
  can read, hence 0600. A file it rejects is ignored silently, so the join
  checks the connection appeared after the reload. A wrong password must not
  stay behind to autoconnect-loop or reach the installed system.
- **Consequences:** The passphrase sits in plaintext at 0600 root on the
  installed system — NetworkManager's own model for system-owned secrets, and
  needed because a bare Hyprland session has no keyring agent to hand it back
  at boot. Joinable from the installer: open, WPA2/WPA3-personal, hidden
  networks, UTF-8 names; enterprise (802.1X), WEP and OWE are set up after
  install in `nm-connection-editor`. Failure wording (wrong password, not
  found, timeout) is matched from `nmcli`'s documented messages and is
  re-verified on real hardware.

## D-0070 — NetworkManager's connectivity check is disabled

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** `[connectivity] enabled=false` in
  `/etc/NetworkManager/conf.d/20-connectivity.conf`, shipped from one source,
  `system/networkmanager/20-connectivity.conf`, to the installed system by
  `sync-system`, with a byte-identical copy in the live ISO's airootfs (the
  profile cannot symlink out of itself; an acceptance test keeps them one file).
- **Alternatives considered:** Keep the default — Arch ships a file that
  fetches `http://ping.archlinux.org/nm-check.txt` on every connection, which
  tells a third party your IP and when you connected. Point it at an endpoint
  we run — continuously operated infrastructure, the thing D-0050 and D-0061
  already decline. Lengthen the interval — still phones home.
- **Reasoning:** The project has no telemetry, and this is a phone-home no one
  asked for. Checked against the real daemon: a same-named file in `/etc`
  replaces Arch's shipped one, leaving `[connectivity] enabled=false` with no
  URI.
- **Consequences:** NetworkManager can no longer detect captive-portal (hotel,
  airport) networks by itself; the user opens the login page. Connectivity
  state still comes from the default route.

## D-0071 — Network UI: `networkmanager-dmenu` + `nm-connection-editor` behind `network-menu`; battery on the bar; Bluetooth deferred

> Amended by D-0075: the picker's password prompt and its visible outcome.

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** Waybar's `network` module shows one of five signal icons plus
  distinct icons for cable, cable-without-an-address, not connected and radio
  off (rfkill), with the details in the tooltip. Left-click and `SUPER+CTRL+N`
  open the picker (`networkmanager-dmenu` through fuzzel); right-click opens
  `nm-connection-editor`. All three go through one entry point,
  `home/network`'s `network-menu` — roles, not executables. A `battery` module
  (warning 30, critical 15) joins the right side, with `@error` added to the
  matugen palette.
- **Alternatives considered:** Omarchy's Quickshell panel — REJECT, a unified
  shell (D-0025). `nm-applet` in the tray — needs a tray producer and an agent,
  and is the heavier option. `nmtui` in a floating terminal (Omarchy's earlier
  approach, with `impala`/`bluetui`) — no GUI, and needs window rules.
  `impala`/`iwgtk` — iwd-only, and the iwd stack is rejected (D-0068). Our own
  fuzzel-and-`nmcli` script — would re-implement `networkmanager-dmenu`, which
  supports fuzzel natively. `eww`/`ags` panels — heavy, and a custom shell.
- **Reasoning:** Follows the fuzzel menu convention (`power-menu`,
  `clipboard-menu`, D-0033), and `nm-connection-editor` gives the
  enterprise/VPN/static-IP coverage the picker doesn't. Reading the
  `networkmanager_dmenu` source showed fuzzel's `--password` masking is applied
  only when `[dmenu_passphrase] obscure = True`; its default is `False`, which
  would show a Wi-Fi password in plain text as it is typed, so the config sets
  it and a test pins it. A stylesheet naming a colour that isn't defined fails to
  load, so a migration re-renders the palette on machines themed before `@error`
  existed, and a test checks every colour `style.css` uses is in the template.
  The real Waybar, with this config and a palette from the real matugen, was run
  under a headless Sway: no crash, no CSS errors, and `battery` stays inert with
  no battery.
- **Consequences:** `nm-connection-editor` adds GTK3/libnma weight (accepted).
  Bluetooth is deferred — it needs `bluez` and a running daemon (cutting
  against "no unnecessary daemons") and a UI choice; so are a volume-mixer click
  and brightness. `format-disabled` on an rfkill block and the Nerd Font glyphs
  are verified on hardware.

## D-0072 — Regulatory domain from the timezone, in wireless-regdb's own file (revises the Phase 17 plan)

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** `configure-base-system` writes `WIRELESS_REGDOM="XX"` to
  `/etc/conf.d/wireless-regdom`, the country taken from the target's tzdata
  `zone.tab` for the chosen timezone (one country per zone; `UTC` and similar
  have none, and set nothing). Any earlier uncommented line is removed first,
  so a re-run or a changed timezone never leaves two. `wireless-regdb` is
  listed in `packages/network.txt`. The kernel command line and `configure_boot`
  are untouched.
- **Alternatives considered:** `cfg80211.ieee80211_regdom=XX` on the UKI
  command line — the original plan; the kernel documentation discourages it in
  favour of userspace hints. `iw reg set` during install — lost at the reboot
  that ends the install (Omarchy deliberately avoids it for that reason).
  Asking the user for a region (Windows and macOS do) — the timezone is already
  chosen and implies it; a separate question can be added later.
- **Reasoning:** Without a regulatory domain the kernel stays in the
  restrictive "world" domain — passive-only scanning on many 5 GHz channels, so
  networks vanish from the list. The spike found `wireless-regdb` already ships
  a udev rule that runs `set-wireless-regdom` when `cfg80211` loads; that
  script sources `/etc/conf.d/wireless-regdom` and calls `iw reg set`, so the
  package's own primitive is the one to set. Verified by running the real
  function bodies on the real package-shipped file: `WIRELESS_REGDOM="US"`, then
  the real `set-wireless-regdom` (with `iw` stubbed) produced `iw reg set US`.
  `wireless-regdb` is not a dependency of `linux-firmware`, so it must be listed.
- **Consequences:** An Intel card that is self-managed may ignore the hint —
  `iw reg get` on the Alienware confirms. The live session stays in the world
  domain, so it may miss some 5 GHz networks. D-0067 (Phase 16's installed-machine
  layout) is written at that phase's close-out.

## D-0073 — A blocked or missing Wi-Fi radio is named and diagnosed on the installer page, never guessed

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** `WifiBackend.radio_state()` reads `nmcli -t -f WIFI-HW,WIFI radio`
  explicitly: `enabled`/`disabled` in `WIFI-HW` are "not blocked" and "hard-blocked",
  `missing` is a new `NO_ADAPTER` state, and any value it does not recognise is
  `UNKNOWN` — never a confident "hardware switch". Every command runs under
  `LC_ALL=C`. The Wi-Fi page says what is true for each state: a hard block names the
  blocking rfkill device and its driver, a missing adapter says none was found (or
  names one with no driver), and a "Details" section shows the machine's own facts
  (rfkill devices, Wi-Fi adapters on the PCI bus and whether a driver bound, wireless
  interfaces), read from sysfs by a GTK-free module (`gui/installer/wifi_diagnostics.py`).
  The page re-reads the state every couple of seconds while it is blocked, missing or
  unreadable and stops when it leaves the screen, so pressing the Wi-Fi key or fixing a
  BIOS setting is noticed on its own. The live ISO gains `iw`, `pciutils`, `usbutils`
  and `evtest`; `autarchy.nogui` on the kernel command line skips the GUI and leaves a
  terminal on tty1; `scripts/system-report` gains a Wi-Fi section built on the same module.
- **Alternatives considered:** Keep one generic message — what failed. Show raw
  `rfkill list` output — needs the tool and a parser, and still doesn't say what to do.
  An in-GUI terminal — the Phase 15 deferred idea (D-0066); `cage` has no key bindings, so
  it needs its own mechanism, and a boot-time option answers the immediate need at a
  fraction of the cost (it stays deferred). Trying to clear a hard block from software —
  not possible, `rfkill unblock` only changes the soft bit. Blacklisting Dell kernel
  modules speculatively — no evidence any of them is involved.
- **Reasoning:** Found on real hardware. On the Alienware 14 (P39G) the page said "Wi-Fi is
  switched off by a hardware switch" while the laptop's Wi-Fi key (F2) did nothing, and the
  live session had no terminal to look with. The code treated every `WIFI-HW` value other
  than `enabled` as a hard block, but a real NetworkManager 1.58.1 in a container with no
  Wi-Fi device prints `missing:enabled` (exit 0) — so the message could name the wrong cause
  entirely — and the tests had only ever used a fake runner with four made-up fixtures. The
  hardware research found that the P39G's BIOS has a "Function Key Behavior" setting and a
  "Wireless" menu whose "Wireless Network: Disabled" makes the card invisible to the OS, and
  that a Dell community report fixed an Alienware 14-R1 whose Fn+F2 did nothing through that
  BIOS setting. **Correction (same day):** that research also named the adapter, the Qualcomm
  Atheros Killer Wireless-N 1202 (AR9462, `ath9k`) -- wrong for this unit. The new "Details"
  on the first hardware boot showed PCI 14e4:43b1, a Broadcom BCM4352, which needs the
  proprietary `wl` driver (D-0074), and an `rfkill` device `dell-rbtn` hard-blocked
  (`dell-rbtn` registers an rfkill only for a firmware-reported airplane-mode slider; the state
  is whatever the BIOS returns); this entry's diagnostics are what found both.
- **Consequences:** The real cause on this machine is settled by the new "Details" on the
  next boot rather than assumed. Hardware quirks specific to one laptop stay out of the
  installer; what it does is make the problem legible. The tests now use real `nmcli` strings
  and a fake sysfs tree; only the empty-tree case of the sysfs reader has been run on a real
  `/sys`, so the first hardware boot is also its first real exercise.

## D-0074 — Hardware that needs extra packages is declared by PCI ID and added only where it is present (the Broadcom BCM4352's proprietary driver)

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** `system/hardware.txt` maps a PCI `vendor:device` ID to a list under
  `packages/hardware/` — ordinary package lists (one package per line with a "why"
  comment), parsed only by `scripts/pkglist`. `scripts/hwpkglist` prints the packages of every
  list whose device is on the PCI bus; `install-base-system` resolves them up front, before
  anything destructive, and adds them to the `pacstrap` list; `iso/build-offline-repo` bakes
  every hardware list into the offline repo so an offline install can add them; `pkg-audit`
  treats them as declared when installed and never as missing when not. A malformed map line
  or an unknown list fails closed (nothing printed, exit 1), so a broken map stops the install
  before the disk is touched. The first entry is `14e4:43b1` (Broadcom BCM4352) →
  `broadcom-wl-dkms` plus `linux-headers` and `linux-lts-headers`. The installer's Wi-Fi page
  reads the same file to say what an adapter needs. The live ISO carries no `wl`; on this
  laptop the page says the adapter needs a driver that comes with the installed system, so
  Wi-Fi is available after the first boot.
- **Alternatives considered:** Install it on every machine — about 300 MB of kernel headers and
  a proprietary module on hardware that doesn't need them. A host-keyed list
  (`packages/alienware-14.txt`, Phase 12's plan) — keyed by a hostname the user chooses, not by
  the hardware. Build `wl` into the live ISO so the page can connect during install — dkms, the
  headers and a compiler in the live image (about 200 MB more, more RAM pinned) and a build step
  that must track the kernel; declined by the user, since the install itself needs no network.
  Ship no driver — leaves the laptop needing Ethernet or a USB adapter. A precompiled package —
  `broadcom-wl` no longer exists in Arch's repositories, only the DKMS one. Omarchy's shape (a
  script per chip checking PCI IDs during install, `install/hardware/fix-bcm43xx.sh`) — ADAPTed
  as declarative data plus one tested selector, so the next quirk is a line in a file.
- **Reasoning:** The evidence came from the machine itself: the installer page's new Details
  (D-0073) showed `14e4:43b1` bound to `bcma-pci-bridge`. No open driver supports that chip —
  `b43` predates 802.11ac, `brcmfmac`'s ID table does not list it, and `bcma` only enumerates
  its cores, so no Wi-Fi interface ever appears and NetworkManager reports no adapter. Only
  Broadcom's proprietary `wl` works. It builds against both current kernels (`linux` 7.2.6 and
  `linux-lts` 6.18.52, checked in a container), and in a real `pacstrap` — base plus both
  kernels plus what `hwpkglist` added, in one transaction like the installer's — DKMS built
  `wl` for both inside the new system. The package ships its own module blacklist (`bcma`,
  `b43`, `ssb`, `brcm*`), so no extra configuration is needed. A proprietary, kernel-tainting
  module is accepted for this hardware, and only for it: the user confirmed shipping it gated
  by the chip.
- **Consequences:** Proprietary code on machines with this chip only. DKMS needs the headers of
  every installed kernel and builds at install time (a little longer), and rebuilds through its
  pacman hook whenever a kernel updates; a kernel too new for the packaged patches would break
  the build, so this rides on the package tracking the kernel (it currently covers 7.2). No
  Wi-Fi during install on this laptop — the live session has no `wl` — so the laptop comes up
  offline and the user joins from the bar after first boot. Separately, the `dell-rbtn` rfkill
  (a firmware-reported airplane-mode slider, hard-blocked) would keep NetworkManager from
  enabling Wi-Fi even with the driver; other Alienware owners cleared it by blacklisting the
  module or with an `acpi_osi` kernel parameter, but nothing confirms either for the 14, so
  that waits for a test on the machine (`modprobe -r dell_rbtn` from `autarchy.nogui`) rather
  than being guessed. Phase 12's planned `packages/alienware-14.txt` is superseded by this.

## D-0075 — The network picker's password prompt is fixed at its source, and its outcome is reported (amends D-0071)

- **Status:** Accepted (2026-09-20, Phase 17). Extended by D-0077, which found the cause left open here.
- **Decision:** `~/.config/fuzzel/fuzzel.ini` no longer sets `[dmenu] exit-immediately-if-empty`
  (the matugen template drops it; a migration re-renders machines themed before). A new
  `network-watch` script runs after the picker: `network-menu` snapshots the saved profiles'
  UUIDs, runs `networkmanager_dmenu`, then feeds the snapshot to `network-watch`, which watches
  the Wi-Fi device through `nmcli` and shows mako toasts — Connecting, Connected, a critical
  Could not connect, or Still connecting after 30 s. On a failure it deletes only the Wi-Fi
  profile *this attempt created* (a UUID absent from the snapshot), so the next pick asks for
  the password again; a profile that already existed is never deleted, and the toast says how
  to forget it. A cancelled picker is silent. If the profiles cannot be listed the watcher is
  skipped, because an empty snapshot would make every saved profile look new. Waybar's
  `format-linked` tooltip no longer says "cable".
- **Alternatives considered:** Replace `networkmanager-dmenu` with our own fuzzel + `nmcli`
  script — the password would go on `nmcli`'s command line (visible in `ps`), which D-0069
  forbids; `networkmanager-dmenu` hands it to NetworkManager over D-Bus. This is now the reason
  D-0071 rejected it, not effort. `nm-applet` in the tray — a GTK3 stack plus a secret agent and
  keyring we don't otherwise have. A `pinentry =` wrapper around `fuzzel --prompt-only
  --password` — kept as the fallback if removing the setting doesn't fix the prompt on the
  machine (it needs `networkmanager-dmenu` 2.7.1+ to accept arguments). A custom Waybar module
  with a "connecting" icon — the `network` module has no such state, so it would mean a second
  module and polling; declined by the user in favour of toasts.
- **Reasoning:** On the Alienware the picker scanned and saved networks but never connected,
  while `nmcli --ask device wifi connect` worked. Reading the code found a defect that would
  break the password prompt on a themed machine: `networkmanager_dmenu` gives fuzzel an empty
  stdin for the passphrase, and `exit-immediately-if-empty` (added in Phase 5, used by no other
  menu; `clipboard-menu` already handles a cancelled menu) makes fuzzel quit at once, so an empty
  password would be saved. **That was not the cause on the Alienware:** checking the machine
  showed `~/.config/fuzzel/` does not exist there (matugen never rendered `fuzzel.ini`), so
  fuzzel ran on its defaults. The fix stays, as a real latent defect, but the reason the picker
  fails to connect on that machine is **still open** and needs evidence from the machine
  (`nmcli connection show`, NetworkManager's journal, the saved profile). Separately, the picker
  exits when NetworkManager *accepts* the request, so nothing reported what happened afterwards
  and a bad profile stayed saved. GNOME, KDE, Windows and macOS all show a connecting state and an
  explicit failure; this supplies the same from state we already have. `nm-connection-editor`
  (right-click) is an editor with no Connect action -- by design, not the bug.
- **Consequences:** One more small script in `home/network`. The watcher polls `nmcli` for up to
  30 s after each pick (about one call a second). It reads device and profile state only and
  never a passphrase. It deletes a newly created profile on any failed first attempt, including
  a non-password failure such as an out-of-range access point; the user re-enters the password.
  The cause of the failed connection on the Alienware was established once Claude Code ran on the
  machine and could read its journal: D-0077.

## D-0077 — The picker asks for WPA2-PSK on a WPA2/WPA3 transition network, through a shim, not a fork (extends D-0075)

- **Status:** Accepted (2026-09-20, Phase 17)
- **Decision:** `network-menu` runs `network-picker`, a small Python script that loads
  `/usr/bin/networkmanager_dmenu` as a module and rebinds one function, `create_wifi_profile`:
  after upstream builds the profile, a `key-mgmt` of `sae` is changed to `wpa-psk` whenever the
  access point also offers PSK (`ap_security()` says `WPA1` or `WPA2`); `sae` stays for a
  WPA3-only network. Everything else -- the fuzzel list, the obscured passphrase prompt, MAC
  pinning, the D-Bus hand-off that keeps the password out of `argv` (D-0069) -- is upstream's,
  untouched. The shim fails closed (a message and a non-zero exit, never the unpatched picker) if
  the upstream script loses any of the three names it relies on. `scripts/check` now sorts the
  files under `home/*/dot-local/bin` by shebang so a Python script there is syntax-checked
  rather than handed to shellcheck.
- **Alternatives considered:** An own fuzzel + `nmcli device wifi connect` picker -- the password
  would be on `nmcli`'s command line, which D-0069 forbids, and it was rejected in D-0075 for that
  reason; `nmcli --ask` with the password on stdin would avoid `argv` but means rewriting the
  list, the prompt and the actions upstream already has. Waiting for an upstream release --
  leaves this laptop connecting by hand; the issue is worth filing, but the fix must ship in the
  ISO now. A NetworkManager configuration that forces PSK -- there is none; `key-mgmt` is
  per-profile. Having `network-watch` repair a failed `sae` profile -- it would need the
  passphrase to re-add it, which D-0069 forbids the script to touch. Gating the downgrade on the
  driver (`wl` only) -- more logic for no gain: a WPA2 profile works on every card, and a
  transition network is by definition one that still accepts WPA2.
- **Reasoning:** From the machine's own NetworkManager journal: the picker *did* add and
  activate the 5 GHz network (`connection-add-activate`), with `key_mgmt SAE`; the supplicant
  could not select that key management with `wl`, association timed out after 25 s, the
  activation failed as `ssid-not-found`, the profile stayed saved, and autoconnect repeated the
  same failure on every boot (12 attempts, 0 successes). The 2.4 GHz network worked only because
  its profile had been made by `nmcli --ask`, which lets the daemon complete the profile and
  chooses `wpa-psk`. `/usr/bin/networkmanager_dmenu:1275` sets `sae` for any AP whose security
  string contains `WPA3`; `nmcli -f WIFI-PROPERTIES device show` on the BCM4352 lists no WPA3 at
  all. So the rule the shim applies is the one `nmcli` and the installer page
  (`gui/installer/wifi.py` `classify_security`: transition -> psk) already use. Verified against
  the real libnm: upstream's profile for a `psk sae` AP is `sae`, the patched one is `wpa-psk`,
  `verify()` passes and the PSK is intact.
- **Consequences:** WPA3 is not used on transition-mode networks from the picker, on any card; a
  WPA3-only network is unaffected. The shim depends on three upstream names (`ap_security`,
  `create_wifi_profile`, `main`) and on `main()` sitting behind an `if __name__ == "__main__"`
  guard; a package update that changes them stops the picker with a clear message instead of
  regressing silently, and `tests/unit/network-picker.bats` pins the behaviour against a fake
  upstream. `network-watch`'s failure toast still says "check the password"; with the SAE
  case gone that is the common cause again.
