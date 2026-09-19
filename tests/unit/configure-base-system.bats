#!/usr/bin/env bats
# Unit tests for install/configure-base-system.
#
# The script runs against a fake target root in a temp directory. Commands that
# would touch the real machine (arch-chroot, systemctl, blkid, mountpoint, id) are
# replaced by stubs on PATH that record how they were called.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/install/configure-base-system"
  TARGET="$BATS_TEST_TMPDIR/target"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  make_target
  make_vars
  make_stubs
}

# A target root as pacstrap and genfstab leave it: fstab, zoneinfo, a stock
# locale.gen, and the stock initramfs images mkinitcpio built during pacstrap.
make_target() {
  mkdir -p "$TARGET/etc" "$TARGET/boot" "$TARGET/efi" "$TARGET/usr/share/zoneinfo/America"
  echo "UUID=x / btrfs subvol=/@ 0 0" >"$TARGET/etc/fstab"
  touch "$TARGET/usr/share/zoneinfo/America/Chicago"
  printf '%s\n' \
    '#     en_US.UTF-8 UTF-8' \
    '#de_DE.UTF-8 UTF-8' \
    '#en_US.UTF-8 UTF-8' \
    '#en_US ISO-8859-1' >"$TARGET/etc/locale.gen"
  touch "$TARGET/boot/vmlinuz-linux" \
    "$TARGET/boot/initramfs-linux.img" \
    "$TARGET/boot/initramfs-linux-fallback.img"
}

make_vars() {
  VARS="$BATS_TEST_TMPDIR/test.local.vars"
  cat >"$VARS" <<'EOF'
DISK=/dev/vda           # not used by this script
HOST=testhost
USERNAME=alice
TZONE=America/Chicago
LOCALE=en_US.UTF-8
KEYMAP=us
EOF
}

# Stub bodies are single-quoted on purpose: they must expand when the stub runs, not here.
# shellcheck disable=SC2016
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"

  stub "$bin/systemctl" 'echo "systemctl $*" >>"$STUB_LOG"'
  stub "$bin/mountpoint" 'echo "mountpoint $*" >>"$STUB_LOG"; exit "${STUB_MOUNTPOINT_RC:-0}"'
  # Device-specific, not a single hardcoded value: a stub that can't tell
  # devices apart can't catch a bug about resolving the wrong device's
  # UUID (D-0065 -- the swap UUID must differ from root's for the
  # rd.luks.name= invariant test below to mean anything).
  stub "$bin/blkid" 'echo "blkid $*" >>"$STUB_LOG"; case "$*" in
    *by-partlabel/cryptroot) echo "1111-2222" ;;
    *by-partlabel/cryptswap) echo "5555-6666" ;;
  esac'
  stub "$bin/visudo" 'echo "visudo $*" >>"$STUB_LOG"'
  stub "$bin/id" 'if [[ ${1:-} == -u ]]; then echo 0; else exec /usr/bin/id "$@"; fi'

  # arch-chroot TARGET CMD...: answers the "is it already done?" queries from
  # STUB_USER_EXISTS and STUB_BOOTCTL_INSTALLED; logs chpasswd's stdin too
  # (the one case a test needs to see what actually flowed through -- the
  # password read from fd 8); everything else succeeds.
  cat >"$bin/arch-chroot" <<'EOF'
#!/usr/bin/env bash
echo "arch-chroot $*" >>"$STUB_LOG"
shift
case "$1 ${2:-}" in
  "id -u") [[ ${STUB_USER_EXISTS:-0} == 1 ]] ;;
  "passwd -S")
    if [[ ${STUB_USER_EXISTS:-0} == 1 ]]; then echo "$3 P 2026-09-13 0 99999 7 -1"; else echo "$3 L"; fi
    ;;
  "bootctl is-installed") [[ ${STUB_BOOTCTL_INSTALLED:-0} == 1 ]] ;;
  "chpasswd "*) echo "arch-chroot stdin: $(cat)" >>"$STUB_LOG" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$bin/arch-chroot"

  PATH="$bin:$PATH"
}

stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1"
  chmod +x "$1"
}

calls() {
  cat "$STUB_LOG"
}

@test "fails and names the variable when a required value is missing" {
  echo "HOST=" >>"$VARS"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_failure
  assert_output --partial "HOST"
  run calls
  refute_output --partial "arch-chroot"
}

@test "refuses to run when the target root is not mounted" {
  export STUB_MOUNTPOINT_RC=1
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_failure
  assert_output --partial "not mounted"
  run calls
  refute_output --partial "arch-chroot"
}

@test "fails before changing anything when the timezone does not exist" {
  echo "TZONE=Nowhere/City" >>"$VARS"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_failure
  assert_output --partial "Nowhere/City"
  assert [ ! -e "$TARGET/etc/hostname" ]
}

