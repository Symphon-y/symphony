import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from installer.runner import _secret_pipe_fd


class SecretPipeFdTest(unittest.TestCase):
    def test_read_end_yields_the_secret_plus_newline(self):
        r = _secret_pipe_fd("correcthorsebatterystaple")
        try:
            self.assertEqual(os.read(r, 4096), b"correcthorsebatterystaple\n")
        finally:
            os.close(r)

    def test_write_end_is_already_closed(self):
        # A closed write end is what makes the read above return EOF
        # after one line, instead of blocking forever -- this is the
        # actual property install-base-system's `read -r <&9` depends on.
        r = _secret_pipe_fd("x")
        try:
            os.read(r, 4096)
            self.assertEqual(os.read(r, 4096), b"")
        finally:
            os.close(r)


if __name__ == "__main__":
    unittest.main()
