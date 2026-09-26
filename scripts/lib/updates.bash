# updates: what is pending, in one file that update-check writes and everything else
# reads. Sourced by home/update/dot-local/bin/update-{check,notify,status,now}.
#
# Splitting detection from display is what lets the toast, the waybar badge and the
# applier agree without three copies of "what is pending" (Phase 20, D-0087).
#
# One key=value line per field. Package names and version tags contain no spaces,
# newlines or quotes, so nothing here needs escaping -- but it is read with a parser
# rather than `source`, because a corrupted state file must not become code.

updates_state_file() {
  echo "${SYMPHONY_STATE:-$HOME/.local/state/symphony}/updates"
}

# Sets UPDATE_PACKAGES, UPDATE_PKGLIST, UPDATE_RELEASE and UPDATE_INSTALLED. A machine
# that has never checked reads as nothing pending rather than as an error. `checked` is
# not loaded: updates_save always stamps it with now, so nothing round-trips it.
updates_load() {
  UPDATE_PACKAGES=0
  UPDATE_PKGLIST=""
  UPDATE_RELEASE=""
  UPDATE_INSTALLED=""

  local file key value
  file=$(updates_state_file)
  [[ -r $file ]] || return 0
  while IFS='=' read -r key value; do
    case $key in
      packages) UPDATE_PACKAGES=$value ;;
      pkglist) UPDATE_PKGLIST=$value ;;
      release) UPDATE_RELEASE=$value ;;
      installed) UPDATE_INSTALLED=$value ;;
    esac
  done <"$file"
  [[ $UPDATE_PACKAGES =~ ^[0-9]+$ ]] || UPDATE_PACKAGES=0
}

# Writes what the UPDATE_* variables currently say, stamped with now.
updates_save() {
  local file
  file=$(updates_state_file)
  mkdir -p "$(dirname "$file")"
  cat >"$file" <<STATE
packages=$UPDATE_PACKAGES
pkglist=$UPDATE_PKGLIST
release=$UPDATE_RELEASE
installed=$UPDATE_INSTALLED
checked=$(date +%s)
STATE
}

updates_pending() {
  ((UPDATE_PACKAGES > 0)) || [[ -n $UPDATE_RELEASE ]]
}

# A package list as a person reads it: comma-separated, cut short past $2 names with a
# count of the rest. 37 names is a state file's business, not a tooltip's or a toast's.
updates_pkglist_summary() {
  local -a names
  read -ra names <<<"$1"
  local max=${2:-10}
  ((${#names[@]})) || return 0

  local list rest=$((${#names[@]} - max))
  printf -v list '%s, ' "${names[@]:0:max}"
  list=${list%, }
  ((rest > 0)) && list+=" and $rest more"
  printf '%s' "$list"
}
