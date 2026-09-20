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
  touch "$TARGET/usr/share/zoneinfo/America/Chicago" "$TARGET/usr/share/zoneinfo/UTC"
  # tzdata's zone.tab (tab-separated: country, coordinates, zone, comment -- one
  # country per zone, and no entry for UTC) and wireless-regdb's conf file, which
  # ships every country commented out.
  printf 'US\t+415100-0873900\tAmerica/Chicago\tCentral (most areas)\nGB\t+513030-0000731\tEurope/London\n' \
    >"$TARGET/usr/share/zoneinfo/zone.tab"
  mkdir -p "$TARGET/etc/conf.d"
  printf '%s\n' '# Uncomment your country' '#WIRELESS_REGDOM="GB"' '#WIRELESS_REGDOM="US"' \
    >"$TARGET/etc/conf.d/wireless-regdom"
  printf '%s\n' \
    '#     en_US.UTF-8 UTF-8' \
    '#de_DE.UTF-8 UTF-8' \
    '#en_US.UTF-8 UTF-8' \
    '#en_US ISO-8859-1' >"$TARGET/etc/locale.gen"
  touch "$TARGET/boot/vmlinuz-linux" \
    "$TARGET/boot/initramfs-linux.img" \
    "$TARGET/boot/initramfs-linux-fallback.img"

  # What useradd -m would have left (the stub doesn't run it), and the mounted
  # @snapshots subvolume plus snapper's shipped config template that
  # configure_snapper builds on (pacstrap installs snapper -- packages/storage.txt).
  mkdir -p "$TARGET/home/alice" "$TARGET/.snapshots" \
    "$TARGET/usr/share/snapper/config-templates" "$TARGET/etc/conf.d"
  printf '%s\n' \
    '# a template comment' \
    'SUBVOLUME="/"' \
    'FSTYPE="btrfs"' \
    'NUMBER_LIMIT="50"' \
    'NUMBER_LIMIT_IMPORTANT="10"' \
    'TIMELINE_CREATE="yes"' >"$TARGET/usr/share/snapper/config-templates/default"
  printf '%s\n' '# List of snapper configurations.' 'SNAPPER_CONFIGS=""' >"$TARGET/etc/conf.d/snapper"
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
    "system/networkmanager/20-connectivity.conf:etc/NetworkManager/conf.d/20-connectivity.conf" \
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

@test "appends the firmware-quirk kernel parameters install-base-system resolved (D-0076)" {
  AUTARCHY_KERNEL_PARAMS="module_blacklist=dell_rbtn quiet" run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/etc/kernel/cmdline")" \
    "rd.luks.name=1111-2222=root root=/dev/mapper/root rootflags=subvol=@ rw module_blacklist=dell_rbtn quiet"
}

@test "quirk parameters come after resume= and are in place before the images are built (D-0076)" {
  AUTARCHY_RESUME_DEVICE=/dev/mapper/cryptswap AUTARCHY_KERNEL_PARAMS="module_blacklist=dell_rbtn" \
    run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/etc/kernel/cmdline")" \
    "rd.luks.name=1111-2222=root root=/dev/mapper/root rootflags=subvol=@ rw rd.luks.name=5555-6666=cryptswap resume=/dev/mapper/cryptswap resumeflags=x-systemd.device-timeout=30s module_blacklist=dell_rbtn"
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
  assert_line "systemctl --root=$TARGET enable NetworkManager.service systemd-resolved.service systemd-timesyncd.service nftables.service systemd-boot-update.service fstrim.timer paccache.timer snapper-cleanup.timer sddm.service"
}

@test "masks NetworkManager-wait-online after enabling NetworkManager, so boot isn't held for a network (Phase 17)" {
  # Enabling NetworkManager links its wait-online service into network-online.target
  # (checked against the real package): anything ordered after the network would
  # then wait up to ~60s at boot when there is none -- a laptop off Wi-Fi.
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  assert_line "systemctl --root=$TARGET mask NetworkManager-wait-online.service"
  local enable_line mask_line
  enable_line=$(grep -n 'systemctl --root=.* enable NetworkManager.service' "$STUB_LOG" | head -1 | cut -d: -f1)
  mask_line=$(grep -n 'mask NetworkManager-wait-online.service' "$STUB_LOG" | head -1 | cut -d: -f1)
  assert [ "$enable_line" -lt "$mask_line" ]
}

