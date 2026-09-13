# Phase 01 — Environment Inspection & Base Arch Install

| | |
|---|---|
| **Status** | Complete |
| **Driver** | Claude (Mac preparation) → **User** (runbook in the VM) |
| **Branch** | `phase/01-base-install` |
| **Started** | 2026-09-12 |
| **Completed** | 2026-09-13 |

## Goal

The lab VM runs a minimal Arch system with an encrypted root and snapshots. It boots to a
text console, the user can log in, the network and pacman work, the repo is cloned
inside the VM, and `tests/acceptance/phase-01.bats` passes.

## Scope

**In scope**
- Environment inspection of the VM (`scripts/system-report`)
- Manual base install following [`docs/runbooks/base-install.md`](../runbooks/base-install.md)
- Package inventory (`packages/`), system config (`system/`), unit and acceptance tests

**Out of scope**
- Claude Code, AUR helpers, dotfiles deployment (Phase 2)
- Any graphical stack (Phase 4)
- Automating the install (Phase 8)

## Decisions

Recorded in `DECISIONS.md` at close-out.

**Resolved (user, 2026-09-12)**
- LUKS2 full-disk encryption in the VM
- systemd-boot + unified kernel images (UKIs); no Limine
- Unraid console only: no SSH server; repo reaches the VM through `gh` over HTTPS;
  evidence comes back as commits
- Homebrew test tooling on the Mac
- No Unraid snapshots; recovery is in-system or a reinstall (D-0008)

**Resolved (plan)**
- Manual install, no archinstall
- GPT: 2 GiB ESP plus a LUKS2 root; Btrfs subvolumes `@ @home @log @pkg @snapshots`
- Snapper (numbered cleanup, timeline off) + snap-pac
- Kernels `linux` + `linux-lts`; zram swap; NetworkManager + systemd-resolved; nftables deny-inbound
- Wheel user with password-required sudo; root account locked
- System config under `system/<component>/` (refines D-0007)

**Open**
- Using Claude Code through the Unraid console (Phase 2 plan mode)

## Acceptance tests (written before implementation)

File: `tests/acceptance/phase-01.bats` — run as the installed user after `sudo -v`.

| Group | What it proves |
|---|---|
| boot | 64-bit UEFI; systemd-boot installed; UKIs for `linux` and `linux-lts`; menu editor disabled; LUKS unlock on the kernel cmdline |
| storage | `/` is Btrfs on the LUKS2 mapping (discards on); every subvolume in `system/storage/subvolumes.txt` mounted with its options; ESP is vfat at `/efi`, not world-readable; TRIM timer |
| swap / snapshots | zram swap active; snapper `root` config with timeline off; cleanup timer; snap-pac |
| identity | hostname set (not `archiso`); UTF-8 locale; console keymap; timezone set and NTP synced |
| network | NetworkManager + resolved active; stub resolv.conf; DNS resolves; HTTPS works |
| packages | pacman DB consistent; no foreign packages; every explicitly installed package declared in `packages/` |
| security | non-root wheel user; root locked; no NOPASSWD; sudoers valid; nftables input policy drop; no non-loopback listeners except DHCP clients; no SSH server |
| health | no failed units; system `running`; QEMU guest agent active (VM only) |

Unit tests: `tests/unit/pkglist.bats`.

Red confirmed: 2026-09-13 on the live ISO (`102c12b`): 23 not ok, 12 ok. The ISO
already provides some checked pieces (resolved, sudo, guest agent). Every failure is a
genuine assertion failure, with no load or syntax errors. · Green confirmed:
2026-09-13 on the installed system after a reboot (`a6e70ad`): **36/36 ok**, 0 skipped.

## Tasks

