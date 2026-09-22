#!/usr/bin/env bats
# Unit tests for install/install-base-system. Every disk-management command is
# stubbed on PATH so the script never touches real block devices; the sibling
# configure-base-system script it hands off to is overridden via
# AUTARCHY_CONFIGURE_SCRIPT to a stub, mirroring scripts/migrate's
# AUTARCHY_MIGRATIONS_DIR-style test override.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/install-base-system"
  TARGET="$BATS_TEST_TMPDIR/target"
  mkdir -p "$TARGET"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  # Absent by default so seed_release_marker no-ops in every test that
  # doesn't explicitly exercise it -- a real /etc/autarchy-release on the
  # machine running these tests must never leak in.
  export AUTARCHY_LIVE_RELEASE_FILE="$BATS_TEST_TMPDIR/no-release-file"
  # Quirks come from this machine's DMI; hermetic unless a test stubs them (D-0076).
  stub "$BATS_TEST_TMPDIR/no-quirks" 'exit 0'
  export AUTARCHY_QUIRKPARAMS_SCRIPT="$BATS_TEST_TMPDIR/no-quirks"
  make_vars
  make_stubs
}

make_vars() {
  VARS="$BATS_TEST_TMPDIR/test.local.vars"
  cat >"$VARS" <<'EOF'
DISK=/dev/vda
HOST=testhost
USERNAME=alice
TZONE=America/Chicago
LOCALE=en_US.UTF-8
KEYMAP=us
EOF
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1"
  chmod +x "$1"
}

# Stub bodies are single-quoted on purpose: they must expand when the stub runs, not here.
# shellcheck disable=SC2016
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"

  stub "$bin/id" 'if [[ ${1:-} == -u ]]; then echo "${STUB_UID:-0}"; else exec /usr/bin/id "$@"; fi'

  cat >"$bin/lsblk" <<'EOF'
#!/usr/bin/env bash
echo "lsblk $*" >>"$STUB_LOG"
case "$1 $2" in
  "-dno TYPE") echo "${STUB_DISK_TYPE-disk}" ;;
  "-no MOUNTPOINT") [[ -n ${STUB_DISK_MOUNTED:-} ]] && echo "${STUB_DISK_MOUNTED}" ;;
esac
EOF
  chmod +x "$bin/lsblk"

  stub "$bin/mountpoint" 'echo "mountpoint $*" >>"$STUB_LOG"; exit "${STUB_TARGET_MOUNTED:-1}"'
  stub "$bin/sgdisk" 'echo "sgdisk $*" >>"$STUB_LOG"'
  stub "$bin/partprobe" 'echo "partprobe $*" >>"$STUB_LOG"'
  stub "$bin/udevadm" 'echo "udevadm $*" >>"$STUB_LOG"'
  # Logs its stdin too, but only when --key-file - is present: that's the
  # one case a test needs to see what actually flowed through (the
  # passphrase read from fd 9). Every other call has no meaningful stdin.
  cat >"$bin/cryptsetup" <<'EOF'
#!/usr/bin/env bash
echo "cryptsetup $*" >>"$STUB_LOG"
if [[ "$*" == *"--key-file -"* ]]; then
  echo "cryptsetup stdin: $(cat)" >>"$STUB_LOG"
fi
EOF
  chmod +x "$bin/cryptsetup"
  stub "$bin/mkfs.btrfs" 'echo "mkfs.btrfs $*" >>"$STUB_LOG"'
  stub "$bin/mkfs.fat" 'echo "mkfs.fat $*" >>"$STUB_LOG"'
  stub "$bin/btrfs" 'echo "btrfs $*" >>"$STUB_LOG"'
  stub "$bin/mount" 'echo "mount $*" >>"$STUB_LOG"'
  stub "$bin/umount" 'echo "umount $*" >>"$STUB_LOG"'
  stub "$bin/pacstrap" 'echo "pacstrap $*" >>"$STUB_LOG"; mkdir -p "$3/etc"'
  stub "$bin/genfstab" 'echo "UUID=x / btrfs subvolid=256,subvol=/@ 0 0"'
  stub "$bin/blkid" 'echo "blkid $*" >>"$STUB_LOG"; echo "3333-4444"'
  stub "$bin/mkswap" 'echo "mkswap $*" >>"$STUB_LOG"'
  stub "$bin/arch-chroot" 'echo "arch-chroot $*" >>"$STUB_LOG"'

  # Also logs fd 8's content, if open -- the one way a test can confirm
  # install-base-system passes it through to configure-base-system
  # untouched (D-0066: fd 8 is the user password, fd 9 the LUKS
  # passphrase -- install-base-system consumes fd 9 itself but must never
  # touch fd 8, which isn't its concern).
  cat >"$bin/autarchy-configure-stub" <<'EOF'