@test "fails before changing anything when the locale is not in locale.gen" {
  echo "LOCALE=xx_XX.UTF-8" >>"$VARS"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_failure
  assert_output --partial "xx_XX.UTF-8"
  assert [ ! -e "$TARGET/etc/hostname" ]
}

@test "installs each system config file at its target path" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  local pair
  for pair in \
    "system/mkinitcpio/10-autarchy.conf:etc/mkinitcpio.conf.d/10-autarchy.conf" \
    "system/mkinitcpio/linux.preset:etc/mkinitcpio.d/linux.preset" \
    "system/mkinitcpio/linux-lts.preset:etc/mkinitcpio.d/linux-lts.preset" \
    "system/zram/zram-generator.conf:etc/systemd/zram-generator.conf" \
    "system/resolved/10-autarchy.conf:etc/systemd/resolved.conf.d/10-autarchy.conf" \
    "system/nftables/nftables.conf:etc/nftables.conf" \
    "system/sudo/10-wheel:etc/sudoers.d/10-wheel" \
    "system/boot/loader.conf:efi/loader/loader.conf"; do
    run cmp "$REPO_ROOT/${pair%%:*}" "$TARGET/${pair#*:}"
    assert_success
  done

  run find "$TARGET/etc/sudoers.d/10-wheel" -perm 0440
  assert_output "$TARGET/etc/sudoers.d/10-wheel"
  run calls
  # System files come from install/sync-system, which validates sudoers before installing.
  assert_line "visudo -cf $REPO_ROOT/system/sudo/10-wheel"
}

@test "writes hostname, locale, keymap, and timezone from the vars file" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  assert_equal "$(cat "$TARGET/etc/hostname")" "testhost"
  assert_equal "$(cat "$TARGET/etc/locale.conf")" "LANG=en_US.UTF-8"
  assert_equal "$(cat "$TARGET/etc/vconsole.conf")" "KEYMAP=us"
  assert_equal "$(readlink "$TARGET/etc/localtime")" "/usr/share/zoneinfo/America/Chicago"

  # Only the chosen locale is uncommented; examples and other locales are untouched.
  run cat "$TARGET/etc/locale.gen"
  assert_line "en_US.UTF-8 UTF-8"
  assert_line "#de_DE.UTF-8 UTF-8"
  assert_line "#en_US ISO-8859-1"
  assert_line "#     en_US.UTF-8 UTF-8"

  run calls
  assert_line "arch-chroot $TARGET hwclock --systohc"
  assert_line "arch-chroot $TARGET locale-gen"
}

@test "writes a kernel command line that unlocks the LUKS partition by UUID" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/etc/kernel/cmdline")" \
    "rd.luks.name=1111-2222=root root=/dev/mapper/root rootflags=subvol=@ rw"
  run calls
  assert_line "blkid -s UUID -o value /dev/disk/by-partlabel/cryptroot"
}

@test "adds resume= to the cmdline when AUTARCHY_RESUME_DEVICE is set (Phase 12 hibernation)" {
  AUTARCHY_RESUME_DEVICE=/dev/mapper/cryptswap run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/etc/kernel/cmdline")" \
    "rd.luks.name=1111-2222=root root=/dev/mapper/root rootflags=subvol=@ rw rd.luks.name=5555-6666=cryptswap resume=/dev/mapper/cryptswap resumeflags=x-systemd.device-timeout=30s"
  run calls
  assert_line "blkid -s UUID -o value /dev/disk/by-partlabel/cryptswap"
}

@test "resume= is never added without a matching rd.luks.name= for the same device (D-0065)" {
  # The exact invariant a real hardware boot deadlock violated:
  # systemd-hibernate-resume.service runs inside the initramfs and can
  # only find the resume device if sd-encrypt already unlocked it there
  # via its own rd.luks.name= -- a resume= device unlocked only later,
  # via crypttab on the not-yet-mounted real root, is a permanent hang,
  # not a slow one. Whenever resume=/dev/mapper/X appears, rd.luks.name=
  # ...=X must also appear in the same cmdline.
  AUTARCHY_RESUME_DEVICE=/dev/mapper/cryptswap run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  local cmdline mapper_name
  cmdline=$(cat "$TARGET/etc/kernel/cmdline")
  mapper_name=$(basename "$AUTARCHY_RESUME_DEVICE")
  [[ $cmdline == *"resume=/dev/mapper/$mapper_name"* ]]
  [[ $cmdline == *"rd.luks.name="*"=$mapper_name"* ]]
}

@test "replaces stock initramfs images with unified kernel images and installs the boot loader" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  assert [ ! -e "$TARGET/boot/initramfs-linux.img" ]
  assert [ ! -e "$TARGET/boot/initramfs-linux-fallback.img" ]
  assert [ -e "$TARGET/boot/vmlinuz-linux" ]
  assert [ -d "$TARGET/efi/EFI/Linux" ]

  run calls
  assert_line "arch-chroot $TARGET mkinitcpio -P"
  assert_line "arch-chroot $TARGET bootctl install"
}

