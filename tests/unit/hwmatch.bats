#!/usr/bin/env bats
# Unit tests for scripts/hwmatch: the one parser of system/hardware.txt (D-0082). A line
# is `<key> <value>...` where the key names hardware -- pci:VVVV:DDDD, usb:VVVV:PPPP,
# dmi:<modalias glob>, hda:<codec vendor id>:<subsystem id> -- and each value says what
# that hardware needs: packages=<list>, cmdline=<param>, modprobe=<file>, files=<manifest>,
# service=<unit>. hwmatch prints, for every entry present on this machine, one
# `<kind>\t<value>` line per value, sorted and de-duplicated. sysfs and procfs are
# fixtures; the last tests run against the repo's real map.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/hwmatch"
  SYS="$BATS_TEST_TMPDIR/sys"
  PROC="$BATS_TEST_TMPDIR/proc"
  MAP="$BATS_TEST_TMPDIR/hardware.txt"
  LISTS="$BATS_TEST_TMPDIR/lists"
  SYSTEM="$BATS_TEST_TMPDIR/system"
  mkdir -p "$SYS/bus/pci/devices" "$SYS/bus/usb/devices" "$SYS/class/dmi/id" "$PROC/asound" \
    "$LISTS" "$SYSTEM/modprobe" "$SYSTEM/hardware"
  export SYMPHONY_SYS="$SYS" SYMPHONY_PROC="$PROC" SYMPHONY_HARDWARE_MAP="$MAP" \
    SYMPHONY_HARDWARE_PACKAGES="$LISTS" SYMPHONY_SYSTEM_DIR="$SYSTEM"
  : >"$MAP"
}

pci() {
  local dir="$SYS/bus/pci/devices/$1"
  mkdir -p "$dir"
  echo "0x$2" >"$dir/vendor"
  echo "0x$3" >"$dir/device"
}

usb() {
  local dir="$SYS/bus/usb/devices/$1"
  mkdir -p "$dir"
  echo "$2" >"$dir/idVendor"
  echo "$3" >"$dir/idProduct"
}

dmi() {
  printf '%s\n' "$1" >"$SYS/class/dmi/id/modalias"
}

# A codec as /proc/asound/cardN/codec#0 prints its identity.
hda() {
  mkdir -p "$PROC/asound/card$1"
  printf 'Codec: Fake\nAddress: 0\nVendor Id: 0x%s\nSubsystem Id: 0x%s\n' "$2" "$3" >"$PROC/asound/card$1/codec#0"
}

list() {
  local name=$1
  shift
  printf '%s\n' "$@" >"$LISTS/$name.txt"
}

entry() {
  printf '%s\n' "$*" >>"$MAP"
}

# --- keys -------------------------------------------------------------------------

@test "pci: an entry matches when the vendor:device is on the bus" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl broadcom-wl-dkms
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  run "$SCRIPT"
  assert_success
  assert_output $'packages\tbroadcom-wl'
}

@test "usb: an entry matches on idVendor:idProduct" {
  usb 2-1.7 187c 0525
  list alienfx alienfx
  entry 'usb:187c:0525  packages=alienfx  service=alienfx-theme.service'
  run "$SCRIPT"
  assert_success
  assert_line $'packages\talienfx'
  assert_line $'service\talienfx-theme.service'
}

@test "dmi: an entry matches the modalias by shell glob" {
  dmi 'dmi:bvnAlienware:bvrA09:bd04/23/2014:svnAlienware:pnAlienware 14:pvrA09:rvnAlienware:rn07MJ2Y:'
  entry 'dmi:*:svnAlienware:pnAlienware*14:*  cmdline=module_blacklist=dell_rbtn'
  run "$SCRIPT"
  assert_success
  assert_output $'cmdline\tmodule_blacklist=dell_rbtn'
}

@test "hda: an entry matches a codec by vendor id and subsystem id, on any card" {
  hda 1 10ec0668 102805a9
  printf 'options snd-hda-intel model=x\n' >"$SYSTEM/modprobe/alc3661.conf"
  entry 'hda:10ec0668:102805a9  modprobe=alc3661.conf'
  run "$SCRIPT"
  assert_success
  assert_output $'modprobe\talc3661.conf'
}

@test "nothing present: prints nothing, exits 0" {
  list broadcom-wl x
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  entry 'usb:187c:0525  packages=broadcom-wl'
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "a machine with no sysfs buses or dmi at all is fine" {
  rm -rf "$SYS" "$PROC"
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  list broadcom-wl x
  run "$SCRIPT"
  assert_success
  assert_output ""
}

# --- values -----------------------------------------------------------------------

@test "every value kind is printed, one line each, in a fixed order" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl x
  printf 'x\n' >"$SYSTEM/modprobe/m.conf"
  printf '0644 hardware/r.rules /etc/udev/rules.d/r.rules\n' >"$SYSTEM/hardware/r.txt"
  entry 'pci:14e4:43b1  packages=broadcom-wl cmdline=foo=1 modprobe=m.conf files=r.txt service=svc.service'
  run "$SCRIPT"
  assert_success
  assert_line --index 0 $'cmdline\tfoo=1'
  assert_line --index 1 $'files\tr.txt'
  assert_line --index 2 $'modprobe\tm.conf'
  assert_line --index 3 $'packages\tbroadcom-wl'
  assert_line --index 4 $'service\tsvc.service'
}

