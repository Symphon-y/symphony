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

- **Status:** Accepted (2026-09-13, Phase 1)
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
