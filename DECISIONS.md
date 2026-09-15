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