@test "creates the wheel user, sets its password interactively when no password fd is given, and locks root" {
  # No fd 8 here: the documented manual/recovery runbook path calls this
  # script directly, with no collector at all, and must keep working
  # exactly like today -- passwd's own interactive prompt, no chpasswd.
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  assert_line "arch-chroot $TARGET useradd -m -G wheel alice"
  assert_line "arch-chroot $TARGET passwd alice"
  assert_line "arch-chroot $TARGET passwd -l root"
}

@test "creates the wheel user and sets its password unattended when a password fd is given (Phase 15/D-0066)" {
  run bash -c "\"$SCRIPT\" \"$VARS\" \"$TARGET\" 8<<<'userpass456'"
  assert_success
  run calls
  assert_line "arch-chroot $TARGET useradd -m -G wheel alice"
  refute_line "arch-chroot $TARGET passwd alice"
  assert_line "arch-chroot $TARGET chpasswd"
  assert_line "arch-chroot stdin: alice:userpass456"
  assert_line "arch-chroot $TARGET passwd -l root"
}

@test "re-running skips the user and boot loader steps that are already done" {
  export STUB_USER_EXISTS=1 STUB_BOOTCTL_INSTALLED=1
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  refute_line "arch-chroot $TARGET useradd -m -G wheel alice"
  refute_line "arch-chroot $TARGET passwd alice"
  refute_line "arch-chroot $TARGET bootctl install"
  assert_line "arch-chroot $TARGET passwd -l root"
}

@test "enables the base services, including sddm, in the target" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  assert_line "systemctl --root=$TARGET enable NetworkManager.service systemd-resolved.service systemd-timesyncd.service nftables.service systemd-boot-update.service fstrim.timer paccache.timer sddm.service"
}

@test "configures SDDM autologin for the new user (Phase 16)" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/etc/sddm.conf.d/20-autologin.conf")" \
    "$(printf '[Autologin]\nUser=alice\nSession=hyprland-uwsm')"
}

@test "copies the baked-in repo to the new user's home as a real checkout, and chowns it (Phase 16)" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  local dest="$TARGET/home/alice/Projects/autarchy"
  assert [ -d "$dest/.git" ]
  assert [ -e "$dest/install/configure-base-system" ]
  run calls
  assert_line "arch-chroot $TARGET chown -R alice:alice /home/alice/Projects/autarchy"
}

@test "runs link-home apply as the new user against the copied repo (Phase 16)" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  assert_line "arch-chroot $TARGET runuser -u alice -- bash -c cd /home/alice/Projects/autarchy && install/link-home apply"
}

@test "clears skel-provided dotfiles before link-home apply, so stow doesn't abort on them" {
  # useradd -m populates a fresh account from /etc/skel, which ships
  # .bash_logout/.bash_profile/.bashrc. home/bash/dot-bashrc stows over
  # exactly .bashrc, and GNU stow aborts its entire combined call (every
  # package, not just bash) on a single conflict like this -- reproduced
  # live against this repo's own stow packages, exit 1. Since
  # configure-base-system runs under set -Eeuo pipefail, that would have
  # killed the whole script before it ever reached enable_services()
  # (sddm.service), matching a real hardware install that booted fine
  # but never got a graphical session.
  mkdir -p "$TARGET/home/alice"
  touch "$TARGET/home/alice/.bash_logout" \
    "$TARGET/home/alice/.bash_profile" \
    "$TARGET/home/alice/.bashrc"

  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  assert [ ! -e "$TARGET/home/alice/.bash_logout" ]
  assert [ ! -e "$TARGET/home/alice/.bash_profile" ]
  assert [ ! -e "$TARGET/home/alice/.bashrc" ]
  run calls
  assert_line "arch-chroot $TARGET runuser -u alice -- bash -c cd /home/alice/Projects/autarchy && install/link-home apply"
}

@test "writes ~/.gitconfig.local when both GIT_NAME and GIT_EMAIL are provided (Phase 16)" {
  {
    echo 'GIT_NAME="Alice Example"'
    echo "GIT_EMAIL=alice@users.noreply.github.com"
  } >>"$VARS"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  local gitconfig="$TARGET/home/alice/.gitconfig.local"
  assert [ -e "$gitconfig" ]
  run cat "$gitconfig"
  assert_line "[user]"
  assert_line --partial "name = Alice Example"
  assert_line --partial "email = alice@users.noreply.github.com"
  run calls
  assert_line "arch-chroot $TARGET chown alice:alice /home/alice/.gitconfig.local"
}

@test "never writes ~/.gitconfig.local when git identity was skipped (Phase 16)" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert [ ! -e "$TARGET/home/alice/.gitconfig.local" ]
}

@test "points resolv.conf at the systemd-resolved stub after the last chroot call" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(readlink "$TARGET/etc/resolv.conf")" "../run/systemd/resolve/stub-resolv.conf"
}
