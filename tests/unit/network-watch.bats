#!/usr/bin/env bats
# Unit tests for home/network/dot-local/bin/network-watch: after the network picker
# returns, turn NetworkManager's state into "Connecting / Connected / Could not connect"
# toasts, and remove only the profile the failed attempt created (D-0075).
#
# nmcli, notify-send and sleep are stubbed on PATH. The nmcli stub answers from files:
#   $STATES    one wifi-device state per poll (the last line repeats), e.g. "connecting (prepare)"
#   $ACTIVE    the active connections, "uuid:device:name" lines
#   $PROFILES  every saved profile, "uuid:type:name" lines

bats_require_minimum_version 1.5.0

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/network/dot-local/bin/network-watch"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  export STATES="$BATS_TEST_TMPDIR/states" ACTIVE="$BATS_TEST_TMPDIR/active" PROFILES="$BATS_TEST_TMPDIR/profiles"
  export NETWORK_WATCH_TIMEOUT=6 NETWORK_WATCH_GRACE=3
  : >"$STUB_LOG"
  : >"$ACTIVE"
  : >"$PROFILES"
  printf 'disconnected\n' >"$STATES"
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  cat >"$bin/nmcli" <<'STUB'
#!/usr/bin/env bash
echo "nmcli $*" >>"$STUB_LOG"
case "$*" in
  "-t -f DEVICE,TYPE,STATE device")
    state=$(head -n1 "$STATES")
    [[ $(wc -l <"$STATES") -gt 1 ]] && sed -i 1d "$STATES"
    [[ $state == none ]] || echo "wlp10s0:wifi:$state"
    echo "enp8s0:ethernet:unavailable"
    ;;
  "-t -f UUID,DEVICE,NAME connection show --active") cat "$ACTIVE" ;;
  "-t -f UUID,TYPE,NAME connection show") cat "$PROFILES" ;;
  "connection delete uuid "*) ;;
  *) echo "unexpected nmcli call: $*" >&2; exit 64 ;;
esac
STUB
  # shellcheck disable=SC2016 # the stub body expands when the stub runs, not here
  printf '#!/usr/bin/env bash\necho "notify-send $*" >>"$STUB_LOG"\n' >"$bin/notify-send"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/sleep"
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

# The saved profiles before the picker ran, as network-menu passes them (UUID per line).
watch() {
  printf '%s\n' "$@" | "$SCRIPT"
}

@test "connects: says Connecting, then Connected, and deletes nothing" {
  printf 'connecting (prepare)\nconnecting (getting IP configuration)\nconnected\n' >"$STATES"
  echo 'u-new:wlp10s0:HomeNet' >"$ACTIVE"
  echo 'u-new:802-11-wireless:HomeNet' >"$PROFILES"
  run watch
  assert_success
  run calls
  assert_output --partial "Connecting to HomeNet"
  assert_output --partial "Connected to HomeNet"
  refute_output --partial "Could not"
  refute_output --partial "connection delete"
}

@test "a wrong password on a NEW profile: says so, and deletes that profile so the next pick asks again" {
  printf 'connecting (need authentication)\ndisconnected\n' >"$STATES"
  echo 'u-new:wlp10s0:HomeNet' >"$ACTIVE"
  printf 'u-old:802-11-wireless:Work\nu-new:802-11-wireless:HomeNet\n' >"$PROFILES"
  run watch u-old
  assert_success
  run calls
  assert_output --partial "Could not connect to HomeNet"
  assert_output --partial "nmcli connection delete uuid u-new"
  refute_output --partial "connection delete uuid u-old"
}

@test "the failure toast is critical (it stays until dismissed)" {
  printf 'connecting (need authentication)\ndisconnected\n' >"$STATES"
  echo 'u-new:wlp10s0:HomeNet' >"$ACTIVE"
  echo 'u-new:802-11-wireless:HomeNet' >"$PROFILES"
  run watch
  run grep 'Could not connect' "$STUB_LOG"
  assert_output --partial "-u critical"
}

