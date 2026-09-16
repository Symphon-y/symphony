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
  stub "$bin/pacstrap" 'echo "pacstrap $*" >>"$STUB_LOG"; mkdir -p "$2/etc"'
  stub "$bin/genfstab" 'echo "UUID=x / btrfs subvolid=256,subvol=/@ 0 0"'

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
  assert_line --partial "pacstrap -K $TARGET"

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
