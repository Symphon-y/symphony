import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from installer.wifi import (
    NetworkNotFound,
    RadioState,
    Security,
    WifiBackend,
    WrongPassword,
)
from installer.wifi_demo import demo_backend


class DemoBackendTest(unittest.TestCase):
    """--dry-run has no radio, so the installer's Wi-Fi page runs against this. It is
    the real WifiBackend over canned nmcli answers, not a second implementation --
    the page exercises the same parsing, profile writing and error mapping as on
    hardware, and never touches /etc/NetworkManager."""

    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.backend = demo_backend(profile_dir=self._dir.name, delay=0)

    def test_it_is_a_real_wifi_backend(self):
        self.assertIsInstance(self.backend, WifiBackend)

    def test_the_scan_offers_a_realistic_mix(self):
        aps = {ap.ssid: ap for ap in self.backend.scan()}
        self.assertGreaterEqual(len(aps), 5)
        self.assertEqual({ap.security for ap in aps.values()} >= {Security.OPEN, Security.WPA_PSK, Security.ENTERPRISE}, True)
        # An SSID that needs unescaping, so the page is seen handling one.
        self.assertIn("Cafe: Free Wi-Fi", aps)
        self.assertEqual(self.backend.scan(), sorted(self.backend.scan(), key=lambda a: (-a.signal, a.ssid)))

    def test_the_radio_is_on_and_there_is_no_ethernet(self):
        self.assertEqual(self.backend.radio_state(), RadioState.ON)
        self.assertFalse(self.backend.ethernet_connected())

    def test_a_good_password_connects_and_leaves_a_private_profile_in_the_demo_directory(self):
        self.backend.connect("HomeNet", "correct horse", Security.WPA_PSK)
        profile = Path(self._dir.name) / "autarchy-wifi.nmconnection"
        self.assertTrue(profile.exists())
        self.assertIn("ssid=HomeNet", profile.read_text(encoding="utf-8"))

    def test_a_network_that_rejects_the_password_fails_the_way_hardware_would(self):
        with self.assertRaises(WrongPassword):
            self.backend.connect("Wrong Password Net", "correct horse", Security.WPA_PSK)
        self.assertEqual(list(Path(self._dir.name).iterdir()), [])

    def test_a_vanished_network_fails_the_way_hardware_would(self):
        with self.assertRaises(NetworkNotFound):
            self.backend.connect("Out Of Range", "correct horse", Security.WPA_PSK)


if __name__ == "__main__":
    unittest.main()