@test "a failure on a profile that already existed never deletes it, and says how to forget it" {
  printf 'connecting (need authentication)\ndisconnected\n' >"$STATES"
  echo 'u-old:wlp10s0:HomeNet' >"$ACTIVE"
  echo 'u-old:802-11-wireless:HomeNet' >"$PROFILES"
  run watch u-old
  assert_success
  run calls
  assert_output --partial "Could not connect to HomeNet"
  assert_output --partial "forget"
  refute_output --partial "connection delete"
}

@test "a failure so quick it is over before the first look still reports it and removes the new profile" {
  printf 'disconnected\n' >"$STATES"
  echo 'u-new:802-11-wireless:HomeNet' >"$PROFILES"
  run watch
  assert_success
  run calls
  assert_output --partial "Could not connect to HomeNet"
  assert_output --partial "nmcli connection delete uuid u-new"
}

@test "a cancelled picker is silent: no toast, nothing deleted" {
  echo 'u-old:802-11-wireless:Work' >"$PROFILES"
  run watch u-old
  assert_success
  run calls
  refute_output --partial "notify-send"
  refute_output --partial "connection delete"
}

@test "already connected and nothing changed: silent" {
  printf 'connected\n' >"$STATES"
  echo 'u-old:wlp10s0:Work' >"$ACTIVE"
  echo 'u-old:802-11-wireless:Work' >"$PROFILES"
  run watch u-old
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "switching from one connected network to another reports the new one" {
  printf 'connected\nconnecting (prepare)\nconnected\n' >"$STATES"
  echo 'u-b:wlp10s0:Cafe' >"$ACTIVE"
  printf 'u-a:802-11-wireless:Work\nu-b:802-11-wireless:Cafe\n' >"$PROFILES"
  run watch u-a u-b
  assert_success
  run calls
  assert_output --partial "Connecting to Cafe"
  assert_output --partial "Connected to Cafe"
}

@test "still connecting after the timeout: says so once and stops, deleting nothing" {
  printf 'connecting (prepare)\n' >"$STATES"
  echo 'u-new:wlp10s0:HomeNet' >"$ACTIVE"
  echo 'u-new:802-11-wireless:HomeNet' >"$PROFILES"
  run watch
  assert_success
  run calls
  assert_output --partial "Still connecting to HomeNet"
  refute_output --partial "connection delete"
}

@test "a network name with a colon is shown as typed" {
  printf 'connecting (prepare)\nconnected\n' >"$STATES"
  echo 'u-new:wlp10s0:Cafe\: Free' >"$ACTIVE"
  echo 'u-new:802-11-wireless:Cafe\: Free' >"$PROFILES"
  run watch
  assert_success
  run calls
  assert_output --partial "Connected to Cafe: Free"
}

@test "no Wi-Fi device: silent, exit 0" {
  printf 'none\n' >"$STATES"
  run watch
  assert_success
  run calls
  refute_output --partial "notify-send"
}

@test "without notify-send it still works, saying so on stderr instead of staying silent" {
  rm "$BATS_TEST_TMPDIR/bin/notify-send"
  printf 'connecting (prepare)\nconnected\n' >"$STATES"
  echo 'u-new:wlp10s0:HomeNet' >"$ACTIVE"
  echo 'u-new:802-11-wireless:HomeNet' >"$PROFILES"
  run --separate-stderr watch
  assert_success
  [[ $stderr == *"Connected to HomeNet"* ]]
}

@test "never asks NetworkManager for secrets (D-0069: the passphrase is not ours to touch)" {
  printf 'connecting (prepare)\nconnected\n' >"$STATES"
  echo 'u-new:wlp10s0:HomeNet' >"$ACTIVE"
  echo 'u-new:802-11-wireless:HomeNet' >"$PROFILES"
  run watch
  assert_success
  run calls
  refute_output --partial "show-secrets"
  refute_output --partial "password"
  refute_output --partial "psk"
}

@test "a new profile that is not Wi-Fi (an Ethernet one NetworkManager made meanwhile) is never touched" {
  printf 'disconnected\n' >"$STATES"
  echo 'u-eth:ethernet:Wired connection 1' >"$PROFILES"
  run watch
  assert_success
  run calls
  refute_output --partial "notify-send"
  refute_output --partial "connection delete"
}
