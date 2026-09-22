"""A Wi-Fi backend for --dry-run, where there is no radio (Phase 17).

Not a second implementation: it is the real WifiBackend running over canned
`nmcli` answers, so the installer's Wi-Fi page exercises the same scan parsing,
profile writing and error mapping as on hardware. Connections are written to a
throwaway directory, never /etc/NetworkManager.
"""

from __future__ import annotations

import re
import subprocess
import tempfile
import time
from pathlib import Path

from .wifi import PROFILE_NAME, WifiBackend

# What `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list` prints: a spread
# of security types, an SSID containing ':' (escaped as nmcli does), a backslash,
# a duplicate access point, and a hidden network with no name.
_SCAN = "\n".join(
    [
        ":HomeNet:82:WPA2",
        ":Neighbour 5G:74:WPA2 WPA3",
        ":Office (802.1X):66:WPA2 802.1X",
        ":Wrong Password Net:61:WPA2",
        r":Cafe\: Free Wi-Fi:58:--",
        r":Back\slash Net:47:WPA3",
        ":HomeNet:55:WPA2",
        ":Out Of Range:22:WPA2",
        "::40:WPA2",
    ]
)


def _result(argv, returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(argv, returncode, stdout, stderr)


class _DemoNetworkManager:
    def __init__(self, profile: Path, delay: float, radio: str = "enabled:enabled") -> None:
        self._profile = profile
        self._delay = delay
        self._connected = False
        # What `nmcli -t -f WIFI-HW,WIFI radio` prints: enabled:enabled, enabled:disabled
        # (soft-blocked), disabled:enabled (hard-blocked), missing:enabled (no adapter).
        self.radio = radio

    def _saved(self, key: str) -> str:
        try:
            match = re.search(rf"^{key}=(.*)$", self._profile.read_text(encoding="utf-8"), re.M)
        except OSError:
            return ""
        return match.group(1) if match else ""

    def __call__(self, argv):
        if argv[:2] == ["nmcli", "-t"]:
            fields = argv[argv.index("-f") + 1] if "-f" in argv else ""
            if fields == "IN-USE,SSID,SIGNAL,SECURITY":
                return _result(argv, stdout=_SCAN + "\n")
            if fields == "WIFI-HW,WIFI":
                return _result(argv, stdout=self.radio + "\n")
            if fields == "TYPE,STATE":
                return _result(argv, stdout="wifi:disconnected\n")
            if fields == "STATE":
                return _result(argv, stdout="connected\n" if self._connected else "disconnected\n")
            if fields == "UUID":
                return _result(argv, stdout=self._saved("uuid") + "\n")
        if argv[:1] == ["nmcli"] and "up" in argv:
            time.sleep(self._delay)
            ssid = self._saved("ssid")
            if ssid == "Wrong Password Net":
                return _result(
                    argv, 4, stderr="Error: Connection activation failed: (7) Secrets were required, but not provided."
                )
            if ssid == "Out Of Range":
                return _result(
                    argv, 4, stderr="Error: Connection activation failed: (53) The Wi-Fi network could not be found."
                )
            self._connected = True
        return _result(argv)


class _DemoBackend(WifiBackend):
    """The real WifiBackend, plus a hook to change the simulated radio state --
    the user pressing the Wi-Fi key, or fixing a BIOS setting, while the page is open."""

    def set_demo_radio(self, radio: str) -> None:
        self._run.radio = radio


def demo_backend(
    profile_dir: str | Path | None = None, delay: float = 1.2, radio: str = "enabled:enabled"
) -> _DemoBackend:
    """A WifiBackend over canned answers. `delay` is how long a join takes, so the
    page's spinner can be seen; `radio` is the simulated `nmcli radio` state."""
    directory = Path(profile_dir or tempfile.mkdtemp(prefix="symphony-wifi-demo-"))
    return _DemoBackend(run=_DemoNetworkManager(directory / PROFILE_NAME, delay, radio), profile_dir=directory)
