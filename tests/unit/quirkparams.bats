#!/usr/bin/env bats
# Unit tests for scripts/quirkparams: which kernel parameters this machine's firmware
# quirks need (D-0076). The DMI modalias and the quirks map are fixtures here; the last
# tests run it against the repo's real map.

bats_require_minimum_version 1.5.0

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/scripts/quirkparams"
  SYS="$BATS_TEST_TMPDIR/sys"
  MAP="$BATS_TEST_TMPDIR/quirks.txt"
  mkdir -p "$SYS/class/dmi/id"
  export SYMPHONY_SYS="$SYS" SYMPHONY_HARDWARE_MAP="$MAP"
}

# The machine's DMI modalias, as /sys/class/dmi/id/modalias shows it.
dmi() {
  printf '%s\n' "$1" >"$SYS/class/dmi/id/modalias"
}

ALIENWARE_14='dmi:bvnAlienware:bvr A09:bd01/01/2014:svnAlienware:pnAlienware 14:pvrA09:rvnAlienware:rnAlienware 14:rvrA09:cvnAlienware:ct10:cvrA09:sku0'
ALIENWARE_17='dmi:bvnAlienware:bvr A11:bd01/01/2015:svnAlienware:pnAlienware 17:pvrA11:rvnAlienware:rnAlienware 17:rvrA11:cvnAlienware:ct10:cvrA11:sku0'

@test "prints the parameter of a quirk whose DMI pattern matches this machine" {
  printf 'dmi:*:svnAlienware:pnAlienware*14:*  cmdline=module_blacklist=dell_rbtn  # bogus slider\n' >"$MAP"
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_success
  assert_output "module_blacklist=dell_rbtn"
}

@test "prints nothing for another model of the same vendor" {
  printf 'dmi:*:svnAlienware:pnAlienware*14:*  cmdline=module_blacklist=dell_rbtn\n' >"$MAP"
  dmi "$ALIENWARE_17"
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "a vendor-only pattern matches every model of that vendor" {
  printf 'dmi:*:svnAlienware:*  cmdline=quiet\n' >"$MAP"
  dmi "$ALIENWARE_17"
  run "$SCRIPT"
  assert_success
  assert_output "quiet"
}

@test "prints every matching parameter, sorted, each once" {
  {
    printf 'dmi:*:svnAlienware:*  cmdline=zzz_last\n'
    printf 'dmi:*:svnAlienware:pnAlienware*14:*  cmdline=aaa_first=1\n'
    printf 'dmi:*:cvnAlienware:*  cmdline=zzz_last\n'
    printf 'dmi:*:svnSomeoneElse:*  cmdline=never\n'
  } >"$MAP"
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_success
  assert_output "$(printf 'aaa_first=1\nzzz_last')"
}

@test "comments and blank lines are ignored" {
  printf '# a header\n\n   \ndmi:*:svnAlienware:*  cmdline=quiet   # trailing note\n' >"$MAP"
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_success
  assert_output "quiet"
}

@test "a machine with no DMI data gets no parameters" {
  printf 'dmi:*:svnAlienware:*  cmdline=quiet\n' >"$MAP"
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "no quirks file means no parameters" {
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_success
  assert_output ""
}

@test "fails closed on a line with no parameter, naming the line" {
  printf 'dmi:*:svnAlienware:*\n' >"$MAP"
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_failure 1
  assert_output --partial "$MAP:1"
}

@test "fails closed on a line with an extra field" {
  printf 'dmi:*:svnAlienware:*  cmdline=quiet  loglevel=3\n' >"$MAP"
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_failure 1
}

@test "fails closed on a parameter that is not a plain kernel parameter (it ends up on the boot command line)" {
  printf 'dmi:*:svnAlienware:*  cmdline=quiet;reboot\n' >"$MAP"
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_failure 1
}

@test "a broken line stops it even on a machine that would not match, and prints nothing" {
  printf 'dmi:*:svnAlienware:*  cmdline=quiet\nbroken\n' >"$MAP"
  dmi "$ALIENWARE_17"
  run --separate-stderr "$SCRIPT"
  assert_failure 1
  assert_output ""
}

@test "the repo's real quirks file parses cleanly" {
  unset SYMPHONY_HARDWARE_MAP
  dmi "dmi:svnNobody:pnNothing:"
  run "$SCRIPT"
  assert_success
  assert_output ""
}

# The real map, against the DMI strings read off the Alienware 14 itself
# (sys_vendor "Alienware", product_name "Alienware 14").
@test "the real quirks file blacklists dell_rbtn on the Alienware 14" {
  unset SYMPHONY_HARDWARE_MAP
  dmi "$ALIENWARE_14"
  run "$SCRIPT"
  assert_success
  assert_output "module_blacklist=dell_rbtn"
}

@test "the real quirks file leaves other Alienware models alone" {
  unset SYMPHONY_HARDWARE_MAP
  dmi "$ALIENWARE_17"
  run "$SCRIPT"
  assert_success
  assert_output ""
}