**Mac preparation (Claude)**
- [x] Branch `phase/01-base-install`; this tracking doc
- [x] Omarchy classification rule made explicit (CLAUDE.md, omarchy-influences, memory)
- [x] Homebrew: bats-core 1.14.0, bats-assert, bats-support (tap `bats-core/bats-core`), shellcheck 0.11.0, shfmt 3.14.1
- [x] `tests/unit/pkglist.bats` → red (confirmed: 7/7 fail, script missing) → `scripts/pkglist` → green (7/7); shellcheck and shfmt clean; parses the real lists to 25 packages
- [x] `scripts/system-report` (shellcheck and shfmt clean)
- [x] `packages/*.txt` (all 25 names verified against archlinux.org package search), `system/*` files
- [x] `tests/acceptance/phase-01.bats` runs on the Mac and fails cleanly, with no errors (33 fail, 1 pass, 1 skip; shellcheck clean)
- [x] `docs/runbooks/base-install.md` and `base-install.vars.example`
- [x] Commit; user pushes the branch

**VM (user, following the runbook)**
- [x] 0. Unraid prerequisites
- [x] 1. Repo cloned on the live ISO
- [x] 2. `system-report` committed (`5e21a28`); Claude reviewed the gates: all pass
- [x] 3. Red run committed (`docs/phases/evidence/phase-01-red.tap`, `102c12b`)
- [x] 4–7. Partition, encrypt, Btrfs, pacstrap, configure (`install/configure-base-system`), reboot
- [x] 8. First boot: snapper, repo clone, green run committed (`phase-01-green.tap`)
- [x] 9. `linux-lts` entry boots; snap-pac pre/post snapshots observed (reported by the user)

## Implementation log

### 2026-09-12
- Omarchy research (read-only): `omacom/omarchy-iso` (configurator, archinstall
  orchestrator, disk partitioning) and `basecamp/omarchy` `install/` (snapper, firewall,
  services, sddm). Findings are in the approved plan and go into
  `docs/omarchy-influences.md` at close-out.
- User correction: Omarchy REJECT classifications are permanent. The rule is now in
  CLAUDE.md, the influences doc, and memory.
- **Deviation — ESP mounted at `/efi`, not `/boot`.** With the ESP at `/boot`, kernel
  images live outside the Btrfs root, so a snapper rollback would restore old kernel
  modules next to a new kernel. At `/efi`, `/boot/vmlinuz-*` stays in the snapshotted
  root, and only the UKIs (rebuilt with `mkinitcpio -P`) sit on the ESP.
- **Deviation — added `system/resolved/`.** systemd-resolved's defaults (LLMNR, and
  possibly mDNS) listen on every interface, which contradicts "no listeners". The
  drop-in disables both.
- **Deviation — dropped `system/ssh/` and `system/pacman/`.** There is no SSH server (user
  decision). The pacman cosmetic changes (Color, VerbosePkgLists) are left out of the
  base install as not worth an untested edit to a package-owned file.
- **Deviation — `security.txt` holds `sudo` and `nftables`; `pacman-contrib` is in `base.txt`.**
- **Deviation — the snap-pac check reinstalls an already-installed package** instead of
  installing a new one, so the "every explicit package is declared" test stays meaningful.
- **Deviation — `system/storage/layout.env` renamed to `layout.conf`.** A user-level
  Claude Code hook blocks writing `*.env` files, which is sensible for secrets. The
  file holds only non-secret layout constants, so it was renamed rather than bypassing
  the hook. For the same reason, the per-install variables file is
  `base-install.vars.example` (your local copy: `base-install.local.vars`). It is
  sourced bash with inline comments, not a dotenv file.
- Homebrew-core has no `bats-assert` or `bats-support`. They come from bats-core's
  official tap, maintained by the same project as bats itself.
- Test helper fix: bats pre-sets `BATS_LIB_PATH`, so our library paths are appended
  rather than used as a fallback default. The first "red" run failed on library loading
  and did not count; it was redone after the fix.
- Acceptance suite on the Mac: 33 not ok, 1 ok (HTTPS works on any machine), 1 skip
  (not a VM). The only bats warnings are BW01 for Linux commands absent on macOS.
- **Change — Unraid snapshots removed from the plan (D-0008).** The blank-VM test
  snapshot failed with `Requested operation is not valid: cannot migrate domain: State
  blocked by non-migratable CPU device (invtsc flag)`. The VM's CPU is deliberately
  non-migratable. User decision: hypervisor snapshots are not integral. Removed from
  CLAUDE.md, the phase template, this doc, and the runbook.

