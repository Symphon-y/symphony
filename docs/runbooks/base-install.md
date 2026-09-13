# Runbook: Base Arch Install

Reusable procedure for installing the autarchy base system. It is used in Phase 1 (lab
VM), and again for the rebuild test (Phase 8) and physical hardware (Phase 10).

**Result:** an encrypted Btrfs root with snapshots, booted by systemd-boot from unified
kernel images, with no listening network services. It is verified by
`tests/acceptance/phase-01.bats`.

**Conventions**
- Every command block runs in the live ISO's root shell unless it says otherwise.
- Commands starting with `arch-chroot /mnt` run inside the new system. Everything else
  acts on `/mnt` from outside, so shell variables stay available.
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
| Primary vDisk | virtio, **≥ 40 GiB** | snapshots and two kernels need room |
| Memory / CPUs | **≥ 4 GiB** / **≥ 2** | live ISO runs in RAM; Hyprland later |
| Graphics | leave the default VNC display | no GPU passthrough in Phase 1 |

No Unraid snapshots are needed (D-0008). If an install goes wrong, recover using the
section at the end of this runbook, or reinstall from step 1.

## 1. Get the repo onto the live ISO

Boot the ISO and wait for the root prompt.

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

```sh
lsblk                                  # confirm $DISK is the blank target disk
sgdisk --zap-all "$DISK"
sgdisk -n "1:0:+$ESP_SIZE" -t 1:ef00 -c "1:$ESP_PARTLABEL" \
       -n 2:0:0            -t 2:8309 -c "2:$LUKS_PARTLABEL" "$DISK"
partprobe "$DISK" && udevadm settle

ESP_DEV=/dev/disk/by-partlabel/$ESP_PARTLABEL
LUKS_DEV=/dev/disk/by-partlabel/$LUKS_PARTLABEL
```

LUKS2 with default settings (argon2id). Choose a passphrase using only characters that
are easy to type on a US keyboard through the Unraid console: it is typed there at
every boot.

```sh
cryptsetup luksFormat --type luks2 "$LUKS_DEV"
# --persistent stores allow-discards in the LUKS header, so TRIM works at every boot.
cryptsetup open --allow-discards --persistent "$LUKS_DEV" "$LUKS_MAPPER"
```

Btrfs and subvolumes, from `system/storage/subvolumes.txt`:

```sh
mkfs.btrfs -L "$BTRFS_LABEL" "/dev/mapper/$LUKS_MAPPER"

mount "/dev/mapper/$LUKS_MAPPER" /mnt
while read -r subvol mountpoint; do
  btrfs subvolume create "/mnt/$subvol"
done < <(grep -Ev '^[[:space:]]*(#|$)' system/storage/subvolumes.txt)
umount /mnt

while read -r subvol mountpoint; do
  mount --mkdir -o "$BTRFS_MOUNT_OPTS,subvol=$subvol" "/dev/mapper/$LUKS_MAPPER" "/mnt$mountpoint"
done < <(grep -Ev '^[[:space:]]*(#|$)' system/storage/subvolumes.txt)
```

The ESP. `fmask`/`dmask` keep the boot loader's random seed unreadable to non-root users.

```sh
mkfs.fat -F 32 -n ESP "$ESP_DEV"
mount --mkdir -o fmask=0077,dmask=0077 "$ESP_DEV" "/mnt$ESP_MOUNT"

findmnt -R /mnt                        # check: 5 btrfs subvolumes + vfat at /mnt/efi
```

## 5. Install packages

The package set is exactly what `packages/*.txt` declares.

```sh
PKGS=$(scripts/pkglist packages/*.txt) && pacstrap -K /mnt $PKGS

genfstab -U /mnt >> /mnt/etc/fstab
# Mount by subvolume name only: subvolid= would pin the IDs and break rollback by renaming.
sed -i 's/subvolid=[0-9]*,//g' /mnt/etc/fstab
cat /mnt/etc/fstab                     # check: subvol=/@ ... no subvolid=
```

## 6. Configure the new system

**System config files from the repo:**

```sh
install -Dm644 system/mkinitcpio/10-autarchy.conf  /mnt/etc/mkinitcpio.conf.d/10-autarchy.conf
install -Dm644 system/mkinitcpio/linux.preset      /mnt/etc/mkinitcpio.d/linux.preset
install -Dm644 system/mkinitcpio/linux-lts.preset  /mnt/etc/mkinitcpio.d/linux-lts.preset
install -Dm644 system/zram/zram-generator.conf     /mnt/etc/systemd/zram-generator.conf
install -Dm644 system/resolved/10-autarchy.conf    /mnt/etc/systemd/resolved.conf.d/10-autarchy.conf
install -Dm644 system/nftables/nftables.conf       /mnt/etc/nftables.conf
install -Dm440 system/sudo/10-wheel                /mnt/etc/sudoers.d/10-wheel
arch-chroot /mnt visudo -cf /etc/sudoers.d/10-wheel
```

**Time, locale, console, hostname:**

```sh
ln -sf "/usr/share/zoneinfo/$TZONE" /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc

sed -i "s/^#$LOCALE /$LOCALE /" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LOCALE"   > /mnt/etc/locale.conf
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
echo "$HOST"          > /mnt/etc/hostname
```

**Kernel command line, UKIs, boot loader:**

```sh
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_DEV")
echo "rd.luks.name=$LUKS_UUID=$LUKS_MAPPER root=/dev/mapper/$LUKS_MAPPER rootflags=subvol=@ rw" \
  > /mnt/etc/kernel/cmdline

# pacstrap already built initramfs images with the stock presets; the UKIs replace them.
rm -f /mnt/boot/initramfs-*.img
mkdir -p "/mnt$ESP_MOUNT/EFI/Linux"
arch-chroot /mnt mkinitcpio -P

arch-chroot /mnt bootctl install
install -Dm644 system/boot/loader.conf "/mnt$ESP_MOUNT/loader/loader.conf"
ls "/mnt$ESP_MOUNT/EFI/Linux"          # check: arch-linux.efi, arch-linux-lts.efi, and fallbacks
```

**Users** (you'll be asked for your password):

```sh
arch-chroot /mnt useradd -m -G wheel "$USERNAME"
arch-chroot /mnt passwd "$USERNAME"
# No root password: administration is sudo only; recovery is from the ISO (see Recovery).
arch-chroot /mnt passwd -l root
```

**Services:**

```sh
systemctl --root=/mnt enable \
  NetworkManager.service systemd-resolved.service systemd-timesyncd.service \
  nftables.service systemd-boot-update.service fstrim.timer paccache.timer
```

`qemu-guest-agent` needs no enabling: udev starts it when the VM exposes the guest-agent channel.

## 7. Finish and reboot

```sh
# Outside the chroot on purpose: arch-chroot bind-mounts over /etc/resolv.conf.
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

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