#!/usr/bin/env bash
echo "configure-base-system $*" >>"$STUB_LOG"
if [[ -e /dev/fd/8 ]]; then
  read -r p <&8
  echo "configure-base-system fd8: $p" >>"$STUB_LOG"
fi
EOF
  chmod +x "$bin/autarchy-configure-stub"
  export AUTARCHY_CONFIGURE_SCRIPT="$bin/autarchy-configure-stub"

  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

run_confirmed() {
  run bash -c "echo /dev/vda | \"$SCRIPT\" \"$VARS\" \"$TARGET\""
}

# Same disk-path confirmation on stdin (fd 0), plus a passphrase on fd 9 --
# the contract the terminal collector and the future GUI both use.
run_confirmed_with_passphrase() {
  run bash -c "echo /dev/vda | \"$SCRIPT\" \"$VARS\" \"$TARGET\" 9<<<'testpass123'"
}

@test "fails and names the variable when a required value is missing" {
  echo "DISK=" >>"$VARS"
  run_confirmed
  assert_failure
  assert_output --partial "DISK"
  run calls
  assert_output ""
}

@test "fails when not run as root" {
  export STUB_UID=1000
  run_confirmed
  assert_failure
  assert_output --partial "must run as root"
}

@test "fails when the disk is not a block device" {
  export STUB_DISK_TYPE=""
  run_confirmed
  assert_failure
  assert_output --partial "is not a block device"
  run calls
  refute_output --partial "sgdisk"
}

@test "fails when the target is already mounted" {
  export STUB_TARGET_MOUNTED=0
  run_confirmed
  assert_failure
  assert_output --partial "already mounted"
  run calls
  refute_output --partial "sgdisk"
}

@test "fails when the disk has a mounted partition" {
  export STUB_DISK_MOUNTED=/mnt/somewhere
  run_confirmed
  assert_failure
  assert_output --partial "has a mounted partition"
  run calls
  refute_output --partial "sgdisk"
}

@test "aborts and touches nothing when the confirmation does not match the disk" {
  run bash -c "echo /dev/sdb | \"$SCRIPT\" \"$VARS\" \"$TARGET\""
  assert_failure
  assert_output --partial "aborting"
  run calls
  refute_output --partial "sgdisk"
}

@test "aborts on a disk-path mismatch even with a passphrase fd open (fd 0/fd 9 don't collide)" {
  run bash -c "echo /dev/sdb | \"$SCRIPT\" \"$VARS\" \"$TARGET\" 9<<<'testpass123'"
  assert_failure
  assert_output --partial "aborting"
  run calls
  refute_output --partial "sgdisk"
}

@test "partitions the disk with the ESP and cryptroot labels from layout.conf" {
  run_confirmed
  assert_success
  run calls
  assert_line --regexp 'sgdisk --zap-all /dev/vda'
  assert_line --regexp 'sgdisk -n 1:0:\+2G -t 1:ef00 -c 1:ESP -n 2:0:0 -t 2:8309 -c 2:cryptroot /dev/vda'
}

@test "encrypts the LUKS partition interactively when no passphrase fd is given, and creates every declared subvolume" {
  # No fd 9 here (run_confirmed, not run_confirmed_with_passphrase): the
  # documented manual/recovery runbook path calls this script directly,
  # with no collector at all, and must keep working exactly like today --
  # cryptsetup's own interactive prompt, no --key-file.
  run_confirmed
  assert_success
  run calls
  assert_line "cryptsetup luksFormat --type luks2 /dev/disk/by-partlabel/cryptroot"
  assert_line "cryptsetup open --allow-discards --persistent /dev/disk/by-partlabel/cryptroot root"
  assert_line "btrfs subvolume create /mnt/@"
  assert_line "btrfs subvolume create /mnt/@home"
  assert_line "btrfs subvolume create /mnt/@log"
  assert_line "btrfs subvolume create /mnt/@pkg"
  assert_line "btrfs subvolume create /mnt/@snapshots"
}