### 2026-09-13
- Runbook steps 1–2 done by the user on the live ISO; report at
  [`docs/environment/vm-lab.md`](../environment/vm-lab.md). **All 5 install gates pass.**
- Review: OVMF (EDK II) UEFI 64-bit on Q35; 8 vCPUs (i9-13900K host), 15 GiB RAM;
  `vda` 128 GiB virtio with discard support (512B granularity), so TRIM reaches the host;
  `enp1s0` DHCP IPv4 plus IPv6 addresses from router advertisements; NTP synced. Nothing
  changes the Phase 1 design. `DISK=/dev/vda` is correct.
- Findings for Phase 4 (recorded in `docs/roadmap.md`): the display device is **QXL** with
  no DRM render node, and the VM has **no audio device**.
- Git: the report was pushed from the ISO before `50ceacc` was pushed from the Mac.
  Resolved by rebasing the unpushed Mac commit (now `7686876`); the ISO clone needs
  `git pull` before its next commit.
- Red run reviewed: 23 not ok, 12 ok. The expected failures include hostname (still
  `archiso`), SSH (the ISO ships `sshd`), and package drift (`pkglist` works on the ISO
  and reports 118 undeclared ISO packages).
- **Bug found — the ISO's root shell is zsh, not bash.** A screenshot showed the prompt
  hostname as `autarchy-vm` after the vars file was sourced: zsh treats `HOST` as its
  hostname parameter (cosmetic only). More importantly, zsh does not word-split unquoted
  variables, so the planned `pacstrap -K /mnt $PKGS` would have passed every package as
  one argument. Fixed in the runbook (`50f6e38`) before the user reached step 5 by using
  `$(scripts/pkglist ...)` directly. The rest of steps 4–7 was re-checked for zsh
  differences; none found.
- Steps 4–5 done by the user. Typos through the console were caught before anything was
  written (`:=` instead of `:+` in `sgdisk`); the subvolume loops were given as one-liners.
- **Deviation (user request) — step 6 automated as `install/configure-base-system`.**
  This is earlier than "automate in Phase 8", because step 6 was the most typing and the
  most error-prone step. It follows the standing orders: unit tests with a fake target
  root and stubbed commands, written first. It validates all inputs before changing
  anything, is safe to re-run, and also does step 7's resolv.conf link. The runbook's
  step 6 now invokes the script, and the script is the source of truth.
- Steps 6–7 done; first boot reached. The LUKS prompt, boot, and user login all work.
- **Bug found — duplicate `/etc/fstab` entries.** During step 8, `snapper create-config`
  triggered a systemd reload, and `systemd-fstab-generator` warned "Failed to create
  unit file … as it already exists. Duplicate entry in '/etc/fstab'?" for every mount
  (`/` several times). Likely cause: `genfstab … >> /etc/fstab` ran more than once, since
  `>>` appends. Fixes: runbook step 5 now uses `>`; new acceptance test "fstab
  declares each mountpoint exactly once" (nothing caught this before). The VM's fstab
  is to be inspected before any cleanup.
- **Root cause confirmed from the VM's fstab:** 14 entries, which is `genfstab` output
  twice, and each copy has 7 entries. The 7th is `/` with `subvol=/` and `relatime`:
  the Btrfs top-level volume was still mounted at `/mnt` underneath `@`, most likely
  from `mount /dev/mapper/root /mnt` running twice in step 4, where one `umount` removed
  only one. Because systemd applies the *first* `/` entry when remounting root, the
  root filesystem could lose `noatime`. Runbook step 4 now checks `findmnt /mnt` is
  empty after `umount`, and step 5 checks for exactly 6 `UUID=` entries. The VM fstab
  is cleaned to the 6 correct entries (backup kept at `/etc/fstab.bak`).
