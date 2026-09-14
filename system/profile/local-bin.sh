# Target: /etc/profile.d/local-bin.sh (installed by install/sync-system)
# shellcheck shell=sh
#
# Put ~/.local/bin, the XDG location for per-user programs, on PATH for login shells.
# Claude Code's native installer puts its launcher there, and Arch's /etc/profile
# doesn't add it.
#
# Appended, never prepended: a directory the user account can write to must not
# shadow system commands, or anything running as the user could plant a fake `sudo`
# that captures the password.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="${PATH:+$PATH:}$HOME/.local/bin" ;;
esac
export PATH
