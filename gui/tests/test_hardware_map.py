import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from installer.hardware_map import load_map, parse_map


class ParseMapTest(unittest.TestCase):
    def test_reads_the_pci_id_and_the_note(self):
        text = "14e4:43b1  broadcom-wl  # Broadcom BCM4352 802.11ac\n"
        self.assertEqual(parse_map(text), {"14e4:43b1": "Broadcom BCM4352 802.11ac"})

    def test_ignores_comments_and_blank_lines(self):
        text = "# a header\n\n   \n14e4:43b1  broadcom-wl  # Note\n"
        self.assertEqual(list(parse_map(text)), ["14e4:43b1"])

    def test_an_entry_without_a_note_has_an_empty_one(self):
        self.assertEqual(parse_map("14e4:43b1  broadcom-wl\n"), {"14e4:43b1": ""})

    def test_ids_are_lowercased_like_sysfs_prints_them(self):
        self.assertIn("14e4:43b1", parse_map("14E4:43B1  broadcom-wl  # x\n"))

    def test_malformed_lines_are_skipped_not_fatal(self):
        # scripts/hwpkglist is the strict reader (it fails on a bad line); this one only
        # decorates a message, so it must never take the installer down.
        text = "not-an-id  foo\n14e4:43b1\n14e4:43b1  broadcom-wl  # ok\n"
        self.assertEqual(parse_map(text), {"14e4:43b1": "ok"})


class LoadMapTest(unittest.TestCase):
    def test_a_missing_file_is_an_empty_map(self):
        self.assertEqual(load_map(Path("/no/such/hardware.txt")), {})

    def test_reads_a_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "hardware.txt"
            path.write_text("14e4:43b1  broadcom-wl  # Broadcom BCM4352\n")
            self.assertEqual(load_map(path), {"14e4:43b1": "Broadcom BCM4352"})

    def test_the_repos_own_map_knows_the_broadcom_bcm4352(self):
        # The adapter found on the Alienware 14: the installer page tells the user what
        # it needs from this map, and the installer adds its packages from the same file.
        self.assertIn("BCM4352", load_map().get("14e4:43b1", ""))


if __name__ == "__main__":
    unittest.main()
