#!/usr/bin/env bats
# Unit tests for home/hardware/dot-local/bin/symphony-hardware: applies what
# system/hardware.txt says this machine needs (Phase 19, D-0082), and scans for what
# nothing handles. hwmatch is the real one over fixture sysfs/procfs; everything that
# installs or enables is a stub on PATH that logs its calls.

# Each @test runs in its own subshell, so per-test exports are intentionally local.
# shellcheck disable=SC2030,SC2031

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/hardware/dot-local/bin/symphony-hardware"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  SYS="$BATS_TEST_TMPDIR/sys"
  PROC="$BATS_TEST_TMPDIR/proc"
  ROOT="$BATS_TEST_TMPDIR/root"
  PAYLOAD="$BATS_TEST_TMPDIR/payload"
  mkdir -p "$SYS/bus/pci/devices" "$SYS/bus/usb/devices" "$SYS/class/dmi/id" "$PROC/asound" \
    "$ROOT/etc/modprobe.d" "$PAYLOAD/system/modprobe" "$PAYLOAD/system/hardware" \
    "$PAYLOAD/packages/hardware" "$PAYLOAD/scripts" "$PAYLOAD/install"
  export SYMPHONY_SYS="$SYS" SYMPHONY_PROC="$PROC" SYMPHONY_ROOT="$ROOT" \
    SYMPHONY_PAYLOAD_DIR="$PAYLOAD" SYMPHONY_JOURNAL="$BATS_TEST_TMPDIR/journal.txt"
  export SYMPHONY_HARDWARE_MAP="$PAYLOAD/system/hardware.txt" \
    SYMPHONY_HARDWARE_PACKAGES="$PAYLOAD/packages/hardware" SYMPHONY_SYSTEM_DIR="$PAYLOAD/system"
  : >"$SYMPHONY_HARDWARE_MAP"
  : >"$SYMPHONY_JOURNAL"
  cp "$REPO_ROOT/scripts/hwmatch" "$PAYLOAD/scripts/hwmatch"
  cp "$REPO_ROOT/scripts/pkglist" "$PAYLOAD/scripts/pkglist"
  make_stubs
}

