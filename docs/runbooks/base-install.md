# Runbook: Base Arch Install

Reusable procedure for installing the autarchy base system. It is used in Phase 1 (lab
VM), and again for the rebuild test (Phase 8) and physical hardware (Phase 12).

**Two ways to run this, since Phase 10:**

- **Release ISO (fast path).** Boot the ISO published on the repo's GitHub
  Releases page (built by `.github/workflows/release-iso.yml` from a tagged
  commit on `main`). Since Phase 13, this ISO is fully offline-capable: the
  entire `packages/*.txt` closure is baked in. Since Phase 14, the repo
  itself is baked in too, at `/root/autarchy`. No network connection or
  GitHub access is needed at all to install (use the stock-ISO manual path
  below only if there's some other reason to run it by hand).

  **If the release is split into multiple files** (`autarchy-<tag>.iso.00.part`,
  `.01.part`, etc. -- GitHub Releases refuses any single file at or above
  2 GiB, and this ISO's full offline package set can exceed that), download
  every part plus `autarchy-<tag>.iso.sha256`, then reassemble and verify
  before writing to USB:
  ```sh
  cat autarchy-<tag>.iso.*.part >autarchy-<tag>.iso
  sha256sum -c autarchy-<tag>.iso.sha256
  ```
  Only write the reassembled file to USB once that reports `OK`.

  **The whole runbook below (steps 1-7) is replaced by one guided
  command**, printed on screen the moment you log in:
  ```sh
  autarchy-install
  ```
  It shows a ground-truth report of the
  machine (CPU/memory/GPU/storage/network), asks a handful of plain
  questions in order (disk, hostname, username, timezone, locale, keymap,
  optional hibernation size), shows a review screen, then hands off to
  `install/install-base-system` -- which prints exactly what it's about to
  do to the disk, requires typing the disk path back to confirm before
  anything destructive happens (a second, stronger checkpoint, not a
  duplicate of the review screen), then runs unattended through to a
  rebootable system and offers to reboot. No steps below need typing by
  hand on this path.
- **Stock Arch ISO (manual path, kept as the documented fallback).** Every
  step below, typed by hand -- still the recovery path from the "Recovery"
  section at the end, and still how this runbook stays understandable step
  by step (D-0009).

Both paths produce an identical result, verified by the same
`tests/acceptance/phase-01.bats`.

**Result:** an encrypted Btrfs root with snapshots, booted by systemd-boot from unified
kernel images, with no listening network services. It is verified by
`tests/acceptance/phase-01.bats`.

**Conventions**
- Every command block runs in the live ISO's root shell unless it says otherwise. That
  shell is **zsh** (the installed system's user shell is bash). Commands here work in
  both. Setting `HOST` in zsh also changes the prompt's hostname, which is harmless.
- Config files come from `system/`. Each one names its target path in its header.
- Anything unexpected: stop, take a screenshot, and record it in the tracking doc.
  Don't improvise changes.

---

## 0. Unraid prerequisites

In the VM's settings in Unraid:

| Setting | Value | Why |
|---|---|---|
| BIOS | **OVMF** (UEFI) | systemd-boot and UKIs need UEFI; real hardware will be UEFI |
| Network bridge | `br0` or the default. Either works because there is no SSH | DHCP and internet access |
| Primary vDisk | virtio, **≥ 40 GiB** | Btrfs snapshots and two kernels need room |
| Memory / CPUs | **≥ 4 GiB** / **≥ 2** | live ISO runs in RAM; Hyprland later |
| Graphics | leave the default VNC display | no GPU passthrough in Phase 1 |

No Unraid snapshots are needed (D-0008). If an install goes wrong, recover using the
section at the end of this runbook, or reinstall from step 1.

## 1. Get the repo onto the live ISO

Boot the ISO and wait for the root prompt.

**On the release ISO**, the repo is already at `/root/autarchy` (baked in at
build time, Phase 14) -- everything below down to (not including) `source
base-install.local.vars` is unnecessary: just `cd /root/autarchy`.

**On a stock Arch ISO:**

```sh
# The ISO's writable overlay defaults to a small RAM disk; git, gh, and bats need more.
mount -o remount,size=2G /run/archiso/cowspace

pacman -Sy --noconfirm git github-cli

# Prints a one-time code and a URL. On the Mac, open https://github.com/login/device
# and enter the code. The token lives only in this ISO's RAM.
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git

gh repo clone Symphon-y/autarchy /root/autarchy -- --branch phase/01-base-install
cd /root/autarchy
git config --global user.name  "<your name>"
git config --global user.email "<your email>"
```

Set the install variables (see the comments in the file):

```sh
cp docs/runbooks/base-install.vars.example base-install.local.vars
vim base-install.local.vars
source base-install.local.vars
source system/storage/layout.conf

# Stop here if any of these print an error.
: "${DISK:?}" "${HOST:?}" "${USERNAME:?}" "${TZONE:?}" "${LOCALE:?}" "${KEYMAP:?}"
```

> If you reboot the ISO or open a new shell, repeat the `cd` and both `source` lines.

## 2. Inspect the machine

```sh
mkdir -p docs/environment
scripts/system-report | tee docs/environment/vm-lab.md
git add docs/environment/vm-lab.md
git commit -m "Phase 1: VM environment report"
git push
```

The report ends with an **Install gates** table. **Wait for Claude to review the report**
on the Mac before continuing. A failed gate, or anything surprising about the virtual
hardware, may change the plan.

## 3. Red: the tests must fail before the install

```sh
pacman -S --noconfirm bats bats-assert bats-support

bats tests/unit                       # expected: all pass (already green on the Mac)

mkdir -p docs/phases/evidence
bats --formatter tap tests/acceptance | tee docs/phases/evidence/phase-01-red.tap
git add docs/phases/evidence/phase-01-red.tap
git commit -m "Phase 1: acceptance tests red on live ISO"
git push
```

Most tests should report `not ok`. The UEFI test may pass already; that's expected.

## 4. Partition, encrypt, create filesystems

**On the release ISO**, `install/install-base-system base-install.local.vars`
does steps 4-6 in one command (see the top of this runbook) -- skip to
step 7. The manual commands below are the fallback path and what that script
itself runs.

```sh
lsblk                                  # confirm $DISK is the blank target disk
sgdisk --zap-all "$DISK"
sgdisk -n "1:0:+$ESP_SIZE" -t 1:ef00 -c "1:$ESP_PARTLABEL" \
       -n 2:0:0            -t 2:8309 -c "2:$LUKS_PARTLABEL" "$DISK"
sgdisk -p "$DISK"                      # check: 1 = 2.0 GiB EF00 ESP, 2 = rest 8309 cryptroot
partprobe "$DISK" && udevadm settle

ESP_DEV=/dev/disk/by-partlabel/$ESP_PARTLABEL
LUKS_DEV=/dev/disk/by-partlabel/$LUKS_PARTLABEL
```

LUKS2 with default settings (argon2id). Choose a passphrase using only characters that
are easy to type on a US keyboard through the Unraid console: it is typed there at
every boot. Check first that Shift survives the console: `echo +` must print `+`.

```sh
cryptsetup luksFormat --type luks2 "$LUKS_DEV"
# --persistent stores allow-discards in the LUKS header, so TRIM works at every boot.
cryptsetup open --allow-discards --persistent "$LUKS_DEV" "$LUKS_MAPPER"
```

Btrfs and subvolumes, from `system/storage/subvolumes.txt`:

```sh
mkfs.btrfs -L "$BTRFS_LABEL" "/dev/mapper/$LUKS_MAPPER"

mount "/dev/mapper/$LUKS_MAPPER" /mnt
while read -r subvol mountpoint; do btrfs subvolume create "/mnt/$subvol"; done < <(grep -Ev '^[[:space:]]*(#|$)' system/storage/subvolumes.txt)
btrfs subvolume list /mnt              # check: @ @home @log @pkg @snapshots
umount /mnt
findmnt /mnt                           # check: prints NOTHING. If it prints a mount, run umount /mnt again.

while read -r subvol mountpoint; do mount --mkdir -o "$BTRFS_MOUNT_OPTS,subvol=$subvol" "/dev/mapper/$LUKS_MAPPER" "/mnt$mountpoint"; done < <(grep -Ev '^[[:space:]]*(#|$)' system/storage/subvolumes.txt)
```

The ESP. `fmask`/`dmask` keep the boot loader's random seed unreadable to non-root users.

```sh
mkfs.fat -F 32 -n ESP "$ESP_DEV"
mount --mkdir -t vfat -o fmask=0077,dmask=0077 "$ESP_DEV" "/mnt$ESP_MOUNT"

findmnt -R /mnt                        # check: 5 btrfs subvolumes + vfat at /mnt/efi
```

## 5. Install packages

The package set is exactly what `packages/*.txt` declares.

```sh
# Command substitution, not a variable: the ISO's zsh doesn't word-split unquoted
# variables, but it does split $(...), and so does bash.
pacstrap -K /mnt $(scripts/pkglist packages/*.txt)

# `>` not `>>`: running this line twice must not duplicate every entry.
genfstab -U /mnt > /mnt/etc/fstab
# Mount by subvolume name only: subvolid= would pin the IDs and break rollback by renaming.
sed -i 's/subvolid=[0-9]*,//g' /mnt/etc/fstab
cat /mnt/etc/fstab                     # check: subvol=/@ ... no subvolid=, no "subvol=/" line
grep -c '^UUID=' /mnt/etc/fstab        # check: exactly 6 (5 subvolumes + ESP)
```

## 6. Configure the new system

`install/configure-base-system` does this step. Read it first: it's one short function
per part, running in order. The script is the source of truth; the table only
summarizes it. It checks everything it needs before changing anything, stops at the
first error, and is safe to re-run. It asks for your user's password once.

```sh
git pull                               # fetch the script if this clone predates it
install/configure-base-system base-install.local.vars
ls /mnt/efi/EFI/Linux                  # check: arch-linux.efi, arch-linux-lts.efi, and both -fallback.efi
```

| Part | What it does |
|---|---|
| preflight | Requires root, `/mnt` and `/mnt/efi` mounted, and an fstab. Validates the vars, timezone, and locale. |
| system files | Installs the `system/*` files to their target paths; validates sudoers with `visudo` |
| identity | Timezone and hardware clock; locale; console keymap; hostname |
| boot | `/etc/kernel/cmdline` with the LUKS UUID; replaces the stock initramfs images with UKIs (`mkinitcpio -P`); installs systemd-boot and `loader.conf` |
| users | Creates the wheel user (asks for the password); locks root |
| services | Enables NetworkManager, resolved, timesyncd, nftables, systemd-boot-update, fstrim.timer, paccache.timer |
| resolv.conf | Links to the systemd-resolved stub. Done last, because `arch-chroot` bind-mounts over this file. |

`qemu-guest-agent` needs no enabling: udev starts it when the VM exposes the guest-agent channel.

## 7. Finish and reboot

```sh
umount -R /mnt
cryptsetup close "$LUKS_MAPPER"
poweroff
```

In Unraid, **remove the ISO** from the VM, then start it. In the Unraid console, type
the LUKS passphrase at the prompt and log in as your user.

## 8. First boot

Everything from here runs **as your user** in the Unraid console.

**Snapper.** `snapper create-config` insists on creating `/.snapshots` itself. So
remove our mount, let snapper create its config, then swap its nested subvolume for our
top-level `@snapshots`, which stays out of snapshots of `/`.

```sh
sudo umount /.snapshots
sudo rmdir /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
sudo chmod 750 /.snapshots
sudo snapper -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=10
sudo systemctl enable --now snapper-cleanup.timer
```

**Repo:**

```sh
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
mkdir -p ~/Projects
gh repo clone Symphon-y/autarchy ~/Projects/autarchy -- --branch phase/01-base-install
cd ~/Projects/autarchy
git config --global user.name  "<your name>"
git config --global user.email "<your email>"
```

> `gh` stores its token in `~/.config/gh/hosts.yml` because there is no keyring on a
> text console. Phase 2 revisits this.

**Green:**

```sh
sudo -v
bats --formatter tap tests/acceptance | tee docs/phases/evidence/phase-01-green.tap
git add docs/phases/evidence/phase-01-green.tap
git commit -m "Phase 1: acceptance tests green on installed system"
git push
```

If anything is `not ok`, push the TAP file anyway. Claude fixes the cause from the Mac,
you `git pull` and re-run. Don't edit repo files in the VM.

## 9. Verify recovery paths

```sh
# snap-pac: reinstalling an existing package creates a pre/post snapshot pair
# without adding an undeclared package.
sudo pacman -S --noconfirm less
sudo snapper -c root list              # check: a pre and a post snapshot
```

Reboot, and in the systemd-boot menu choose **Arch Linux (linux-lts)**. After login:

```sh
uname -r                               # check: ends in -lts
```

Reboot again into the default entry.

---

## Recovery: getting back into the installed system from the ISO

```sh
cryptsetup open /dev/disk/by-partlabel/cryptroot root
mount -o subvol=@ /dev/mapper/root /mnt
mount -o subvol=@home /dev/mapper/root /mnt/home
mount -o subvol=@log /dev/mapper/root /mnt/var/log
mount -o subvol=@pkg /dev/mapper/root /mnt/var/cache/pacman/pkg
mount /dev/disk/by-partlabel/ESP /mnt/efi
arch-chroot /mnt
```

From there: rebuild UKIs (`mkinitcpio -P`), fix config, or reset a password.
