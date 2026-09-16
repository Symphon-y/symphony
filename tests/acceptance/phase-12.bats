#!/usr/bin/env bats
# Phase 12 acceptance tests: the Alienware 14/P39G migration.
#
# Split by what's checkable where: "static" runs from the VM and proves the
# new SWAP_SIZE path is genuinely optional (the VM itself stays zram-only,
# unaffected). "hardware" only makes sense on the real Alienware and is
# skipped everywhere else.

setup() {
  load '../helpers/common'
}

# --- static: checkable from the VM -----------------------------------------

@test "install-base-system: SWAP_SIZE is documented as optional in the vars example" {
  run grep -q '^SWAP_SIZE' "$REPO_ROOT/docs/runbooks/base-install.vars.example"
  assert_success
}

@test "install-base-system: layout.conf declares a swap partition label" {
  run grep -q '^SWAP_PARTLABEL=' "$REPO_ROOT/system/storage/layout.conf"
  assert_success
}

@test "this machine (VM) has no hibernation swap configured -- SWAP_SIZE stays opt-in" {
  # zram itself reports TYPE "partition" too (it's kernel swap accounting,
  # not a real block device), so check by name instead: every active swap
  # here should be zram, none a mapped LUKS device.
  run swapon --noheadings --show=NAME
  assert_success
  run grep -v '^/dev/zram' <<<"$output"
  assert_failure
  assert_output ""
}

@test "packages/alienware-14.txt does not exist yet -- ground truth comes first" {
  # Written only after real hardware ground truth (lscpu/lspci/free/lsblk),
  # not assumed in advance -- this test documents that ordering and will be
  # replaced once the file exists.
  assert [ ! -f "$REPO_ROOT/packages/alienware-14.txt" ]
}

# --- hardware: only meaningful on the real Alienware ------------------------

@test "hardware: WiFi is connected" {
  skip "manual: run on the Alienware once installed"
}

@test "hardware: power-profiles-daemon is active" {
  skip "manual: run on the Alienware once installed"
}

@test "hardware: hibernate and resume works" {
  skip "manual: run on the Alienware once installed -- systemctl hibernate, confirm resume"
}

@test "hardware: TPM presence is recorded as a checked fact" {
  skip "manual: dmidecode -t tpm / ls /sys/class/tpm on the Alienware"
}
