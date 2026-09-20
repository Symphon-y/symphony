import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from installer.wifi import RadioState
from installer.wifi_diagnostics import collect, status_message


class FakeSys:
    """A throwaway /sys, so nothing here depends on the machine running the tests."""

    def __init__(self):
        self._dir = tempfile.TemporaryDirectory()
        self.root = Path(self._dir.name)

    def cleanup(self):
        self._dir.cleanup()

    def write(self, rel, text):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text + "\n")

    def link(self, rel, target):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(target)

    def rfkill(self, index, name, kind, hard, soft):
        base = f"class/rfkill/rfkill{index}"
        self.write(f"{base}/name", name)
        self.write(f"{base}/type", kind)
        self.write(f"{base}/hard", str(int(hard)))
        self.write(f"{base}/soft", str(int(soft)))

    def pci(self, slot, cls, vendor, device, driver=None):
        base = f"bus/pci/devices/{slot}"
        self.write(f"{base}/class", cls)
        self.write(f"{base}/vendor", vendor)
        self.write(f"{base}/device", device)
        if driver:
            self.link(f"{base}/driver", f"../../../bus/pci/drivers/{driver}")

    def phy(self, name, driver):
        self.link(f"class/ieee80211/{name}/device/driver", f"../../../../bus/pci/drivers/{driver}")

    def machine(self, vendor, product):
        self.write("class/dmi/id/sys_vendor", vendor)
        self.write("class/dmi/id/product_name", product)


class DiagnosticsTest(unittest.TestCase):
    def setUp(self):
        self.sys = FakeSys()
        self.addCleanup(self.sys.cleanup)

    def diagnose(self):
        return collect(self.sys.root)

    def text(self):
        return "\n".join(self.diagnose().lines())

    def test_a_hard_blocked_wifi_device_is_named_as_the_blocker_with_its_driver(self):
        self.sys.rfkill(0, "phy0", "wlan", hard=True, soft=False)
        self.sys.phy("phy0", "ath9k")
        self.sys.pci("0000:03:00.0", "0x028000", "0x168c", "0x0034", driver="ath9k")

        blockers = self.diagnose().blockers()
        self.assertEqual([(b.name, b.driver) for b in blockers], [("phy0", "ath9k")])
        text = self.text()
        self.assertIn("phy0", text)
        self.assertIn("ath9k", text)
        self.assertIn("hard-blocked", text)

    def test_a_soft_block_is_not_a_blocker_only_a_hard_one_is(self):
        self.sys.rfkill(0, "phy0", "wlan", hard=False, soft=True)
        self.assertEqual(self.diagnose().blockers(), [])
        self.assertIn("soft-blocked", self.text())

    def test_an_unblocked_device_is_reported_as_such(self):
        self.sys.rfkill(0, "phy0", "wlan", hard=False, soft=False)
        self.assertEqual(self.diagnose().blockers(), [])
        self.assertIn("not blocked", self.text())

    def test_a_blocked_bluetooth_radio_is_not_a_wifi_blocker(self):
        # The Killer 1202 is Wi-Fi and Bluetooth on one card; only wlan matters here.
        self.sys.rfkill(0, "hci0", "bluetooth", hard=True, soft=False)
        self.sys.rfkill(1, "phy0", "wlan", hard=False, soft=False)
        self.assertEqual(self.diagnose().blockers(), [])

    def test_a_platform_switch_with_no_driver_link_is_still_named(self):
        self.sys.rfkill(0, "dell-wifi", "wlan", hard=True, soft=False)
        blockers = self.diagnose().blockers()
        self.assertEqual([(b.name, b.driver) for b in blockers], [("dell-wifi", "")])

    def test_a_wireless_pci_adapter_is_listed_with_its_ids_and_whether_a_driver_bound(self):
        self.sys.pci("0000:03:00.0", "0x028000", "0x168c", "0x0034", driver="ath9k")
        self.assertIn("168c:0034", self.text())
        self.assertIn("ath9k", self.text())

    def test_an_adapter_with_no_driver_bound_says_so(self):
        self.sys.pci("0000:03:00.0", "0x028000", "0x168c", "0x0034")
        self.assertIn("no driver bound", self.text())

    def test_wired_network_controllers_are_not_wifi_adapters(self):
        self.sys.pci("0000:04:00.0", "0x020000", "0x10ec", "0x8168", driver="r8169")
        text = self.text()
        self.assertNotIn("10ec:8168", text)
        self.assertIn("No Wi-Fi adapter", text)

    def test_wireless_interfaces_are_listed(self):
        (self.sys.root / "class/net/wlan0/wireless").mkdir(parents=True)
        (self.sys.root / "class/net/eth0").mkdir(parents=True)
        self.assertEqual(self.diagnose().wireless_interfaces, ["wlan0"])
        self.assertIn("wlan0", self.text())

    def test_the_machine_is_named(self):
        self.sys.machine("Alienware", "Alienware 14")
        self.assertIn("Alienware Alienware 14", self.text())

    def test_an_empty_tree_reports_that_nothing_was_found_without_failing(self):
        text = self.text()
        self.assertIn("No Wi-Fi adapter", text)
        self.assertIn("No rfkill", text)
        self.assertIn("none", text.lower())
        self.assertEqual(self.diagnose().blockers(), [])

    def test_a_device_with_unreadable_files_is_skipped_not_a_crash(self):
        (self.sys.root / "class/rfkill/rfkill0").mkdir(parents=True)  # no files inside
        self.assertEqual(self.diagnose().blockers(), [])