@test "encrypts the LUKS partition unattended when a passphrase fd is given (Phase 15/D-0066)" {
  run_confirmed_with_passphrase
  assert_success
  run calls
  assert_line "cryptsetup luksFormat --type luks2 --key-file - /dev/disk/by-partlabel/cryptroot"
  assert_line "cryptsetup open --allow-discards --persistent --key-file - /dev/disk/by-partlabel/cryptroot root"
  # Confirms the actual passphrase content flowed through via stdin, not
  # just that --key-file - was passed -- and that it's read once and
  # reused for both calls, not lost after the first (a real, checked-for
  # bug: cryptsetup runs twice here, and a second read from the same fd
  # would just get EOF since the file offset is shared once inherited).
  assert_line "cryptsetup stdin: testpass123"
  local count
  count=$(grep -c '^cryptsetup stdin: testpass123$' <<<"$output")
  assert_equal "$count" "2"
}

@test "passes fd 8 through to configure-base-system untouched, alongside consuming fd 9 itself (Phase 15/D-0066)" {
  # fd 8 is the user account password -- not this script's concern (see
  # configure-base-system) -- but it's easy to imagine a change here that
  # accidentally closes or reads it while handling fd 9. Confirms it
  # survives, unread by this script, all the way to the hand-off.
  run bash -c "echo /dev/vda | \"$SCRIPT\" \"$VARS\" \"$TARGET\" 8<<<'userpass456' 9<<<'testpass123'"
  assert_success
  run calls
  assert_line "configure-base-system fd8: userpass456"
}

@test "formats the ESP with restrictive permissions" {
  run_confirmed
  assert_success
  run calls
  assert_line "mkfs.fat -F 32 -n ESP /dev/disk/by-partlabel/ESP"
  assert_line --partial "fmask=0077,dmask=0077"
}

@test "pacstraps every declared package and writes fstab without subvolid" {
  run_confirmed
  assert_success
  run calls
  assert_line --partial "pacstrap -K -M $TARGET"

  run cat "$TARGET/etc/fstab"
  refute_output --partial "subvolid="
  assert_output --partial "subvol=/@"
}

@test "hands off to configure-base-system as the last step" {
  run_confirmed
  assert_success
  run calls
  assert_line "configure-base-system $VARS $TARGET"
}

@test "SWAP_SIZE unset: partitions only ESP and cryptroot, no swap-related calls" {
  run_confirmed
  assert_success
  run calls
  refute_output --partial "cryptswap"
  refute_output --partial "mkswap"
  assert [ ! -e "$TARGET/etc/crypttab" ]
}

# --- SWAP_SIZE set: hibernation-capable swap partition (Phase 12) ----------

with_swap() {
  echo "SWAP_SIZE=16G" >>"$VARS"
}

@test "SWAP_SIZE set: partitions ESP, swap, and cryptroot in that order" {
  with_swap
  run_confirmed
  assert_success
  run calls
  assert_line --regexp \
    'sgdisk -n 1:0:\+2G -t 1:ef00 -c 1:ESP -n 2:0:\+16G -t 2:8309 -c 2:cryptswap -n 3:0:0 -t 3:8309 -c 3:cryptroot /dev/vda'
}

@test "SWAP_SIZE set: generates a keyfile and LUKS2-formats the swap partition with it, no prompt" {
  with_swap
  run_confirmed
  assert_success

  assert [ -f "$TARGET/etc/cryptsetup-keys.d/cryptswap.key" ]
  run stat -c '%a' "$TARGET/etc/cryptsetup-keys.d/cryptswap.key"
  assert_output "600"

  run calls
  assert_line "cryptsetup luksFormat --type luks2 --batch-mode --key-file $TARGET/etc/cryptsetup-keys.d/cryptswap.key /dev/disk/by-partlabel/cryptswap"
  assert_line "cryptsetup open --key-file $TARGET/etc/cryptsetup-keys.d/cryptswap.key /dev/disk/by-partlabel/cryptswap cryptswap"
  assert_line "mkswap /dev/mapper/cryptswap"
}

@test "SWAP_SIZE set: adds crypttab and fstab entries, and embeds the keyfile via mkinitcpio FILES=" {
  with_swap
  run_confirmed
  assert_success

  assert_equal "$(cat "$TARGET/etc/crypttab")" \
    "cryptswap UUID=3333-4444 /etc/cryptsetup-keys.d/cryptswap.key luks,x-initrd.attach"
  run grep -Fx '/dev/mapper/cryptswap none swap defaults 0 0' "$TARGET/etc/fstab"
  assert_success
  assert_equal "$(cat "$TARGET/etc/mkinitcpio.conf.d/20-swap-resume.conf")" \
    "FILES=(/etc/cryptsetup-keys.d/cryptswap.key)"
}

