import dataclasses
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from installer.state import Answers


class VarsFileContentTest(unittest.TestCase):
    def test_never_includes_either_password(self):
        answers = Answers(user_password="hunter2", luks_passphrase="correcthorse")
        content = answers.vars_file_content()
        self.assertNotIn("hunter2", content)
        self.assertNotIn("correcthorse", content)

    def test_includes_every_other_field(self):
        answers = Answers(
            disk="/dev/nvme0n1",
            hostname="alienware",
            username="travis",
            timezone="America/Chicago",
            locale="en_US.UTF-8 UTF-8",
            keymap="us",
            swap_size="16G",
        )
        content = answers.vars_file_content()
        self.assertEqual(
            content,
            "DISK=/dev/nvme0n1\n"
            "HOST=alienware\n"
            "USERNAME=travis\n"
            "TZONE=America/Chicago\n"
            "LOCALE=en_US.UTF-8 UTF-8\n"
            "KEYMAP=us\n"
            "SWAP_SIZE=16G\n"
            "GIT_NAME=''\n"
            "GIT_EMAIL=''\n",
        )

    def test_shell_quotes_a_git_name_with_a_space(self):
        # The vars file is `source`d as bash -- an unquoted value with a
        # space breaks it (Phase 16).
        answers = Answers(git_name="Alice Example", git_email="alice@users.noreply.github.com")
        content = answers.vars_file_content()
        self.assertIn("GIT_NAME='Alice Example'\n", content)
        self.assertIn("GIT_EMAIL=alice@users.noreply.github.com\n", content)


class WifiAnswerTest(unittest.TestCase):
    def test_the_wifi_network_name_is_display_only_and_never_in_the_vars_file(self):
        # The Wi-Fi connection is made live, on its page, and reaches the installed
        # system as a NetworkManager connection file (install/configure-base-system),
        # not through the vars file -- this field only lets the Review page show it.
        content = Answers(wifi_ssid="HomeNet").vars_file_content()
        self.assertNotIn("HomeNet", content)
        self.assertNotIn("WIFI", content.upper())

    def test_wifi_is_skipped_by_default(self):
        self.assertEqual(Answers().wifi_ssid, "")

    def test_no_field_can_hold_a_wifi_password(self):
        names = {f.name for f in dataclasses.fields(Answers)}
        self.assertEqual({n for n in names if "psk" in n or ("wifi" in n and "pass" in n)}, set())


if __name__ == "__main__":
    unittest.main()
