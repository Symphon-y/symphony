# Helpers for acceptance tests that inspect the running system.

# Root-only checks: run directly when already root (the ISO), otherwise through
# sudo without prompting, so an expired sudo timestamp fails instead of hanging.
# Where the OS content this machine actually runs from lives: the root-owned
# payload on a machine installed from the ISO (D-0067), else the checkout the
# tests sit in. link-home must be checked from there -- stow links point into it.
os_root() {
  if [[ -d /usr/local/share/symphony/current/home ]]; then
    echo /usr/local/share/symphony/current
  else
    echo "$REPO_ROOT"
  fi
}

as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo -n "$@"
  fi
}