@test "SWAP_SIZE set: passes AUTARCHY_RESUME_DEVICE to configure-base-system" {
  with_swap
  cat >"$BATS_TEST_TMPDIR/bin/autarchy-configure-stub" <<'EOF'
#!/usr/bin/env bash
echo "configure-base-system $* resume=${AUTARCHY_RESUME_DEVICE:-unset}" >>"$STUB_LOG"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/autarchy-configure-stub"
  run_confirmed
  assert_success
  run calls
  assert_line "configure-base-system $VARS $TARGET resume=/dev/mapper/cryptswap"
}

# --- release marker (Phase 12; retired in Phase 18) ------------------------

@test "no per-user release marker is seeded: the payload's VERSION is the installed release (D-0079)" {
  echo "2026.09.16" >"$AUTARCHY_LIVE_RELEASE_FILE"
  run_confirmed
  assert_success
  assert [ ! -e "$TARGET/home/alice/.local/state/autarchy/current-release" ]
  run calls
  refute_line "arch-chroot $TARGET chown -R alice:alice /home/alice/.local"
}

# scripts/hwpkglist answers from the PCI bus and is tested on its own; here it is a stub.
hwpkglist_stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$1" >"$BATS_TEST_TMPDIR/hwpkglist-stub"
  chmod +x "$BATS_TEST_TMPDIR/hwpkglist-stub"
}

@test "pacstraps the packages this machine's hardware needs on top of the declared ones (Phase 17)" {
  hwpkglist_stub 'printf "broadcom-wl-dkms\nlinux-headers\n"'
  AUTARCHY_HWPKGLIST_SCRIPT="$BATS_TEST_TMPDIR/hwpkglist-stub" run_confirmed
  assert_success
  run calls
  assert_line --partial "pacstrap -K -M $TARGET"
  assert_line --partial " broadcom-wl-dkms"
  assert_line --partial " linux-headers"
  # ...alongside the ordinary inventory, not instead of it.
  assert_line --partial " networkmanager"
}

@test "pacstraps no hardware-specific packages when the hardware needs none (Phase 17)" {
  hwpkglist_stub 'exit 0'
  AUTARCHY_HWPKGLIST_SCRIPT="$BATS_TEST_TMPDIR/hwpkglist-stub" run_confirmed
  assert_success
  run calls
  refute_output --partial "broadcom-wl-dkms"
}

@test "a failing hardware lookup stops the install before pacstrap touches anything (Phase 17)" {
  hwpkglist_stub 'echo "hwpkglist: broken map" >&2; exit 1'
  AUTARCHY_HWPKGLIST_SCRIPT="$BATS_TEST_TMPDIR/hwpkglist-stub" run_confirmed
  assert_failure
  run calls
  refute_output --partial "pacstrap"
}

# --- firmware quirks (D-0076) ------------------------------------------------------

# scripts/quirkparams answers from the DMI data and is tested on its own; here it is a stub.
quirkparams_stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$1" >"$BATS_TEST_TMPDIR/quirkparams-stub"
  chmod +x "$BATS_TEST_TMPDIR/quirkparams-stub"
  export AUTARCHY_QUIRKPARAMS_SCRIPT="$BATS_TEST_TMPDIR/quirkparams-stub"
}

configure_stub_reporting_params() {
  cat >"$BATS_TEST_TMPDIR/bin/autarchy-configure-stub" <<'STUB'
#!/usr/bin/env bash
echo "configure-base-system params=${AUTARCHY_KERNEL_PARAMS-unset}" >>"$STUB_LOG"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/autarchy-configure-stub"
}

@test "hands the kernel parameters this machine's quirks need to configure-base-system (D-0076)" {
  quirkparams_stub 'printf "module_blacklist=dell_rbtn\nquiet\n"'
  configure_stub_reporting_params
  run_confirmed
  assert_success
  run calls
  assert_line "configure-base-system params=module_blacklist=dell_rbtn quiet"
}

@test "hands over no kernel parameters when the machine has no quirks (D-0076)" {
  quirkparams_stub 'exit 0'
  configure_stub_reporting_params
  run_confirmed
  assert_success
  run calls
  assert_line "configure-base-system params=unset"
}

@test "a failing quirk lookup stops the install before the disk is touched (D-0076)" {
  quirkparams_stub 'echo "quirkparams: broken map" >&2; exit 1'
  run_confirmed
  assert_failure
  run calls
  refute_output --partial "sgdisk"
  refute_output --partial "pacstrap"
}
