# Helpers for acceptance tests that inspect the running system.

# Root-only checks: run directly when already root (the ISO), otherwise through
# sudo without prompting, so an expired sudo timestamp fails instead of hanging.
as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo -n "$@"
  fi
}
