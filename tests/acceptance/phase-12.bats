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

@test "hibernation swap follows SWAP_SIZE: present on the Alienware, absent elsewhere (opt-in)" {
  # zram itself reports TYPE "partition" too (it's kernel swap accounting,
  # not a real block device), so check by name: on a machine installed with
  # SWAP_SIZE (the Alienware) one active swap is a mapped LUKS device; on the
  # VM every active swap is zram.
  run swapon --noheadings --show=NAME
  assert_success
  run grep -v '^/dev/zram' <<<"$output"
  if [[ $(cat /sys/class/dmi/id/product_name 2>/dev/null) == "Alienware 14" ]]; then
    assert_success
    assert_output --regexp '^/dev/(mapper/cryptswap|dm-[0-9]+)$'
  else
    assert_failure
    assert_output ""
  fi
}

@test "iso: the live environment can actually find its own root (archiso HOOKS, gpt-auto-generator masked)" {
  # A real boot failure on the first hardware attempt: without these, the
  # live medium's initramfs falls back to systemd's generic root-finding,
  # which times out waiting for a nonexistent /dev/gpt-auto-root.
  local base="$REPO_ROOT/iso/profile/airootfs"
  run grep -q '^archiso_config=' "$base/etc/mkinitcpio.d/linux.preset"
  assert_success
  run grep -q 'HOOKS=.*archiso' "$base/etc/mkinitcpio.conf.d/archiso.conf"
  assert_success
  run readlink "$base/etc/systemd/system-generators/systemd-gpt-auto-generator"
  assert_output "/dev/null"
}

@test "iso: root is unlocked and auto-logs-in on the live medium" {
  # Also a real boot failure: without these, root is locked by the shadow
  # package's own default state, and the live environment is unusable even
  # if it does boot.
  local base="$REPO_ROOT/iso/profile/airootfs"
  run grep -q '^root::' "$base/etc/shadow"
  assert_success
  run grep -q 'autologin root' "$base/etc/systemd/system/getty@tty1.service.d/autologin.conf"
  assert_success
}

@test "iso: NetworkManager and systemd-resolved are enabled on the live medium" {
  # Was dhcpcd + iwd until Phase 17: the live ISO now runs the same network stack
  # as the installed system (D-0014), so a Wi-Fi connection made in the live
  # session can be carried to the new system as-is. See phase-17.bats.
  local wants="$REPO_ROOT/iso/profile/airootfs/etc/systemd/system/multi-user.target.wants"
  local svc
  for svc in NetworkManager.service systemd-resolved.service; do
    assert is_symlink "$wants/$svc"
  done
}

@test "release workflow: pins the release to the tagged commit, not the default branch" {
  # A real publish failure found testing this phase: without an explicit
  # target commit, the release publish step defaulted to main, producing
  # a silently-drafted, "untagged-<hash>"-URLed release for a tag pushed
  # against any other commit. Still true after Phase 14 switched the
  # publish step from action-gh-release to the gh CLI directly.
  # shellcheck disable=SC2016 # a literal grep pattern, not meant to expand
  run grep -q -- '--target "\$GITHUB_SHA"' "$REPO_ROOT/.github/workflows/release-iso.yml"
  assert_success
}

@test "iso: autarchy-install exists and composes the existing, already-tested scripts in order" {
  local script="$REPO_ROOT/iso/profile/airootfs/usr/local/bin/autarchy-install"
  assert [ -x "$script" ]

  # No new install logic here -- only orchestration of what already exists
  # and is already tested elsewhere (install-base-system, via the shared
  # run-guided-install runner -- Phase 15/D-0066). The repo itself is
  # baked into the live environment at build time (Phase 14), so there is
  # no bootstrap/clone step to orchestrate here any more.
  run grep -q 'scripts/system-report' "$script"
  assert_success
  run grep -q 'install/run-guided-install' "$script"
  assert_success

  # The review screen (a plain proceed? gate) must come before
  # run-guided-install runs -- install-base-system's own typed-disk-path
  # gate is a second, separate checkpoint, not a replacement.
  local review_line install_line
  review_line=$(grep -n 'Proceed with these values' "$script" | head -1 | cut -d: -f1)
  install_line=$(grep -n '^  install/run-guided-install' "$script" | head -1 | cut -d: -f1)
  assert [ -n "$review_line" ]
  assert [ -n "$install_line" ]
  assert [ "$review_line" -lt "$install_line" ]
}

@test "iso: autarchy-install lists disk options and never accepts a blank/invalid disk" {
  # A real bug found booting the ISO on real hardware (Phase 14): the disk
  # prompt gave no way to know the available options, and leaving it blank
  # surfaced only much later as an unrelated, unhelpful error instead of
  # being rejected at the point of input.
  local script="$REPO_ROOT/iso/profile/airootfs/usr/local/bin/autarchy-install"
  run grep -q '^ask_disk()' "$script"
  assert_success
  run grep -q '^list_disks()' "$script"
  assert_success
  # main() must use the validating prompt, not the old blank-accepting one.
  # shellcheck disable=SC2016 # a literal grep pattern, not meant to expand
  run grep -q 'disk=\$(ask_disk)' "$script"
  assert_success
}

@test "iso: the live medium prints autarchy-install as the one obvious thing to run" {
  run grep -q 'autarchy-install' "$REPO_ROOT/iso/profile/airootfs/root/.bash_profile"
  assert_success
}

@test "docs: base-install.md documents the guided autarchy-install flow" {
  run grep -q 'autarchy-install' "$REPO_ROOT/docs/runbooks/base-install.md"
  assert_success
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
