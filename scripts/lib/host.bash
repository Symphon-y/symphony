# host: identify the machine a root filesystem belongs to.
# Sourced by install/sync-system and install/ssh-jump-host.

# Print the hostname from ROOT/etc/hostname when it is a plain hostname, so it can
# safely name a directory under system/hosts/; print nothing otherwise.
target_hostname() {
  local root=$1 name=""
  if [[ -r $root/etc/hostname ]]; then
    name=$(tr -d '[:space:]' <"$root/etc/hostname")
  fi
  if [[ $name =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
    echo "$name"
  fi
}
