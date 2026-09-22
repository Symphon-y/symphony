#!/usr/bin/env bats
# Unit tests for the Phase 19 migration that removes the global WirePlumber soft-mixer
# rule (D-0083): the stow link the old payload left is gone after restow, but a machine
# themed before may still have WirePlumber's remembered routes, which keep the
# hardware mixer untouched until they are cleared. HOME is a temp dir; systemctl is a stub.

setup() {
  load '../helpers/common'
  SCRIPT=$(ls "$REPO_ROOT"/migrations/*-drop-global-alsa-soft-mixer.sh)
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d" "$HOME/.local/state/wireplumber" "$BATS_TEST_TMPDIR/bin"
  # shellcheck disable=SC2016 # stub body expands when the stub runs
  printf '#!/usr/bin/env bash\necho "systemctl $*" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/systemctl"
  chmod +x "$BATS_TEST_TMPDIR/bin/systemctl"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

calls() {
  cat "$STUB_LOG"
}

@test "removes a leftover soft-mixer rule (link or file), the remembered routes, and restarts WirePlumber" {
  ln -s /nowhere "$HOME/.config/wireplumber/wireplumber.conf.d/51-alsa-soft-mixer.conf"
  echo "x" >"$HOME/.local/state/wireplumber/default-routes"
  run "$SCRIPT"
  assert_success
  assert [ ! -e "$HOME/.config/wireplumber/wireplumber.conf.d/51-alsa-soft-mixer.conf" ]
  assert [ ! -L "$HOME/.config/wireplumber/wireplumber.conf.d/51-alsa-soft-mixer.conf" ]
  assert [ ! -e "$HOME/.local/state/wireplumber/default-routes" ]
  run calls
  assert_line "systemctl --user try-restart wireplumber.service"
}

@test "is a no-op when there is nothing to remove" {
  run "$SCRIPT"
  assert_success
  run calls
  assert_output ""
}

@test "leaves other WirePlumber rules and state alone" {
  echo "keep" >"$HOME/.config/wireplumber/wireplumber.conf.d/52-bluetooth-a2dp-autoconnect.conf"
  echo "keep" >"$HOME/.local/state/wireplumber/default-profile"
  echo "x" >"$HOME/.local/state/wireplumber/default-routes"
  run "$SCRIPT"
  assert_success
  assert [ -e "$HOME/.config/wireplumber/wireplumber.conf.d/52-bluetooth-a2dp-autoconnect.conf" ]
  assert [ -e "$HOME/.local/state/wireplumber/default-profile" ]
}
