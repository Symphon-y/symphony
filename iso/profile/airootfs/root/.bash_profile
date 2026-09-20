# shellcheck shell=bash
# autarchy live/install environment (root's shell is bash on this ISO,
# D-0009-adjacent Phase 10 decision; this file only affects an
# interactive login shell, never arch-chroot or scripted calls into this
# environment).
#
# tty1 auto-starts the real guided installer: a GTK4/libadwaita GUI,
# kiosk-launched via cage (a minimal wlroots compositor -- run one
# fullscreen app, exit when it exits; Phase 15/Milestone C). tty2+ stay
# on plain getty, landing on this same login shell below, as the escape
# hatch to the terminal fallback (autarchy-install) or the manual
# runbook path if the GUI can't start on real hardware.
if [[ $(tty) == /dev/tty1 ]]; then
  # Pinned, not left to GTK's own default: GTK >=4.16 defaults to a
  # Vulkan (GSK) renderer on Wayland, and the Alienware's Haswell/HD 4600
  # iGPU has documented blank-window bugs on exactly this GPU generation
  # (found during Phase 15 planning research). "gl" is the current
  # renderer name as of this ISO's GTK version -- renamed from the
  # older "ngl" docs mention; confirmed live via `GSK_RENDERER=help`.
  export GSK_RENDERER=gl
  exec cage -- /root/autarchy/gui/autarchy-installer
fi

cat <<'EOF'

  autarchy installer
  ===================
  Run:  autarchy-install

  Wi-Fi is optional (the install needs no network). To join a network first:
        nmtui
  A connection you save there is carried over to the installed system.

  (or see docs/runbooks/base-install.md in the baked-in repo at
  /root/autarchy for the manual step-by-step path)

EOF