class StatusMessageTest(unittest.TestCase):
    """What the Wi-Fi page tells the user for each radio state -- specific enough
    to act on, and never a claim the facts don't support."""

    def setUp(self):
        self.sys = FakeSys()
        self.addCleanup(self.sys.cleanup)

    def message(self, radio):
        return status_message(radio, collect(self.sys.root))

    def test_nothing_to_say_when_the_radio_is_on(self):
        self.assertIsNone(self.message(RadioState.ON))

    def test_a_hard_block_names_the_device_and_what_to_try(self):
        self.sys.rfkill(0, "phy0", "wlan", hard=True, soft=False)
        self.sys.phy("phy0", "ath9k")
        message = self.message(RadioState.HARD_BLOCKED)
        self.assertIn("phy0 (ath9k)", message)
        self.assertIn("wireless switch", message)
        self.assertIn("BIOS", message)

    def test_a_hard_block_with_no_named_blocker_still_reads_sensibly(self):
        self.assertIn("hardware switch", self.message(RadioState.HARD_BLOCKED))

    def test_no_adapter_at_all_points_at_the_bios_and_the_key_not_a_switch(self):
        message = self.message(RadioState.NO_ADAPTER)
        self.assertIn("No Wi-Fi adapter", message)
        self.assertIn("BIOS", message)
        self.assertNotIn("hardware switch", message)

    def test_an_adapter_the_kernel_can_see_but_no_driver_owns_says_so(self):
        self.sys.pci("0000:03:00.0", "0x028000", "0x168c", "0x0034")
        message = self.message(RadioState.NO_ADAPTER)
        self.assertIn("168c:0034", message)
        self.assertIn("no driver", message)

    def test_an_adapter_with_a_driver_that_networkmanager_still_cannot_see(self):
        self.sys.pci("0000:03:00.0", "0x028000", "0x168c", "0x0034", driver="ath9k")
        message = self.message(RadioState.NO_ADAPTER)
        self.assertIn("ath9k", message)
        self.assertNotIn("No Wi-Fi adapter", message)

    def test_a_soft_block_is_just_off(self):
        self.assertEqual(self.message(RadioState.SOFT_BLOCKED), "Wi-Fi is turned off.")

    def test_an_unreadable_state_says_it_could_not_tell(self):
        self.assertIn("Could not read", self.message(RadioState.UNKNOWN))


if __name__ == "__main__":
    unittest.main()
