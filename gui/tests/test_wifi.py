import os
import re
import stat
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from installer import wifi
from installer.wifi import (
    AccessPoint,
    ConnectFailed,
    ConnectTimeout,
    InvalidPassphrase,
    InvalidSsid,
    NetworkNotFound,
    RadioState,
    Security,
    UnsupportedNetwork,
    WifiBackend,
    WrongPassword,
    classify_security,
    keyfile_for,
    parse_scan,
    validate_passphrase,
    validate_ssid,
)


# --- a stand-in for the parts of nmcli/rfkill this module talks to -----------------


class Result:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


class FakeRunner:
    """Records every command and answers from a table keyed by the argv prefix.
    Nothing here touches a radio, NetworkManager or the network."""

    def __init__(self, answers=None):
        self.calls = []
        self.answers = answers or {}

    def __call__(self, argv):
        self.calls.append(list(argv))
        for prefix, result in self.answers.items():
            if tuple(argv[: len(prefix)]) == prefix:
                return result(argv) if callable(result) else result
        return Result()


def unescape(value):
    """A keyfile value as NetworkManager reads it back (GLib key-file rules) --
    the oracle behind the golden tests, checked against a real NetworkManager
    1.58.1 when these fixtures were made (see the phase-17 tracking doc)."""
    return re.sub(
        r"\\(.)",
        lambda m: {"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}[m.group(1)],
        value,
    )


def keyfile_values(text, section, key):
    current = None
    for line in text.splitlines():
        if line.startswith("["):
            current = line.strip("[]")
        elif current == section and line.startswith(key + "="):
            return line[len(key) + 1 :]
    return None


# Awkward SSIDs and passphrases, every one of which round-tripped through a real
# NetworkManager with the escaping under test (phase-17 spike 1).
ROUND_TRIP_CASES = [
    ("HomeNet", "correct horse"),
    ("My;Net", "pass;word"),
    ("1;2;3", "12345678"),
    ("a#b c", "p#ss w0rd!"),
    ("back\\slash", "pa\\ss\\\\word"),
    ("end\\", "endswith\\bs-pass"),
    ("café ☕", "pässwörd-日本語"),
    (" lead", "  spaces  pass"),
    ("trail ", "trailing pass "),
    ("a  b", "a  b  c  d"),
    ("t\tab", "ta\tb-pass-xx"),
    ('say "hi"', 'it\'s "quoted"'),
    ("[wifi]", "[connection]x"),
    ("a=b", "k=v=w=passw"),
    ("x\\sy", "pw\\sfoo\\tbar"),
    ("S" * 32, "p" * 63),
]

UUID = "11111111-2222-3333-4444-555555555555"


class ParseScanTest(unittest.TestCase):
    def test_reads_current_signal_and_security(self):
        aps = parse_scan("*:HomeNet:82:WPA2\n:Guest:64:WPA2 WPA3\n")
        home = next(a for a in aps if a.ssid == "HomeNet")
        self.assertTrue(home.in_use)
        self.assertEqual(home.signal, 82)
        self.assertEqual(home.security, Security.WPA_PSK)
        self.assertFalse(next(a for a in aps if a.ssid == "Guest").in_use)

    def test_unescapes_colons_and_backslashes_in_ssids(self):
        aps = parse_scan(":Cafe\\: Free:55:--\n:Back\\\\slash:33:WPA3\n")
        self.assertEqual({a.ssid for a in aps}, {"Cafe: Free", "Back\\slash"})

    def test_drops_hidden_networks_with_no_ssid(self):
        self.assertEqual(parse_scan("::40:WPA2\n"), [])

    def test_collapses_duplicate_ssids_to_the_strongest(self):
        aps = parse_scan(":HomeNet:60:WPA2\n:HomeNet:82:WPA2\n:HomeNet:30:WPA2\n")
        self.assertEqual([(a.ssid, a.signal) for a in aps], [("HomeNet", 82)])

    def test_keeps_the_in_use_mark_even_when_the_connected_access_point_is_the_weaker(self):
        aps = parse_scan("*:HomeNet:40:WPA2\n:HomeNet:82:WPA2\n")
        self.assertEqual(len(aps), 1)
        self.assertTrue(aps[0].in_use)
        self.assertEqual(aps[0].signal, 82)

    def test_sorts_strongest_first(self):
        aps = parse_scan(":Weak:20:WPA2\n:Strong:90:WPA2\n:Mid:55:WPA2\n")
        self.assertEqual([a.ssid for a in aps], ["Strong", "Mid", "Weak"])

    def test_skips_malformed_lines_and_blank_input(self):
        self.assertEqual(parse_scan(""), [])
        self.assertEqual(parse_scan("garbage\n:only:two\n"), [])
        self.assertEqual(parse_scan(":Net:notanumber:WPA2\n"), [])


class ClassifySecurityTest(unittest.TestCase):
    def test_classes(self):
        cases = {
            "--": Security.OPEN,
            "": Security.OPEN,
            "WPA2": Security.WPA_PSK,
            "WPA1 WPA2": Security.WPA_PSK,
            "WPA1": Security.WPA_PSK,
            # A WPA2/WPA3 transition network accepts a plain WPA2 handshake.
            "WPA2 WPA3": Security.WPA_PSK,
            "WPA3": Security.SAE,
            "WPA2 802.1X": Security.ENTERPRISE,
            "WPA3 802.1X": Security.ENTERPRISE,
            "802.1X": Security.ENTERPRISE,
            "WEP": Security.UNSUPPORTED,
            "OWE": Security.UNSUPPORTED,
        }
        for field, expected in cases.items():
            with self.subTest(field=field):
                self.assertEqual(classify_security(field), expected)

    def test_only_open_psk_and_sae_can_be_joined_here(self):
        supported = {s for s in Security if AccessPoint("x", 50, s).supported}
        self.assertEqual(supported, {Security.OPEN, Security.WPA_PSK, Security.SAE})


class ValidationTest(unittest.TestCase):
    def test_ssid_must_be_one_to_thirty_two_bytes(self):
        validate_ssid("a")
        validate_ssid("S" * 32)
        validate_ssid("café ☕")  # counted in bytes, not characters
        for bad in ["", "S" * 33, "é" * 17]:
            with self.subTest(ssid=bad), self.assertRaises(InvalidSsid):
                validate_ssid(bad)

    def test_passphrase_is_eight_to_sixty_three_characters_or_sixty_four_hex(self):
        validate_passphrase("12345678", Security.WPA_PSK)
        validate_passphrase("p" * 63, Security.WPA_PSK)
        validate_passphrase("a" * 64, Security.WPA_PSK)  # 64 hex digits
        # NetworkManager itself only accepts printable ASCII for a WPA passphrase.
        for bad in ["", "1234567", "p" * 64 + "!", "g" * 64, "pässwörd!", "tab\there1"]:
            with self.subTest(psk=bad), self.assertRaises(InvalidPassphrase):
                validate_passphrase(bad, Security.WPA_PSK)

    def test_open_networks_take_no_passphrase(self):
        validate_passphrase("", Security.OPEN)


class KeyfileTest(unittest.TestCase):
    def test_a_plain_wpa_network(self):
        text = keyfile_for("HomeNet", "correct horse", Security.WPA_PSK, uuid=UUID)
        self.assertEqual(
            text,
            "[connection]\n"
            "id=HomeNet\n"
            f"uuid={UUID}\n"
            "type=wifi\n"
            "autoconnect=true\n"
            "\n"
            "[wifi]\n"
            "mode=infrastructure\n"
            "ssid=HomeNet\n"
            "\n"
            "[wifi-security]\n"
            "key-mgmt=wpa-psk\n"
            "psk-flags=0\n"
            "psk=correct horse\n"
            "\n"
            "[ipv4]\n"
            "method=auto\n"
            "\n"
            "[ipv6]\n"
            "method=auto\n",
        )

    def test_sae_uses_the_sae_key_management(self):
        text = keyfile_for("Net", "correct horse", Security.SAE, uuid=UUID)
        self.assertEqual(keyfile_values(text, "wifi-security", "key-mgmt"), "sae")

    def test_open_networks_have_no_security_section(self):
        text = keyfile_for("Cafe", "", Security.OPEN, uuid=UUID)
        self.assertNotIn("[wifi-security]", text)
        self.assertNotIn("psk", text)

    def test_hidden_only_when_asked(self):
        self.assertNotIn("hidden", keyfile_for("Net", "correct horse", Security.WPA_PSK, uuid=UUID))
        hidden = keyfile_for("Net", "correct horse", Security.WPA_PSK, hidden=True, uuid=UUID)
        self.assertEqual(keyfile_values(hidden, "wifi", "hidden"), "true")

    def test_the_secret_is_stored_in_the_file_not_left_to_a_keyring(self):
        # A bare Hyprland session has no keyring agent to hand it back at boot.
        text = keyfile_for("Net", "correct horse", Security.WPA_PSK, uuid=UUID)
        self.assertEqual(keyfile_values(text, "wifi-security", "psk-flags"), "0")

    def test_never_writes_a_permissions_line(self):
        # A `permissions=user:...` line would tie the profile to the live session's
        # user; the installed system has a different one.
        text = keyfile_for("Net", "correct horse", Security.WPA_PSK, uuid=UUID)
        self.assertNotIn("permissions", text)

    def test_generates_a_uuid_when_none_is_given(self):
        text = keyfile_for("Net", "correct horse", Security.WPA_PSK)
        self.assertRegex(keyfile_values(text, "connection", "uuid"), r"^[0-9a-f-]{36}$")

    def test_golden_escaping(self):
        # Exactly what NetworkManager needs to read the original value back:
        # \ -> \\, tab/newline/CR -> \t \n \r, a leading or trailing space -> \s.
        goldens = [
            ("back\\slash", "pa\\ss\\\\word", r"back\\slash", r"pa\\ss\\\\word"),
            (" lead", "  spaces  pass", r"\slead", r"\s spaces  pass"),
            ("trail ", "trailing pass ", r"trail\s", r"trailing pass\s"),
            ("t\tab", "ta\tb-pass-xx", r"t\tab", r"ta\tb-pass-xx"),
            ("My;Net", "pass;word", "My;Net", "pass;word"),
            ("a#b c", 'p#ss "w0rd"=[x]', "a#b c", 'p#ss "w0rd"=[x]'),
        ]
        for ssid, psk, want_ssid, want_psk in goldens:
            with self.subTest(ssid=ssid):
                text = keyfile_for(ssid, psk, Security.WPA_PSK, uuid=UUID)
                self.assertEqual(keyfile_values(text, "wifi", "ssid"), want_ssid)
                self.assertEqual(keyfile_values(text, "wifi-security", "psk"), want_psk)

    def test_every_awkward_value_reads_back_unchanged(self):
        for ssid, psk in ROUND_TRIP_CASES:
            with self.subTest(ssid=ssid):
                text = keyfile_for(ssid, psk, Security.WPA_PSK, uuid=UUID)
                self.assertEqual(unescape(keyfile_values(text, "wifi", "ssid")), ssid)
                self.assertEqual(unescape(keyfile_values(text, "wifi-security", "psk")), psk)
                self.assertEqual(unescape(keyfile_values(text, "connection", "id")), ssid)

    def test_a_newline_cannot_inject_another_key(self):
        text = keyfile_for("Net", "abc\nautoconnect=false\n[x]", Security.WPA_PSK, uuid=UUID)
        lines = text.splitlines()
        # The newlines are escaped inside the psk value, so no line of the file
        # is the injected key or section.
        self.assertNotIn("autoconnect=false", lines)
        self.assertNotIn("[x]", lines)
        self.assertEqual(sum(1 for line in lines if line.startswith("autoconnect=")), 1)


class WifiBackendTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.profile_dir = Path(self._dir.name)
        self.profile = self.profile_dir / "symphony-wifi.nmconnection"

    def backend(self, answers=None):
        runner = FakeRunner(answers)
        return WifiBackend(run=runner, profile_dir=self.profile_dir, new_uuid=lambda: UUID), runner

    def ok_connect_answers(self):
        return {
            ("nmcli", "-t", "-f", "UUID", "connection", "show"): Result(stdout=f"{UUID}\n"),
        }

    # -- reading state

    def test_scan_asks_nmcli_for_the_four_fields_and_parses_them(self):
        be, runner = self.backend(
            {("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY"): Result(stdout=":HomeNet:70:WPA2\n")}
        )
        self.assertEqual([a.ssid for a in be.scan()], ["HomeNet"])
        self.assertEqual(
            runner.calls[0],
            ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"],
        )

    def test_scan_can_force_a_rescan(self):
        be, runner = self.backend()
        be.scan(rescan=True)
        self.assertEqual(runner.calls[0][-2:], ["--rescan", "yes"])

    def test_a_refused_rescan_falls_back_to_the_cached_list(self):
        # NetworkManager throttles rescans; that must not empty the list.
        def answer(argv):
            if argv[-1] == "yes":
                return Result(returncode=1, stderr="Error: Scanning not allowed immediately")
            return Result(stdout=":HomeNet:70:WPA2\n")

        be, runner = self.backend({("nmcli", "-t"): answer})
        self.assertEqual([a.ssid for a in be.scan(rescan=True)], ["HomeNet"])
        self.assertEqual(runner.calls[-1][-2:], ["--rescan", "no"])

    def test_radio_states(self):
        cases = {
            "enabled:enabled": RadioState.ON,
            "enabled:disabled": RadioState.SOFT_BLOCKED,
            "disabled:disabled": RadioState.HARD_BLOCKED,
            "disabled:enabled": RadioState.HARD_BLOCKED,
            # What a real NetworkManager 1.58.1 prints, captured in a container with
            # no Wi-Fi device: the daemon knows of no Wi-Fi hardware or killswitch at
            # all. This used to be reported as "switched off by a hardware switch".
            "missing:enabled": RadioState.NO_ADAPTER,
            "missing:disabled": RadioState.NO_ADAPTER,
        }
        for out, expected in cases.items():
            with self.subTest(out=out):
                be, _ = self.backend({("nmcli", "-t", "-f", "WIFI-HW,WIFI", "radio"): Result(stdout=out + "\n")})
                self.assertEqual(be.radio_state(), expected)

    def test_a_value_it_does_not_recognise_is_unknown_never_a_confident_hard_block(self):
        # A localized nmcli, a future NetworkManager word, or garbage: say "can't
        # tell" rather than blame a hardware switch.
        for out in ["aktiviert:aktiviert", "unavailable:enabled", "enabled:whatever", "garbage", "", "a:b:c"]:
            with self.subTest(out=out):
                be, _ = self.backend({("nmcli", "-t", "-f", "WIFI-HW,WIFI", "radio"): Result(stdout=out + "\n")})
                self.assertEqual(be.radio_state(), RadioState.UNKNOWN)

    def test_a_failing_nmcli_is_unknown(self):
        # Exit 8 is what nmcli returns while NetworkManager is still starting.
        be, _ = self.backend(
            {
                ("nmcli", "-t", "-f", "WIFI-HW,WIFI", "radio"): Result(
                    returncode=8, stderr="Error: NetworkManager is not running."
                )
            }
        )
        self.assertEqual(be.radio_state(), RadioState.UNKNOWN)

    def test_enabling_the_radio_clears_rfkill_then_turns_it_on(self):
        be, runner = self.backend()
        be.enable_radio()
        self.assertEqual(runner.calls, [["rfkill", "unblock", "wifi"], ["nmcli", "radio", "wifi", "on"]])

    def test_ethernet_and_online_state(self):
        be, _ = self.backend(
            {
                ("nmcli", "-t", "-f", "TYPE,STATE", "device"): Result(stdout="wifi:disconnected\nethernet:connected\n"),
                ("nmcli", "-t", "-f", "STATE", "general"): Result(stdout="connected\n"),
            }
        )
        self.assertTrue(be.ethernet_connected())
        self.assertTrue(be.is_online())

    def test_not_online_and_no_ethernet(self):
        be, _ = self.backend(
            {
                ("nmcli", "-t", "-f", "TYPE,STATE", "device"): Result(stdout="wifi:connected\nethernet:unavailable\n"),
                ("nmcli", "-t", "-f", "STATE", "general"): Result(stdout="disconnected\n"),
            }
        )
        self.assertFalse(be.ethernet_connected())
        self.assertFalse(be.is_online())

    # -- connecting

    def test_connect_writes_a_private_profile_reloads_and_brings_it_up(self):
        be, runner = self.backend(self.ok_connect_answers())
        be.connect("HomeNet", "correct horse", Security.WPA_PSK)

        self.assertEqual(stat.S_IMODE(self.profile.stat().st_mode), 0o600)
        self.assertEqual(
            self.profile.read_text(encoding="utf-8"),
            keyfile_for("HomeNet", "correct horse", Security.WPA_PSK, uuid=UUID),
        )
        self.assertEqual(
            runner.calls,
            [
                ["nmcli", "connection", "reload"],
                ["nmcli", "-t", "-f", "UUID", "connection", "show"],
                ["nmcli", "-w", "30", "connection", "up", "uuid", UUID],
            ],
        )

    def test_the_profile_is_private_even_under_a_permissive_umask(self):
        old = os.umask(0)
        self.addCleanup(os.umask, old)
        be, _ = self.backend(self.ok_connect_answers())
        be.connect("HomeNet", "correct horse", Security.WPA_PSK)
        self.assertEqual(stat.S_IMODE(self.profile.stat().st_mode), 0o600)

    def test_a_looser_existing_profile_is_tightened_not_reused(self):
        self.profile.write_text("old")
        self.profile.chmod(0o644)
        be, _ = self.backend(self.ok_connect_answers())
        be.connect("HomeNet", "correct horse", Security.WPA_PSK)
        self.assertEqual(stat.S_IMODE(self.profile.stat().st_mode), 0o600)
        self.assertNotIn("old", self.profile.read_text(encoding="utf-8"))

    def test_the_passphrase_is_never_in_any_command_line(self):
        # The whole reason the profile is written from here rather than passed to
        # `nmcli ... password X`: argv is world-readable in /proc.
        secret = "sup3r-s3cret-passphrase"
        be, runner = self.backend(self.ok_connect_answers())
        be.connect("HomeNet", secret, Security.WPA_PSK)
        for argv in runner.calls:
            for arg in argv:
                self.assertNotIn(secret, arg)

    def test_connecting_to_an_open_network_needs_no_passphrase(self):
        be, _ = self.backend(self.ok_connect_answers())
        be.connect("Cafe", "", Security.OPEN)
        self.assertNotIn("psk", self.profile.read_text(encoding="utf-8"))

    def test_a_hidden_network_is_written_hidden(self):
        be, _ = self.backend(self.ok_connect_answers())
        be.connect("Secret", "correct horse", Security.WPA_PSK, hidden=True)
        self.assertIn("hidden=true", self.profile.read_text(encoding="utf-8"))

    def test_invalid_input_and_unsupported_networks_are_refused_before_anything_is_written(self):
        be, runner = self.backend()
        with self.assertRaises(InvalidPassphrase):
            be.connect("HomeNet", "short", Security.WPA_PSK)
        with self.assertRaises(InvalidSsid):
            be.connect("", "correct horse", Security.WPA_PSK)
        with self.assertRaises(UnsupportedNetwork):
            be.connect("Office", "correct horse", Security.ENTERPRISE)
        self.assertFalse(self.profile.exists())
        self.assertEqual(runner.calls, [])

    def test_a_profile_networkmanager_did_not_accept_is_removed_and_reported(self):
        # A file NetworkManager rejects (mode, ownership, syntax) is ignored
        # silently -- so it is checked for after the reload.
        be, runner = self.backend({("nmcli", "-t", "-f", "UUID", "connection", "show"): Result(stdout="other\n")})
        with self.assertRaises(ConnectFailed):
            be.connect("HomeNet", "correct horse", Security.WPA_PSK)
        self.assertFalse(self.profile.exists())
        self.assertNotIn(["nmcli", "-w", "30", "connection", "up", "uuid", UUID], runner.calls)

    def test_failures_are_named_and_the_profile_is_deleted(self):
        cases = [
            ("Error: Connection activation failed: (7) Secrets were required, but not provided.", WrongPassword),
            ("Error: Connection activation failed: (53) The Wi-Fi network could not be found.", NetworkNotFound),
            ("Error: Timeout expired (30 seconds)", ConnectTimeout),
            ("Error: something nobody has seen before", ConnectFailed),
        ]
        for stderr, expected in cases:
            with self.subTest(stderr=stderr):
                answers = self.ok_connect_answers()
                answers[("nmcli", "-w")] = Result(returncode=4, stderr=stderr)
                be, runner = self.backend(answers)
                with self.assertRaises(expected):
                    be.connect("HomeNet", "correct horse", Security.WPA_PSK)
                # A wrong password must not stay behind to autoconnect-loop, or be
                # copied to the installed system.
                self.assertFalse(self.profile.exists())
                self.assertEqual(runner.calls[-1], ["nmcli", "connection", "reload"])

    def test_the_passphrase_never_reaches_an_error_message(self):
        secret = "sup3r-s3cret-passphrase"
        answers = self.ok_connect_answers()
        answers[("nmcli", "-w")] = Result(returncode=4, stderr=f"Error: odd failure involving {secret}")
        be, _ = self.backend(answers)
        with self.assertRaises(ConnectFailed) as caught:
            be.connect("HomeNet", secret, Security.WPA_PSK)
        self.assertNotIn(secret, str(caught.exception))
        self.assertNotIn(secret, repr(caught.exception))

    def test_forget_removes_the_profile_and_reloads(self):
        self.profile.write_text("x")
        be, runner = self.backend()
        be.forget()
        self.assertFalse(self.profile.exists())
        self.assertEqual(runner.calls, [["nmcli", "connection", "reload"]])

    def test_forget_with_nothing_saved_does_nothing(self):
        be, runner = self.backend()
        be.forget()
        self.assertEqual(runner.calls, [])

    def test_connecting_to_another_network_replaces_the_saved_one(self):
        be, _ = self.backend(self.ok_connect_answers())
        be.connect("First", "correct horse", Security.WPA_PSK)
        be.connect("Second", "battery staple", Security.WPA_PSK)
        text = self.profile.read_text(encoding="utf-8")
        self.assertIn("ssid=Second", text)
        self.assertNotIn("First", text)
        self.assertEqual(list(self.profile_dir.iterdir()), [self.profile])


class DefaultRunnerTest(unittest.TestCase):
    def test_runs_a_real_command_and_captures_its_output(self):
        result = wifi.run_command(["echo", "hello"])
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "hello"))

    def test_commands_run_in_the_c_locale(self):
        # nmcli translates the words this module reads (`enabled`, `missing`, the
        # failure messages); a non-English session would otherwise break both the
        # radio state and the wrong-password / not-found mapping.
        result = wifi.run_command(["sh", "-c", "printf %s \"$LC_ALL\""])
        self.assertEqual(result.stdout, "C")

    def test_a_missing_command_is_a_failed_result_not_a_crash(self):
        result = wifi.run_command(["definitely-not-a-command-xyz"])
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
