# osd: one on-screen display, replaced in place rather than stacked.
# Sourced by home/media/dot-local/bin/{volume,brightness,player}.
#
# Holding a volume key fires this many times a second, and a desktop shows one bar that
# moves, not forty toasts. mako documents neither x-canonical-private-synchronous nor a
# `synchronous` criterion, so replacement goes through what it does document:
# notify-send -p prints the id of the notification it raised, and -r replaces that id
# next time. One id for all three roles, so brightness replaces a volume bar rather
# than queueing behind it -- which is how an OSD is expected to behave.

osd_id_file() {
  echo "${SYMPHONY_STATE:-$HOME/.local/state/symphony}/osd-id"
}

# osd_show SUMMARY BODY [PERCENT]
#
# Never fails its caller: the OSD is a nicety and the volume change is the point, so a
# desktop with no notification daemon still gets working keys.
osd_show() {
  command -v notify-send >/dev/null || return 0

  local summary=$1 body=$2 percent=${3:-}
  local file id=0 new
  file=$(osd_id_file)
  [[ -r $file ]] && id=$(<"$file")
  [[ $id =~ ^[0-9]+$ ]] || id=0

  local -a hints=()
  [[ -n $percent ]] && hints=(-h "int:value:$percent")

  # -t is explicit: mako's [app-name=symphony] section sets a 30 s default for the
  # update offer, which would otherwise leave a volume bar up for half a minute.
  new=$(notify-send -a symphony -p -r "$id" -t 1500 "${hints[@]}" "$summary" "$body") || return 0

  mkdir -p "$(dirname "$file")"
  printf '%s' "$new" >"$file"
}
