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
  stub "$bin/cryptsetup" 'echo "cryptsetup $*" >>"$STUB_LOG"'
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

  cat >"$bin/autarchy-configure-stub" <<'EOF'
#!/usr/bin/env bash
echo "configure-base-system $*" >>"$STUB_LOG"
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

@test "partitions the disk with the ESP and cryptroot labels from layout.conf" {
  run_confirmed
  assert_success
  run calls
  assert_line --regexp 'sgdisk --zap-all /dev/vda'
  assert_line --regexp 'sgdisk -n 1:0:\+2G -t 1:ef00 -c 1:ESP -n 2:0:0 -t 2:8309 -c 2:cryptroot /dev/vda'
}

@test "encrypts the LUKS partition and creates every declared subvolume" {
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

# --- seed_release_marker (Phase 12) ----------------------------------------

@test "release marker: no-ops when not booted from a release ISO (default)" {
  run_confirmed
  assert_success
  assert [ ! -e "$TARGET/home/alice/.local/state/autarchy/current-release" ]
}

@test "release marker: no-ops when the live ISO marker says 'unreleased'" {
  echo "unreleased" >"$AUTARCHY_LIVE_RELEASE_FILE"
  run_confirmed
  assert_success
  assert [ ! -e "$TARGET/home/alice/.local/state/autarchy/current-release" ]
}

@test "release marker: seeds the new user's state dir with the ISO's release tag" {
  echo "2026.09.16" >"$AUTARCHY_LIVE_RELEASE_FILE"
  run_confirmed
  assert_success
  assert_equal "$(cat "$TARGET/home/alice/.local/state/autarchy/current-release")" "2026.09.16"
  run calls
  assert_line "arch-chroot $TARGET chown -R alice:alice /home/alice/.local"
}
