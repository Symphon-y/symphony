#!/usr/bin/env bats
# Phase 1 acceptance tests: the base Arch install.
#
# Run on the installed system as the regular user, after `sudo -v`:
#   bats tests/acceptance/phase-01.bats
# Tests check properties, never machine-specific values like the hostname.
# Red run: from the live ISO before installing, where they must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
  # shellcheck source-path=SCRIPTDIR source=../../system/storage/layout.conf
  source "$REPO_ROOT/system/storage/layout.conf"
}

layout_subvolumes() {
  grep -Ev '^[[:space:]]*(#|$)' "$REPO_ROOT/system/storage/subvolumes.txt"
}

duplicate_fstab_mountpoints() {
  awk '!/^[[:space:]]*#/ && NF { print $2 }' /etc/fstab | sort | uniq -d
}

# Listening sockets not bound to loopback. DHCP clients (ports 68 and 546) keep a
# socket open to receive lease renewals; they are clients, not services. sshd (22)
# may be running on demand; phase-02.bats proves the firewall restricts who can reach it.
public_listeners() {
  ss -Htuln | awk '{ print $5 }' |
    grep -Ev '^(127\.|\[::1\]|\[::ffff:127\.)' |
    grep -Ev ':(22|68|546)$'
}

# --- boot ---------------------------------------------------------------------

@test "boot: firmware is 64-bit UEFI" {
  run cat /sys/firmware/efi/fw_platform_size
  assert_output "64"
}

@test "boot: systemd-boot is installed on the ESP" {
  run as_root bootctl is-installed
  assert_success
}

@test "boot: unified kernel images exist for linux and linux-lts" {
  run as_root bootctl list --no-pager
  assert_success
  assert_output --partial "arch-linux.efi"
  assert_output --partial "arch-linux-lts.efi"
}

@test "boot: the boot menu does not allow editing the kernel command line" {
  run as_root grep -Eq '^editor[[:space:]]+no' "$ESP_MOUNT/loader/loader.conf"
  assert_success
}

@test "boot: the kernel command line unlocks root through sd-encrypt" {
  run cat /proc/cmdline
  assert_output --partial "rd.luks.name="
  assert_output --partial "root=/dev/mapper/$LUKS_MAPPER"
}

# --- storage ------------------------------------------------------------------

@test "storage: / is btrfs on the LUKS mapping" {
  run findmnt -no FSTYPE /
  assert_output "btrfs"
  run findmnt -no SOURCE /
  assert_output --partial "/dev/mapper/$LUKS_MAPPER"
}

@test "storage: the root mapping is LUKS2 with discards allowed" {
  run as_root cryptsetup status "$LUKS_MAPPER"
  assert_success
  assert_output --regexp 'type: +LUKS2'
  assert_output --regexp 'flags: +discards'
}

@test "storage: every subvolume in the layout is mounted where declared" {
  local subvol mountpoint
  while read -r subvol mountpoint; do
    run findmnt -no SOURCE,OPTIONS "$mountpoint"
    assert_success
    assert_output --partial "[/$subvol]"
    assert_output --partial "noatime"
    assert_output --partial "compress=zstd"
  done < <(layout_subvolumes)
}

@test "storage: fstab declares each mountpoint exactly once" {
  run test -r /etc/fstab
  assert_success
  run duplicate_fstab_mountpoints
  assert_output ""
}

@test "storage: the ESP is vfat at the ESP mountpoint and not world-readable" {
  run findmnt -no FSTYPE,OPTIONS "$ESP_MOUNT"
  assert_success
  assert_output --regexp '^vfat .*fmask=0077'
}

@test "storage: periodic TRIM is enabled" {
  run systemctl is-enabled fstrim.timer
  assert_output "enabled"
}

# --- swap and snapshots -------------------------------------------------------

@test "swap: zram swap is active" {
  run swapon --noheadings --show=NAME
  assert_output --partial "zram"
}

@test "snapshots: snapper root config exists with timeline snapshots off" {
  run as_root snapper --csvout -c root get-config
  assert_success
  assert_line "TIMELINE_CREATE,no"
}

@test "snapshots: old snapshots are cleaned up on a timer" {
  run systemctl is-enabled snapper-cleanup.timer
  assert_output "enabled"
}

@test "snapshots: pacman transactions are snapshotted by snap-pac" {
  run pacman -Q snap-pac
  assert_success
}