@test "carries the live session's saved Wi-Fi connections to the target, private and byte-identical (Phase 17)" {
  # Whatever the live session saved (the installer's Wi-Fi page, or nmtui from a
  # shell) is a NetworkManager connection file; copying it is all the hand-off is,
  # so this knows nothing about the format. 0600: NetworkManager ignores any
  # connection file others can read.
  local live="$BATS_TEST_TMPDIR/live-nm"
  mkdir -p "$live"
  printf '[connection]\nid=HomeNet\npsk=not-a-real-secret\n' >"$live/autarchy-wifi.nmconnection"
  chmod 600 "$live/autarchy-wifi.nmconnection"
  printf 'unrelated\n' >"$live/notes.txt"

  AUTARCHY_LIVE_NM_DIR="$live" run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  local dest="$TARGET/etc/NetworkManager/system-connections"
  run cmp "$live/autarchy-wifi.nmconnection" "$dest/autarchy-wifi.nmconnection"
  assert_success
  run find "$dest/autarchy-wifi.nmconnection" -perm 0600
  assert_output "$dest/autarchy-wifi.nmconnection"
  run find "$dest" -maxdepth 0 -perm 0700
  assert_output "$dest"
  # Only connection files are carried.
  assert [ ! -e "$dest/notes.txt" ]
  run calls
  assert_line "arch-chroot $TARGET chown -R root:root /etc/NetworkManager/system-connections"
}

@test "carries a private file even when the live copy is looser (Phase 17)" {
  local live="$BATS_TEST_TMPDIR/live-nm"
  mkdir -p "$live"
  printf '[connection]\nid=Loose\n' >"$live/loose.nmconnection"
  chmod 644 "$live/loose.nmconnection"
  AUTARCHY_LIVE_NM_DIR="$live" run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run find "$TARGET/etc/NetworkManager/system-connections/loose.nmconnection" -perm 0600
  assert_output "$TARGET/etc/NetworkManager/system-connections/loose.nmconnection"
}

@test "carries nothing, and does not fail, when the live session saved no connection (Phase 17)" {
  # The install is offline and Wi-Fi is optional: the common case is no profile.
  AUTARCHY_LIVE_NM_DIR="$BATS_TEST_TMPDIR/no-such-dir" run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  # (The profiles directory isn't even created; the connectivity drop-in is what
  # makes /etc/NetworkManager exist.)
  assert [ -z "$(find "$TARGET/etc/NetworkManager" -name '*.nmconnection')" ]
}

@test "sets the regulatory domain from the timezone, in wireless-regdb's own file (Phase 17)" {
  # wireless-regdb's udev rule runs set-wireless-regdom when cfg80211 loads; that
  # script sources this file and calls `iw reg set`. The kernel command line is
  # left alone (the cmdline tests above assert it unchanged).
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run grep -Fx 'WIRELESS_REGDOM="US"' "$TARGET/etc/conf.d/wireless-regdom"
  assert_success
  run grep -c '^WIRELESS_REGDOM=' "$TARGET/etc/conf.d/wireless-regdom"
  assert_output "1"
  # The shipped, commented list is left intact.
  run grep -Fx '#WIRELESS_REGDOM="GB"' "$TARGET/etc/conf.d/wireless-regdom"
  assert_success
}

@test "re-running does not duplicate the regulatory domain, and follows a changed timezone (Phase 17)" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run grep -c '^WIRELESS_REGDOM=' "$TARGET/etc/conf.d/wireless-regdom"
  assert_output "1"

  mkdir -p "$TARGET/usr/share/zoneinfo/Europe"
  touch "$TARGET/usr/share/zoneinfo/Europe/London"
  echo "TZONE=Europe/London" >>"$VARS"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run grep '^WIRELESS_REGDOM=' "$TARGET/etc/conf.d/wireless-regdom"
  assert_output 'WIRELESS_REGDOM="GB"'
}

