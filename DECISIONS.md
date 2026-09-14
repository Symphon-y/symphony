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
