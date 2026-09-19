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


if __name__ == "__main__":
    unittest.main()