@test "sets no regulatory domain for a timezone with no country, like UTC (Phase 17)" {
  echo "TZONE=UTC" >>"$VARS"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run grep -c '^WIRELESS_REGDOM=' "$TARGET/etc/conf.d/wireless-regdom"
  assert_output "0"
}

@test "skips the regulatory domain quietly when wireless-regdb's file isn't there (Phase 17)" {
  rm "$TARGET/etc/conf.d/wireless-regdom"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert [ ! -e "$TARGET/etc/conf.d/wireless-regdom" ]
}

@test "enables the root-scope maintenance timers from services-root.txt inside the target (Phase 16)" {
  # system/services-root.txt is the one home of that list (Phase 9); the
  # installer reuses install/enable-root-services rather than restating it.
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  assert_line "systemctl --root=$TARGET enable reflector.timer"
  assert_line "systemctl --root=$TARGET enable btrfs-scrub@-.timer"
  assert_line "systemctl --root=$TARGET enable pacman-filesdb-refresh.timer"
}

@test "creates snapper's root config from its shipped template, matching the runbook's settings (Phase 16)" {
  # scripts/update takes a pre-update `snapper -c root create`, which fails on a
  # machine with no root config -- and base-install.md's manual snapper steps
  # never ran on an ISO install. The config is written directly (not via
  # `snapper create-config`, which insists on creating its own /.snapshots
  # subvolume) because @snapshots is already mounted there.
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  local cfg="$TARGET/etc/snapper/configs/root"
  assert [ -e "$cfg" ]
  run cat "$cfg"
  assert_line 'SUBVOLUME="/"'
  assert_line 'TIMELINE_CREATE="no"'
  assert_line 'NUMBER_LIMIT="10"'
  assert_line 'NUMBER_LIMIT_IMPORTANT="10"'
  run grep -c 'NUMBER_LIMIT="50"\|TIMELINE_CREATE="yes"' "$cfg"
  assert_output "0"

  run cat "$TARGET/etc/conf.d/snapper"
  assert_line 'SNAPPER_CONFIGS="root"'
  run find "$TARGET/.snapshots" -maxdepth 0 -perm 0750
  assert_output "$TARGET/.snapshots"
}

@test "fails clearly when snapper's config template is missing" {
  rm "$TARGET/usr/share/snapper/config-templates/default"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_failure
  assert_output --partial "snapper"
}

@test "configures SDDM autologin for the new user (Phase 16)" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/etc/sddm.conf.d/20-autologin.conf")" \
    "$(printf '[Autologin]\nUser=alice\nSession=hyprland-uwsm')"
}

@test "installs a self-contained payload at /usr/local/share/autarchy/current -- no repo checkout, no ~/Projects (Phase 16)" {
  # The installed machine gets the OS content (what install/, scripts/, system/,
  # home/, packages/ and migrations/ hold), root-owned, and nothing else: no
  # .git (a machine isn't a dev checkout), no iso/ or tests/ (build-time
  # only), and never the GUI's vars file. The path must stay physically
  # stable across updates: stow records symlinks by resolved path and
  # refuses to restow over links into a different directory.
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  local payload="$TARGET/usr/local/share/autarchy/current"
  assert [ -e "$payload/install/configure-base-system" ]
  assert [ -e "$payload/install/link-home" ]
  assert [ -e "$payload/scripts/update" ]
  assert [ -e "$payload/system/files.txt" ]
  assert [ -e "$payload/home/bash/dot-bashrc" ]
  assert [ -e "$payload/packages/desktop.txt" ]
  assert [ -d "$payload/migrations" ]
  assert [ ! -e "$payload/.git" ]
  assert [ ! -e "$payload/iso" ]
  assert [ ! -e "$payload/tests" ]
  assert [ ! -e "$payload/gui" ]
  assert [ ! -e "$TARGET/home/alice/Projects" ]
  run calls
  assert_line "arch-chroot $TARGET chown -R root:root /usr/local/share/autarchy"
}

