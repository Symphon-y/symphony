#!/usr/bin/env bats
# Unit tests for scripts/hwpkglist: which extra packages this machine's hardware needs.
# The PCI bus, the hardware map and the package lists are all fixtures here; the last
# tests run it against the repo's real map and lists.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/hwpkglist"
  SYS="$BATS_TEST_TMPDIR/sys"
  MAP="$BATS_TEST_TMPDIR/hardware.txt"
  LISTS="$BATS_TEST_TMPDIR/lists"
  mkdir -p "$SYS/bus/pci/devices" "$LISTS"
  export AUTARCHY_SYS="$SYS" AUTARCHY_HARDWARE_MAP="$MAP" AUTARCHY_HARDWARE_PACKAGES="$LISTS"
}

# A PCI device as sysfs shows it: vendor and device are 0x-prefixed hex.
pci() {
  local dir="$SYS/bus/pci/devices/$1"
  mkdir -p "$dir"
  echo "0x$2" >"$dir/vendor"
  echo "0x$3" >"$dir/device"
}

# A hardware package list, in the format scripts/pkglist parses.
list() {
  local name=$1
  shift
  printf '%s\n' "$@" >"$LISTS/$name.txt"
}

@test "prints the packages of the list mapped to a device that is present" {
  printf '14e4:43b1  broadcom-wl  # Broadcom BCM4352\n' >"$MAP"
  list broadcom-wl "broadcom-wl-dkms  # the driver" "linux-headers  # DKMS builds against these"
  pci 0000:03:00.0 14e4 43b1
  run "$SCRIPT"
  assert_success
  assert_output "$(printf 'broadcom-wl-dkms\nlinux-headers')"
}

@test "prints nothing when the device is not on the bus" {
  printf '14e4:43b1  broadcom-wl\n' >"$MAP"
  list broadcom-wl broadcom-wl-dkms
  pci 0000:00:02.0 8086 0416
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "only the lists of devices that are present" {
  printf '14e4:43b1  broadcom-wl\n10de:1234  nvidia-thing\n' >"$MAP"
  list broadcom-wl broadcom-wl-dkms
  list nvidia-thing nvidia
  pci 0000:03:00.0 14e4 43b1
  run "$SCRIPT"
  assert_output "broadcom-wl-dkms"
}

@test "a package two present devices both need is printed once, sorted" {
  printf '14e4:43b1  a\n14e4:43a0  b\n' >"$MAP"
  list a zzz shared
  list b shared aaa
  pci 0000:03:00.0 14e4 43b1
  pci 0000:04:00.0 14e4 43a0
  run "$SCRIPT"
  assert_output "$(printf 'aaa\nshared\nzzz')"
}

@test "comments and blank lines in the map are ignored" {
  printf '# a comment\n\n14e4:43b1  broadcom-wl   # trailing note\n   \n' >"$MAP"
  list broadcom-wl broadcom-wl-dkms
  pci 0000:03:00.0 14e4 43b1
  run "$SCRIPT"
  assert_output "broadcom-wl-dkms"
}

@test "a machine with no PCI bus at all is fine and prints nothing" {
  rmdir "$SYS/bus/pci/devices"
  printf '14e4:43b1  broadcom-wl\n' >"$MAP"
  list broadcom-wl broadcom-wl-dkms
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "a missing hardware map is fine: nothing to add" {
  rm -f "$MAP"
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "a map entry naming a list that does not exist fails, and prints no packages (never a partial install)" {
  printf '14e4:43b1  no-such-list\n' >"$MAP"
  pci 0000:03:00.0 14e4 43b1
  run "$SCRIPT"
  assert_failure
  assert_output --partial "no-such-list"
}

@test "a malformed map line fails and names the line" {
  printf 'not-an-id  broadcom-wl\n' >"$MAP"
  run "$SCRIPT"
  assert_failure
  assert_output --partial "hardware.txt:1"
}

@test "an entry with no list name fails" {
  printf '14e4:43b1\n' >"$MAP"
  run "$SCRIPT"
  assert_failure
  assert_output --partial "hardware.txt:1"
}

@test "with the repo's real map and lists, the Broadcom BCM4352 gets its driver and headers for both kernels" {
  unset AUTARCHY_HARDWARE_MAP AUTARCHY_HARDWARE_PACKAGES
  pci 0000:03:00.0 14e4 43b1
  run "$SCRIPT"
  assert_success
  assert_line "broadcom-wl-dkms"
  assert_line "linux-headers"
  assert_line "linux-lts-headers"
}

@test "with the repo's real map, a machine without that adapter adds nothing" {
  unset AUTARCHY_HARDWARE_MAP AUTARCHY_HARDWARE_PACKAGES
  pci 0000:00:02.0 8086 0416
  run "$SCRIPT"
  assert_success
  assert_output ""
}