# shellcheck disable=SC2016 # stub bodies expand when the stub runs
make_stubs() {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  # sudo runs the command as-is; `install -o root -g root` cannot chown as a user, so
  # the ownership flags are dropped (that they were asked for is in the log).
  cat >"$bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >>"$STUB_LOG"
if [[ $1 == install ]]; then
  args=()
  while (($#)); do case $1 in -o|-g) shift 2 ;; *) args+=("$1"); shift ;; esac; done
  exec "${args[@]}"
fi
exec "$@"
EOF
  printf '#!/usr/bin/env bash\necho "systemctl $*" >>"$STUB_LOG"\n' >"$bin/systemctl"
  printf '#!/usr/bin/env bash\necho "mkinitcpio $*" >>"$STUB_LOG"\n' >"$bin/mkinitcpio"
  # The payload's appliers, as stubs.
  printf '#!/usr/bin/env bash\necho "install-packages $*" >>"$STUB_LOG"\n' >"$PAYLOAD/install/install-packages"
  printf '#!/usr/bin/env bash\necho "sync-system $*" >>"$STUB_LOG"\n' >"$PAYLOAD/install/sync-system"
  # pacman -Qq answers what is "installed"
  printf '#!/usr/bin/env bash\ncase "$1" in -Qq) printf "%%s\\n" ${STUB_INSTALLED:-} ;; esac\n' >"$bin/pacman"
  chmod +x "$bin"/* "$PAYLOAD/install"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

pci() {
  local dir="$SYS/bus/pci/devices/$1"
  mkdir -p "$dir"
  echo "0x$2" >"$dir/vendor"
  echo "0x$3" >"$dir/device"
  echo "${PCI_CLASS:-0x028000}" >"$dir/class"
  echo "pci:v0000${2^^}d0000${3^^}sv00000000sd00000000bc02sc80i00" >"$dir/modalias"
  [[ -n ${4:-} ]] && mkdir -p "$dir/driver" # a bound driver is a `driver` symlink/dir
  return 0
}

usb() {
  local dir="$SYS/bus/usb/devices/$1"
  mkdir -p "$dir"
  echo "$2" >"$dir/idVendor"
  echo "$3" >"$dir/idProduct"
  echo "usb:v${2^^}p${3^^}d0100dc00dsc00dp00ic03isc00ip00in00" >"$dir/modalias"
  [[ -n ${4:-} ]] && mkdir -p "$dir/driver"
  return 0
}

entry() {
  printf '%s\n' "$*" >>"$SYMPHONY_HARDWARE_MAP"
}

list() {
  local name=$1
  shift
  printf '%s\n' "$@" >"$PAYLOAD/packages/hardware/$name.txt"
}

# --- usage / check -----------------------------------------------------------------

@test "usage error on a bad subcommand" {
  run "$SCRIPT" bogus
  assert_failure 2
  assert_output --partial "usage"
}

@test "check: names each present entry and what it would do; absent entries are listed as such" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl broadcom-wl-dkms
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  entry 'usb:187c:0525  packages=broadcom-wl service=x.service'
  run "$SCRIPT" check
  assert_success
  assert_output --partial "pci:14e4:43b1"
  assert_output --partial "broadcom-wl-dkms"
  assert_output --partial "usb:187c:0525"
  assert_output --regexp "absent|not present"
  run calls
  refute_output --partial "install-packages"
}

@test "check: says when a matched package is already installed" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl broadcom-wl-dkms
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  STUB_INSTALLED="broadcom-wl-dkms" run "$SCRIPT" check
  assert_success
  assert_output --partial "installed"
}

# --- apply -----------------------------------------------------------------------

@test "apply: installs the matched packages through the payload's install-packages" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl broadcom-wl-dkms linux-headers
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_line "install-packages broadcom-wl-dkms linux-headers"
}

@test "apply: a modprobe= file lands in /etc/modprobe.d, root-owned, and the initramfs is rebuilt" {
  pci 0000:0a:00.0 14e4 43b1
  printf 'options snd-hda-intel model=x\n' >"$PAYLOAD/system/modprobe/alc.conf"
  entry 'pci:14e4:43b1  modprobe=alc.conf'
  run "$SCRIPT" apply
  assert_success
  assert_equal "$(cat "$ROOT/etc/modprobe.d/alc.conf")" "options snd-hda-intel model=x"
  run calls
  assert_line --regexp "^sudo install .*alc.conf .*$ROOT/etc/modprobe.d/alc.conf"
  assert_line "sudo mkinitcpio -P"
}

@test "apply: a files= manifest is installed by sync-system with that manifest, as root" {
  usb 2-1 187c 0525
  printf '0644 hardware/60-alienfx.rules /etc/udev/rules.d/60-alienfx.rules\n' >"$PAYLOAD/system/hardware/alienfx.txt"
  entry 'usb:187c:0525  files=alienfx.txt'
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_line "sudo $PAYLOAD/install/sync-system --root $ROOT --manifest $PAYLOAD/system/hardware/alienfx.txt apply"
}

@test "apply: after a files= manifest that installs udev rules, the rules are reloaded and re-applied to devices already plugged in" {
  usb 2-1 187c 0525
  printf '0644 hardware/60-alienfx.rules /etc/udev/rules.d/60-alienfx.rules\n' >"$PAYLOAD/system/hardware/alienfx.txt"
  entry 'usb:187c:0525  files=alienfx.txt'
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\necho "udevadm $*" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/udevadm"
  chmod +x "$BATS_TEST_TMPDIR/bin/udevadm"
  mkdir -p "$ROOT/run/udev" && python3 -c "import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])" "$ROOT/run/udev/control"
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_line "sudo udevadm control --reload"
  assert_line --regexp "^sudo udevadm trigger .*--action=add"
}

@test "apply: a files= manifest with no udev rule does not touch udev" {
  usb 2-1 187c 0525
  printf '0644 hardware/thing.conf /etc/thing.conf\n' >"$PAYLOAD/system/hardware/thing.txt"
  entry 'usb:187c:0525  files=thing.txt'
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\necho "udevadm $*" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/udevadm"
  chmod +x "$BATS_TEST_TMPDIR/bin/udevadm"
  mkdir -p "$ROOT/run/udev" && python3 -c "import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])" "$ROOT/run/udev/control"
  run "$SCRIPT" apply
  assert_success
  run calls
  refute_output --partial "udevadm"
}

@test "apply: udev is not touched where it is not running (the installer's chroot)" {
  usb 2-1 187c 0525
  printf '0644 hardware/60-alienfx.rules /etc/udev/rules.d/60-alienfx.rules\n' >"$PAYLOAD/system/hardware/alienfx.txt"
  entry 'usb:187c:0525  files=alienfx.txt'
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\necho "udevadm $*" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/udevadm"
  chmod +x "$BATS_TEST_TMPDIR/bin/udevadm"
  run "$SCRIPT" apply
  assert_success
  run calls
  refute_output --partial "udevadm"
}

@test "apply: a service= is enabled as a user unit when it is one, else as a system unit via sudo" {
  usb 2-1 187c 0525
  mkdir -p "$PAYLOAD/home/hardware/dot-config/systemd/user"
  : >"$PAYLOAD/home/hardware/dot-config/systemd/user/alienfx-theme.service"
  entry 'usb:187c:0525  service=alienfx-theme.service service=power-profiles-daemon.service'
  run "$SCRIPT" apply
  assert_success
  run calls
  assert_line "systemctl --user enable --now alienfx-theme.service"
  assert_line "sudo systemctl enable --now power-profiles-daemon.service"
}

@test "apply: cmdline= is install-time only -- reported, never written to a running system" {
  pci 0000:0a:00.0 14e4 43b1
  entry 'pci:14e4:43b1  cmdline=module_blacklist=dell_rbtn'
  run "$SCRIPT" apply
  assert_success
  assert_output --partial "module_blacklist=dell_rbtn"
  assert_output --regexp "install time|installer"
  run calls
  refute_output --partial "cmdline"
}

@test "apply: nothing matched does nothing and says so" {
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  list broadcom-wl x
  run "$SCRIPT" apply
  assert_success
  assert_output --partial "nothing"
  run calls
  assert_output ""
}

@test "apply: sudo only where root is needed; packages go through yay as the user" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl x
  entry 'pci:14e4:43b1  packages=broadcom-wl'
  run "$SCRIPT" apply
  assert_success
  run calls
  refute_output --regexp "sudo .*install-packages"
}

@test "apply --no-packages: skips the package step (the installer has already pacstrapped them)" {
  pci 0000:0a:00.0 14e4 43b1
  list broadcom-wl x
  printf 'x\n' >"$PAYLOAD/system/modprobe/m.conf"
  entry 'pci:14e4:43b1  packages=broadcom-wl modprobe=m.conf'
  run "$SCRIPT" apply --no-packages
  assert_success
  run calls
  refute_output --partial "install-packages"
  assert_output --partial "m.conf"
}

@test "apply --user-only: touches only user units (first-login has no root)" {
  usb 2-1 187c 0525
  mkdir -p "$PAYLOAD/home/hardware/dot-config/systemd/user"
  : >"$PAYLOAD/home/hardware/dot-config/systemd/user/alienfx-theme.service"
  list alienfx alienfx
  entry 'usb:187c:0525  packages=alienfx service=alienfx-theme.service service=other.service'
  run "$SCRIPT" apply --user-only
  assert_success
  run calls
  assert_line "systemctl --user enable --now alienfx-theme.service"
  refute_output --partial "sudo"
  refute_output --partial "install-packages"
}

# --- scan ------------------------------------------------------------------------

@test "scan: names a PCI or USB device with no driver bound, by modalias, and stays silent about bound ones" {
  pci 0000:0a:00.0 14e4 43b1 bound
  pci 0000:01:00.0 10de 0fe4
  usb 2-1 187c 0525
  run "$SCRIPT" scan
  assert_success
  assert_output --partial "pci:v000010DEd00000FE4"
  assert_output --partial "usb:v187Cp0525"
  refute_output --partial "14E4d000043B1"
}

@test "scan: a PCI bridge with no driver (host bridge, class 06xx) is wiring, not an unhandled device" {
  PCI_CLASS=0x060000 pci 0000:00:00.0 8086 0c04
  run "$SCRIPT" scan
  assert_success
  refute_output --partial "8086:0c04"
  assert_output --partial "nothing unhandled"
}

@test "scan: reports firmware the kernel failed to load, from the journal" {
  printf 'kernel: iwlwifi 0000:02:00.0: Direct firmware load for iwlwifi-7260-17.ucode failed with error -2\n' >"$SYMPHONY_JOURNAL"
  run "$SCRIPT" scan
  assert_success
  assert_output --partial "iwlwifi-7260-17.ucode"
}

@test "scan: reports an audio codec whose output pins are all muted" {
  mkdir -p "$PROC/asound/card1"
  cat >"$PROC/asound/card1/codec#0" <<'EOF'
Codec: Realtek ALC3661
Vendor Id: 0x10ec0668
Subsystem Id: 0x102805a9
Node 0x14 [Pin Complex] wcaps 0x40058f: Stereo Amp-In Amp-Out
  Amp-Out vals:  [0x80 0x80]
  Pin-ctls: 0x40: OUT
Node 0x15 [Pin Complex] wcaps 0x40058d: Stereo Amp-Out
  Amp-Out vals:  [0x80 0x80]
  Pin-ctls: 0xc0: OUT HP
EOF
  run "$SCRIPT" scan
  assert_success
  assert_output --partial "ALC3661"
  assert_output --regexp "muted"
}

@test "scan: an unmuted codec is not reported" {
  mkdir -p "$PROC/asound/card1"
  printf 'Codec: Realtek ALC3661\nVendor Id: 0x10ec0668\nSubsystem Id: 0x102805a9\nNode 0x14 [Pin Complex] wcaps 0x40058f: Stereo Amp-Out\n  Amp-Out vals:  [0x00 0x00]\n  Pin-ctls: 0x40: OUT\n' >"$PROC/asound/card1/codec#0"
  run "$SCRIPT" scan
  assert_success
  refute_output --partial "muted"
}

@test "scan: a device an entry already covers is not reported as unhandled" {
  usb 2-1 187c 0525
  list alienfx alienfx
  entry 'usb:187c:0525  packages=alienfx'
  run "$SCRIPT" scan
  assert_success
  refute_output --partial "usb:v187Cp0525"
}

@test "scan: never installs or changes anything" {
  pci 0000:01:00.0 10de 0fe4
  run "$SCRIPT" scan
  assert_success
  run calls
  assert_output ""
}

@test "scan: nothing to report says so" {
  pci 0000:0a:00.0 14e4 43b1 bound
  run "$SCRIPT" scan
  assert_success
  assert_output --partial "nothing unhandled"
}