@test "records the installed release in the payload's VERSION file (Phase 16)" {
  echo "2026.09.20" >"$BATS_TEST_TMPDIR/live-release"
  AUTARCHY_LIVE_RELEASE_FILE="$BATS_TEST_TMPDIR/live-release" run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/usr/local/share/autarchy/current/VERSION")" "2026.09.20"
}

@test "VERSION is 'unreleased' when the live environment has no release marker" {
  AUTARCHY_LIVE_RELEASE_FILE="$BATS_TEST_TMPDIR/does-not-exist" run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/usr/local/share/autarchy/current/VERSION")" "unreleased"
}

@test "re-running replaces the payload instead of nesting a second copy inside it" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  touch "$TARGET/usr/local/share/autarchy/current/stale-file"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  assert [ ! -e "$TARGET/usr/local/share/autarchy/current/stale-file" ]
  assert [ ! -e "$TARGET/usr/local/share/autarchy/current/current" ]
}

@test "runs link-home apply as the new user from the installed payload (Phase 16)" {
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  assert_line "arch-chroot $TARGET runuser -u alice -- bash -c cd /usr/local/share/autarchy/current && install/link-home apply"
}

@test "creates the user's XDG directories, English-named and without Projects, before linking dotfiles (Phase 16)" {
  # xdg-user-dirs 0.20 creates ~/Projects by default; system/xdg/user-dirs.defaults
  # (installed by sync-system) is what keeps it -- and Desktop/Templates/Public --
  # out. LC_ALL=C keeps the names English regardless of the chosen locale, which
  # is what the screenshot/screen-record scripts' $HOME/Pictures fallback assumes.
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run calls
  assert_line "arch-chroot $TARGET runuser -u alice -- env HOME=/home/alice LC_ALL=C xdg-user-dirs-update"

  local xdg_line link_line
  xdg_line=$(grep -n 'xdg-user-dirs-update' "$STUB_LOG" | head -1 | cut -d: -f1)
  link_line=$(grep -n 'install/link-home apply' "$STUB_LOG" | head -1 | cut -d: -f1)
  assert [ "$xdg_line" -lt "$link_line" ]
}

@test "removes only the skel .bashrc before link-home apply, so stow doesn't abort on it (Phase 16)" {
  # useradd -m populates a fresh account from /etc/skel, which ships
  # .bash_logout/.bash_profile/.bashrc. Only .bashrc collides with a stow
  # package (home/bash/dot-bashrc), and GNU stow aborts its entire combined
  # call (every package, not just bash) on a single conflict -- which, under
  # set -Eeuo pipefail, killed the whole script before it reached
  # enable_services() (a real hardware install that booted to a bare TTY).
  # .bash_profile is what makes login shells (SSH, TTY) source .bashrc at
  # all; nothing in home/ replaces it, so it must survive.
  touch "$TARGET/home/alice/.bash_logout" \
    "$TARGET/home/alice/.bash_profile" \
    "$TARGET/home/alice/.bashrc"

  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success

  assert [ ! -e "$TARGET/home/alice/.bashrc" ]
  assert [ -e "$TARGET/home/alice/.bash_profile" ]
  assert [ -e "$TARGET/home/alice/.bash_logout" ]
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
  assert_line --partial 'name = "Alice Example"'
  assert_line --partial 'email = "alice@users.noreply.github.com"'
  run calls
  assert_line "arch-chroot $TARGET chown alice:alice /home/alice/.gitconfig.local"
}

@test "escapes quotes and backslashes in the git identity, so the file stays valid gitconfig (Phase 16)" {
  # Values are double-quoted with \" and \\ escapes: an unquoted or unescaped
  # name containing " or \ (or starting a # / ; comment) would corrupt the file.
  {
    echo "GIT_NAME='Al \"Ace\" O\\Brien; #1'"
    echo "GIT_EMAIL=alice@users.noreply.github.com"
  } >>"$VARS"
  run "$SCRIPT" "$VARS" "$TARGET"
  assert_success
  run cat "$TARGET/home/alice/.gitconfig.local"
  assert_line --partial 'name = "Al \"Ace\" O\\Brien; #1"'
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
