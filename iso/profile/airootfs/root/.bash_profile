# shellcheck shell=bash
# autarchy live/install environment -- printed once per login (root's
# shell is bash on this ISO, D-0009-adjacent Phase 10 decision; this file
# only affects an interactive login shell, never arch-chroot or scripted
# calls into this environment).
cat <<'EOF'

  autarchy installer
  ===================
  Run:  autarchy-install

  (or see docs/runbooks/base-install.md in the cloned repo for the manual
  step-by-step path)

EOF