- **Second effect of the stacked mount — compression never enabled.** No Btrfs entry
  in the VM fstab has `compress=zstd:1`. Compression is a filesystem-wide option,
  fixed by the first mount of the volume: the leftover top-level mount had no options,
  so the later subvolume mounts couldn't turn compression on (per-mount `noatime` did
  apply). pacstrap therefore wrote uncompressed data. The cleanup also adds
  `compress=zstd:1` to every Btrfs entry, and a remount of `/` turns it on. Existing files
  stay uncompressed, which is harmless; new writes are compressed. The cleanup was tested
  on the Mac against a replica of the VM fstab: 6 entries, no duplicates, no top-level
  entry, compression on all Btrfs lines, and running it twice gives the same file.
- Follow-up (not done now): `install/configure-base-system` preflight could validate the
  fstab (one entry per mountpoint, no top-level subvolume, Btrfs compression present),
  which would have caught this before reboot. Candidate for Phase 8.
- Steps 8–9 done by the user; first green run pushed (`c87f23f`): **32/35 ok**. That
  run predates the fstab test (35 tests), because the fstab fix commits weren't on
  GitHub yet when the VM clone was made. Failures:
  - **12 snapper timeline off:** console typo. `set-config TIMELINE_CREAT=no` created a
    meaningless key, and `TIMELINE_CREATE` stayed `yes`. Fixed on the VM: `set-config`
    again, and the stray key removed (`TIMELINE_CREATE,no` is the only match).
  - **28 sudo never skips the password:** a test bug. It matched the commented-out
    `# %wheel ALL=(ALL:ALL) NOPASSWD: ALL` example in the stock `/etc/sudoers`. The test
    now ignores comment lines, and was checked on the Mac to still catch an active
    NOPASSWD rule.
  - **30 firewall:** a test bug. On the VM, `nftables` is `enabled`, and its boot run
    exited `0/SUCCESS`, then it shows `inactive (dead)`. Arch's packaged unit
    (nftables 1.1.7-3, checked in the Arch packaging repo) is `Type=oneshot` with
    no `RemainAfterExit` and no `ExecStop`. It loads the rules into the kernel and
    exits, and the rules stay loaded. The test now asserts that the unit is enabled and
    that the `inet filter input` chain is live with `policy drop`, not `is-active`. No
    unit drop-in was added: overriding the packaged unit only to change its status
    display isn't worth owning.
- The account was renamed from `Travis` to `travis` on the user's decision (lowercase is
  the portable convention, and renaming only gets harder later). Method: a transient
  `systemd-run` unit that ends the user's session and then runs `usermod -l … -d … -m`
  plus `groupmod -n`. Worth remembering: **`usermod -l` does not rename
  `/etc/subuid` and `/etc/subgid` entries**; they were fixed with `sed`. The tests don't
  hardcode usernames.
- Console quirk: noVNC sometimes drops Shift (`+` came out as `=`, and `_` vanished).
  Workarounds: check Shift characters before pressing Enter, or avoid them (a regex `.`
  in place of `_`).
  **Correction (2026-09-13, user):** the console does not drop Shift. Both incidents
  were ordinary typos, so there is no console quirk to work around.
- **Final green run** (after the fixes and a reboot, logged in as `travis`): 36/36 ok
  (`a6e70ad`), including the new fstab test. Close-out: D-0009 to D-0017 written,
  Omarchy influences recorded, roadmap and README updated, branch merged to `main`.
  **Phase 1 complete.**

## VM → physical hardware notes

- Add CPU microcode (`intel-ucode` / `amd-ucode`) and `linux-firmware`; drop `packages/vm.txt`.
- Partition labels `ESP` and `cryptroot` must be unique across all attached disks (dual boot, USB drives).
- TPM2 auto-unlock (`systemd-cryptenroll`) and Secure Boot signing of UKIs (`sbctl`).
- Hibernation needs disk-backed swap; zram alone cannot hibernate.
- Snapshot-based rollback procedure documented and rehearsed (Phase 8).

## Exit criteria

- [x] All acceptance tests pass on the installed system (green TAP committed: 36/36)
- [x] Unit tests pass (19/19); shellcheck and shfmt clean
- [x] `linux-lts` boot entry verified
- [x] `DECISIONS.md` updated (D-0008 to D-0017)
- [x] `docs/omarchy-influences.md` updated (installer, disk/boot, firewall, services)
- [x] `docs/roadmap.md` status updated
- [x] Branch merged to `main`
