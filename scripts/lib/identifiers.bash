# identifiers: network and personal identifiers that must never be committed (IPv4,
# MAC, and IPv6 addresses; email addresses), with helpers to find or mask them.
# Sourced by scripts/check-identifiers and scripts/system-report.
#
# Patterns are extended regular expressions with explicit character classes, so the
# same text works in grep -E and sed -E, with GNU and BSD tools alike.

# The ERE for one kind of identifier: ipv4, mac, ipv6, or email.
identifier_pattern() {
  case $1 in
    ipv4) echo '([0-9]{1,3}\.){3}[0-9]{1,3}' ;;
    mac) echo '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' ;;
    # Global (2xxx:) and unique-local (fcxx:, fdxx:) addresses, plus link-local fe80::
    # addresses, whose interface part often embeds the MAC address.
    ipv6) echo '(2[0-9A-Fa-f]{3}|[Ff][CcDd][0-9A-Fa-f]{2}):([0-9A-Fa-f]{0,4}:){1,6}[0-9A-Fa-f]{0,4}|[Ff][Ee]80::?([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4}' ;;
    email) echo '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' ;;
  esac
}

# True for IPv4-looking text that identifies nothing: dotted numbers that can't be
# addresses, and the unspecified, loopback, and documentation (RFC 5737) ranges.
ipv4_identifies_nothing() {
  local IFS=. octet
  local -a octets
  read -ra octets <<<"$1"
  for octet in "${octets[@]}"; do
    if ((10#$octet > 255)); then
      return 0
    fi
  done
  [[ $1 == 0.0.0.0 || $1 == 127.* || $1 == 192.0.2.* || $1 == 198.51.100.* || $1 == 203.0.113.* ]]
}

# True when a match of the given kind is allowed in the repository.
identifier_allowed() {
  local kind=$1 match
  match=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
  case $kind in
    ipv4) ipv4_identifies_nothing "$match" ;;
    mac) [[ $match == 00:00:00:00:00:00 || $match == ff:ff:ff:ff:ff:ff ]] ;;
    ipv6) [[ $match == 2001:db8:* || $match == 2001:0db8:* ]] ;;
    # Project addresses, SSH algorithm names (chacha20-poly1305@openssh.com,
    # curve25519-sha256@libssh.org), and systemd escaped-root-path instance units
    # (btrfs-scrub@-.timer: "-" is systemd-escape --path / ) -- all look like email
    # addresses but name nobody.
    email) [[ $match == *@anthropic.com || $match == *@users.noreply.github.com ||
      $match == *@openssh.com || $match == *@libssh.org || $match == *@-.timer ||
      $match == *@-.service ]] ;;
    *) return 1 ;;
  esac
}

# Print "FILE:LINE: KIND" for every identifier in the given files that isn't allowed.
# Never prints the identifier itself: this output ends up in terminals and CI logs.
find_identifiers() {
  local file kind line match
  for file in "$@"; do
    for kind in ipv4 mac ipv6 email; do
      while IFS=: read -r line match; do
        if ! identifier_allowed "$kind" "$match"; then
          echo "$file:$line: $kind"
        fi
      done < <(grep -noEI "$(identifier_pattern "$kind")" "$file" || true)
    done
  done | awk '!seen[$0]++'
}

# Mask every identifier on stdin, allowed ones included: a report never needs them.
redact_identifiers() {
  sed -E \
    -e "s/$(identifier_pattern mac)/<mac>/g" \
    -e "s/$(identifier_pattern ipv6)/<ipv6>/g" \
    -e "s/$(identifier_pattern ipv4)/<ipv4>/g" \
    -e "s/$(identifier_pattern email)/<email>/g"
}
