#!/usr/bin/env bats
# Unit tests for home/network/dot-local/bin/network-picker: networkmanager_dmenu
# with one rule replaced -- a WPA2/WPA3 transition-mode network gets a wpa-psk
# profile, not sae (D-0077).
#
# The real /usr/bin/networkmanager_dmenu needs libnm and a display; the tests
# point NETWORK_PICKER_UPSTREAM at a fake with the same three names the shim
# relies on (ap_security, create_wifi_profile, main). Its main() does what the
# real one does on a new network: builds the profile through the *module
# global* create_wifi_profile and reports the key management it ended up with.

setup() {
  load '../helpers/common'
  SCRIPT="$REPO_ROOT/home/network/dot-local/bin/network-picker"
  export NETWORK_PICKER_UPSTREAM="$BATS_TEST_TMPDIR/networkmanager_dmenu"
  cat >"$NETWORK_PICKER_UPSTREAM" <<'FAKE'
import os, sys

class Security:
    def __init__(self, key_mgmt):
        self.props = {"key-mgmt": key_mgmt}
    def get_key_mgmt(self):
        return self.props["key-mgmt"]
    def set_property(self, name, value):
        self.props[name] = value

class Profile:
    def __init__(self, security):
        self.security = security
    def get_setting_wireless_security(self):
        return self.security

def ap_security(nm_ap):
    return nm_ap  # the fake AP *is* its security string, e.g. "WPA2 WPA3"

def create_wifi_profile(nm_ap, password, adapter):
    sec = ap_security(nm_ap)
    if sec == "--":
        return Profile(None)
    return Profile(Security("sae" if "WPA3" in sec else "wpa-psk"))

def main():
    profile = create_wifi_profile(os.environ["FAKE_AP"], "hunter22", "wlan0")
    sec = profile.get_setting_wireless_security()
    print("key-mgmt:", "none" if sec is None else sec.get_key_mgmt())
    print("argv:", sys.argv[1:])

if __name__ == "__main__":
    main()
FAKE
}

@test "a WPA2/WPA3 transition network gets wpa-psk (upstream would pick sae)" {
  FAKE_AP="WPA2 WPA3" run "$SCRIPT"
  assert_success
  assert_line "key-mgmt: wpa-psk"
}

@test "a WPA3-only network still gets sae" {
  FAKE_AP="WPA3" run "$SCRIPT"
  assert_success
  assert_line "key-mgmt: sae"
}

@test "a WPA2-only network is untouched (wpa-psk)" {
  FAKE_AP="WPA2" run "$SCRIPT"
  assert_success
  assert_line "key-mgmt: wpa-psk"
}

@test "a WPA1+WPA3 network counts as offering PSK too" {
  FAKE_AP="WPA1 WPA3" run "$SCRIPT"
  assert_success
  assert_line "key-mgmt: wpa-psk"
}

@test "an open network has no security setting and is left alone" {
  FAKE_AP="--" run "$SCRIPT"
  assert_success
  assert_line "key-mgmt: none"
}

@test "arguments pass through to the upstream script unchanged" {
  FAKE_AP="WPA2" run "$SCRIPT" --extra one
  assert_success
  assert_line "argv: ['--extra', 'one']"
}

@test "fails closed if the upstream script no longer has the function it patches" {
  sed -i 's/^def create_wifi_profile/def build_wifi_profile/' "$NETWORK_PICKER_UPSTREAM"
  FAKE_AP="WPA2" run "$SCRIPT"
  assert_failure
  assert_output --partial "create_wifi_profile"
  refute_output --partial "key-mgmt:"
}

@test "fails closed if the upstream script is missing" {
  NETWORK_PICKER_UPSTREAM="$BATS_TEST_TMPDIR/nope" run "$SCRIPT"
  assert_failure
  assert_output --partial "nope"
}
