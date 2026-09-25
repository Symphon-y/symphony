# shellcheck shell=bash
# symphony live/install environment (root's shell is bash on this ISO,
# D-0009-adjacent Phase 10 decision; this file only affects an
# interactive login shell, never arch-chroot or scripted calls into this
# environment).
#
# tty1 auto-starts the real guided installer: a GTK4/libadwaita GUI,
# kiosk-launched via cage (a minimal wlroots compositor -- run one
# fullscreen app, exit when it exits; Phase 15/Milestone C). tty2+ stay
# on plain getty, landing on this same login shell below, as the escape
# hatch to the terminal fallback (symphony-install) or the manual
# runbook path if the GUI can't start on real hardware.
#
# symphony.nogui on the kernel command line (systemd-boot: press `e` on the entry
# and append it) skips the GUI and leaves this login shell on tty1 -- the only way
# to a terminal on tty1, since cage has no VT switching (D-0066), for diagnosing
# hardware the installer can't get past (a Wi-Fi adapter that is blocked or missing).
#
# Matched as a whole space-delimited token, not with grep -w (which would also
# match symphony.nogui-something: '-' counts as a word boundary).
if [[ $(tty) == /dev/tty1 ]] && ! grep -qE '(^| )symphony\.nogui( |$)' "${SYMPHONY_CMDLINE_FILE:-/proc/cmdline}"; then
  # Pinned, not left to GTK's own default: GTK >=4.16 defaults to a
  # Vulkan (GSK) renderer on Wayland, and the Alienware's Haswell/HD 4600
  # iGPU has documented blank-window bugs on exactly this GPU generation
  # (found during Phase 15 planning research). "gl" is the current
  # renderer name as of this ISO's GTK version -- renamed from the
  # older "ngl" docs mention; confirmed live via `GSK_RENDERER=help`.
  export GSK_RENDERER=gl
  exec cage -- /root/symphony/gui/symphony-installer
fi

cat <<'EOF'

  symphony installer
  ===================
  Run:  symphony-install

  Wi-Fi is optional (the install needs no network). To join a network first:
        nmtui
  A connection you save there is carried over to the installed system.

  The repo is baked in at /root/symphony; install/install-base-system and
  install/configure-base-system are the two steps symphony-install runs.

EOF