@test "two present entries wanting the same thing print it once" {
  pci 0000:0a:00.0 14e4 43b1
  usb 2-1 187c 0525
  list common x
  entry 'pci:14e4:43b1  packages=common'
  entry 'usb:187c:0525  packages=common'
  run "$SCRIPT"
  assert_success
  assert_output $'packages\tcommon'
}

@test "--kind KIND prints only that kind's values, bare; packages are expanded to package names" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl broadcom-wl-dkms linux-headers
  entry 'pci:14e4:43b1  packages=broadcom-wl cmdline=foo=1'
  run "$SCRIPT" --kind cmdline
  assert_success
  assert_output "foo=1"
  run "$SCRIPT" --kind packages
  assert_line "broadcom-wl-dkms"
  assert_line "linux-headers"
  refute_line "broadcom-wl"
}

@test "--all lists every entry with whether it is present (for check/report)" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl x
  entry 'pci:14e4:43b1  packages=broadcom-wl   # Broadcom'
  entry 'usb:187c:0525  packages=broadcom-wl   # AlienFX'
  run "$SCRIPT" --all
  assert_success
  assert_line $'present\tpci:14e4:43b1\tpackages=broadcom-wl'
  assert_line $'absent\tusb:187c:0525\tpackages=broadcom-wl'
}

# --- fails closed -----------------------------------------------------------------

@test "a package list that does not exist fails, even for hardware that is not present" {
  entry 'pci:14e4:43b1  packages=nope'
  run "$SCRIPT"
  assert_failure
  assert_output --partial "nope"
}

@test "a modprobe file or files manifest that does not exist fails" {
  entry 'pci:14e4:43b1  modprobe=nope.conf'
  run "$SCRIPT"
  assert_failure
  assert_output --partial "nope.conf"
  : >"$MAP"
  entry 'pci:14e4:43b1  files=nope.txt'
  run "$SCRIPT"
  assert_failure
  assert_output --partial "nope.txt"
}

@test "an unknown key kind, an unknown value kind, or a bare word fails and names the line" {
  entry 'scsi:1:2  packages=x'
  run "$SCRIPT"
  assert_failure
  assert_output --partial ":1:"
  : >"$MAP"
  entry 'pci:14e4:43b1  colour=red'
  run "$SCRIPT"
  assert_failure
  assert_output --partial ":1:"
  : >"$MAP"
  entry 'pci:14e4:43b1  broadcom-wl'
  run "$SCRIPT"
  assert_failure
}

@test "a cmdline value with whitespace or shell metacharacters fails (it goes on the boot line)" {
  # shellcheck disable=SC2016 # the literal is the point: it must be rejected
  entry 'pci:14e4:43b1  cmdline=foo=$(x)'
  run "$SCRIPT"
  assert_failure
}

@test "an entry with a key but no values fails" {
  entry 'pci:14e4:43b1'
  run "$SCRIPT"
  assert_failure
}

@test "comments and blank lines are ignored; a missing map is nothing to do" {
  printf '# only a comment\n\n' >"$MAP"
  run "$SCRIPT"
  assert_success
  assert_output ""
  rm "$MAP"
  run "$SCRIPT"
  assert_success
  assert_output ""
}

# --- the repo's real map ----------------------------------------------------------

@test "real map: every line parses (nothing present here, so nothing printed)" {
  unset SYMPHONY_HARDWARE_MAP SYMPHONY_HARDWARE_PACKAGES SYMPHONY_SYSTEM_DIR
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "real map: the Alienware 14 gets the Broadcom driver, the dell_rbtn blacklist and AlienFX" {
  unset SYMPHONY_HARDWARE_MAP SYMPHONY_HARDWARE_PACKAGES SYMPHONY_SYSTEM_DIR
  pci 0000:0a:00.0 14e4 43b1
  usb 2-1.7 187c 0525
  dmi 'dmi:bvnAlienware:bvrA09:bd04/23/2014:svnAlienware:pnAlienware 14:pvrA09:rvnAlienware:rn07MJ2Y:'
  run "$SCRIPT" --kind packages
  assert_success
  assert_line "broadcom-wl-dkms"
  assert_line "alienfx"
  run "$SCRIPT" --kind cmdline
  assert_output "module_blacklist=dell_rbtn"
  run "$SCRIPT" --kind service
  assert_line "alienfx-theme.service"
}