# --- identity -----------------------------------------------------------------

@test "identity: hostname is set and is not the installer's" {
  run hostnamectl hostname
  assert_success
  refute_output ""
  refute_output "archiso"
}

@test "identity: a UTF-8 locale is configured" {
  run localectl status
  assert_output --regexp 'LANG=[^ ]+\.UTF-8'
}

@test "identity: a console keymap is configured" {
  run localectl status
  assert_output --regexp 'VC Keymap: [a-z]'
}

@test "identity: timezone is set and the clock is NTP-synchronized" {
  run timedatectl show -p Timezone --value
  assert_success
  refute_output ""
  run timedatectl show -p NTPSynchronized --value
  assert_output "yes"
}

# --- network ------------------------------------------------------------------

@test "network: NetworkManager and systemd-resolved are active" {
  run systemctl is-active NetworkManager systemd-resolved
  assert_success
}

@test "network: resolv.conf points at the systemd-resolved stub" {
  run readlink /etc/resolv.conf
  assert_output --partial "stub-resolv.conf"
}

@test "network: public DNS names resolve" {
  run getent hosts archlinux.org
  assert_success
}

@test "network: HTTPS to archlinux.org works" {
  run curl -fsS -o /dev/null --max-time 15 https://archlinux.org
  assert_success
}

# --- packages -----------------------------------------------------------------

@test "packages: the pacman database is consistent" {
  run pacman -Dk
  assert_success
}

@test "packages: installed packages match packages/*.txt in both directions, and every foreign package is a declared choice" {
  # Originally two separate checks (explicit-vs-declared; zero-foreign-packages
  # allowed at all). Phase 1 had no AUR packages; Phase 4 onward deliberately
  # installs some via yay (D-0030), so "zero foreign packages" stopped being the
  # right invariant -- "every one is declared, confined to desktop.txt" (the one
  # file CI never installs with plain pacman) is. scripts/pkg-audit (Phase 8) is
  # now the one place this logic lives; kept as an acceptance test here too since
  # phase-01.bats is where this invariant started.
  run "$REPO_ROOT/scripts/pkg-audit"
  assert_success
}

# --- security -----------------------------------------------------------------

@test "security: tests run as a non-root member of wheel" {
  assert [ "$(id -u)" -ne 0 ]
  run id -Gn
  assert_output --regexp '(^| )wheel( |$)'
}

@test "security: the root account is locked" {
  run as_root passwd -S root
  assert_output --regexp '^root L '
}

@test "security: sudo never skips the password" {
  # Only active rules count: the stock /etc/sudoers ships a commented-out NOPASSWD example.
  run as_root grep -rEs '^[^#]*(NOPASSWD|!authenticate)' /etc/sudoers /etc/sudoers.d
  assert_output ""
}

@test "security: the sudoers configuration is valid" {
  run as_root visudo -c
  assert_success
}

@test "security: the firewall drops unsolicited inbound traffic" {
  # Arch's nftables.service is a oneshot without RemainAfterExit: it loads the rules and
  # then reports inactive. So check what matters: it loads at boot, and the rules are live.
  run systemctl is-enabled nftables
  assert_output "enabled"
  run as_root nft list chain inet filter input
  assert_success
  assert_output --partial "policy drop"
}

@test "security: nothing listens beyond loopback except DHCP clients and on-demand sshd" {
  run ss -Htuln
  assert_success
  run public_listeners
  assert_output ""
}

@test "security: the SSH server is not started at boot" {
  # D-0015 (no SSH server) was superseded in Phase 2: sshd exists for on-demand
  # sessions from a trusted jump host, but must never start on its own.
  run systemctl is-enabled sshd
  refute_output "enabled"
}

# --- health -------------------------------------------------------------------

@test "health: no systemd units have failed" {
  run systemctl --failed --no-legend --plain
  assert_success
  assert_output ""
}

@test "health: the system reports itself fully running" {
  run systemctl is-system-running
  assert_output "running"
}

@test "vm: the QEMU guest agent is active" {
  local virt
  virt=$(systemd-detect-virt 2>/dev/null || true)
  [[ $virt == kvm || $virt == qemu ]] || skip "not a QEMU/KVM guest"
  run systemctl is-active qemu-guest-agent
  assert_output "active"
}
