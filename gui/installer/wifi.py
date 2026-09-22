"""Wi-Fi for the installer -- everything except the GTK page (Phase 17).

The live ISO runs NetworkManager, the same stack as the installed system
(D-0014). This module lists networks, joins one, and leaves behind a plain
NetworkManager connection file that install/configure-base-system carries to the
new system as-is -- so nothing here has to know how the hand-off works, and the
hand-off does not know this file format.

Two rules shape it:

* The passphrase never appears in a command line (argv is world-readable in
  /proc), a log line or an exception message. So it is not passed to
  `nmcli ... password X`; the connection file is written from here (mode 0600) and
  NetworkManager is told to reload it.
* keyfile_for() is the one place that knows the file format. Its escaping was
  verified against a real NetworkManager: written raw, a backslash in an SSID
  became a space, a password with backslashes came back empty, and leading spaces
  were silently trimmed.

Every external command goes through an injectable runner, so all of it is unit
tested without a radio (gui/tests/test_wifi.py).
"""

from __future__ import annotations

import os
import subprocess
import uuid as _uuid
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Callable

DEFAULT_PROFILE_DIR = Path("/etc/NetworkManager/system-connections")
# One fixed file: the installer manages a single Wi-Fi connection, and joining
# another network replaces it. Fixed also means no file name is ever built from a
# user-typed SSID.
PROFILE_NAME = "symphony-wifi.nmconnection"


class Security(Enum):
    OPEN = "open"
    WPA_PSK = "wpa-psk"
    SAE = "sae"
    ENTERPRISE = "enterprise"
    UNSUPPORTED = "unsupported"


class RadioState(Enum):
    ON = "on"
    SOFT_BLOCKED = "soft-blocked"
    HARD_BLOCKED = "hard-blocked"
    #: NetworkManager knows of no Wi-Fi hardware or killswitch at all (nmcli prints
    #: `missing`, NetworkManager >= 1.34): no adapter is visible to the OS. Not the
    #: same as a hardware switch being off, and not fixable by one.
    NO_ADAPTER = "no-adapter"
    UNKNOWN = "unknown"


class WifiError(Exception):
    """Base for everything this module raises on purpose."""


class InvalidSsid(WifiError, ValueError):
    pass


class InvalidPassphrase(WifiError, ValueError):
    pass


class UnsupportedNetwork(WifiError):
    pass


class WrongPassword(WifiError):
    pass


class NetworkNotFound(WifiError):
    pass


class ConnectTimeout(WifiError):
    pass


class ConnectFailed(WifiError):
    pass


@dataclass(frozen=True)
class AccessPoint:
    ssid: str
    signal: int
    security: Security
    in_use: bool = False

    @property
    def supported(self) -> bool:
        """Joinable from the installer. Enterprise (802.1X), WEP and OWE are not:
        nm-connection-editor handles them after install."""
        return self.security in (Security.OPEN, Security.WPA_PSK, Security.SAE)


# --- reading a scan --------------------------------------------------------------


def _split_terse(line: str) -> list[str]:
    """Split one line of `nmcli -t` output: fields are separated by ':', and a
    literal ':' or '\\' inside a field is backslash-escaped."""
    fields: list[str] = []
    current: list[str] = []
    i = 0
    while i < len(line):
        char = line[i]
        if char == "\\" and i + 1 < len(line):
            current.append(line[i + 1])
            i += 2
            continue
        if char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
        i += 1
    fields.append("".join(current))
    return fields


def classify_security(field: str) -> Security:
    """Map nmcli's SECURITY column ('WPA2', 'WPA2 WPA3', 'WPA2 802.1X', '--', ...)
    to what the installer can do with the network."""
    tokens = set(field.split())
    if not tokens or tokens == {"--"}:
        return Security.OPEN
    if "802.1X" in tokens:
        return Security.ENTERPRISE
    if tokens & {"WPA1", "WPA2"}:
        # Includes WPA2/WPA3 transition mode, which accepts a plain WPA2 handshake.
        return Security.WPA_PSK
    if "WPA3" in tokens:
        return Security.SAE
    return Security.UNSUPPORTED


def parse_scan(output: str) -> list[AccessPoint]:
    """Parse `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list`: one entry
    per SSID (the strongest access point; in-use if any of them is), hidden
    networks with no SSID dropped, strongest first."""
    best: dict[str, AccessPoint] = {}
    for line in output.splitlines():
        fields = _split_terse(line)
        if len(fields) != 4:
            continue
        in_use, ssid, signal_text, security_text = fields
        if not ssid:
            continue
        try:
            signal = int(signal_text)
        except ValueError:
            continue
        found = AccessPoint(ssid, signal, classify_security(security_text), in_use.strip() == "*")
        current = best.get(ssid)
        if current is None:
            best[ssid] = found
            continue
        stronger = found if found.signal > current.signal else current
        best[ssid] = AccessPoint(
            stronger.ssid,
            stronger.signal,
            stronger.security,
            found.in_use or current.in_use,
        )
    return sorted(best.values(), key=lambda ap: (-ap.signal, ap.ssid))


# --- validation ------------------------------------------------------------------


def validate_ssid(ssid: str) -> None:
    """An SSID is 1-32 *bytes*."""
    if not 1 <= len(ssid.encode("utf-8")) <= 32:
        raise InvalidSsid("A network name is 1 to 32 bytes long.")


def validate_passphrase(psk: str, security: Security) -> None:
    """WPA passphrases are 8-63 printable ASCII characters, or exactly 64 hex
    digits -- the rule NetworkManager itself enforces. Open networks take none."""
    if security is Security.OPEN:
        return
    is_hex_key = len(psk) == 64 and all(c in "0123456789abcdefABCDEF" for c in psk)
    is_passphrase = 8 <= len(psk) <= 63 and all(0x20 <= ord(c) <= 0x7E for c in psk)
    if not (is_hex_key or is_passphrase):
        raise InvalidPassphrase("A Wi-Fi password is 8 to 63 characters (letters, digits, punctuation).")


# --- the connection file ---------------------------------------------------------


def _escape(value: str) -> str:
    """Escape a value the way NetworkManager's key-file reader needs to get it back
    unchanged: '\\' -> '\\\\', tab/newline/CR -> \\t \\n \\r, and a leading or
    trailing space -> \\s (otherwise it is trimmed). Nothing else needs it: ';' '#'
    '"' '=' '[' and Unicode all round-trip as they are."""
    escaped = (
        value.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")
    )
    if escaped.startswith(" "):
        escaped = "\\s" + escaped[1:]
    if escaped.endswith(" "):
        escaped = escaped[:-1] + "\\s"
    return escaped


def keyfile_for(
    ssid: str,
    psk: str,
    security: Security,
    hidden: bool = False,
    uuid: str | None = None,
) -> str:
    """The NetworkManager connection file for one Wi-Fi network.

    The secret is stored in the file itself (psk-flags=0), because a bare Hyprland
    session has no keyring agent to hand it back at boot. There is deliberately no
    `permissions=` line: that would tie the connection to the live session's user.
    """
    if security not in (Security.OPEN, Security.WPA_PSK, Security.SAE):
        raise UnsupportedNetwork("This kind of network can't be set up here.")

    lines = [
        "[connection]",
        f"id={_escape(ssid)}",
        f"uuid={uuid or _uuid.uuid4()}",
        "type=wifi",
        "autoconnect=true",
        "",
        "[wifi]",
        "mode=infrastructure",
        f"ssid={_escape(ssid)}",
    ]
    if hidden:
        lines.append("hidden=true")
    if security is not Security.OPEN:
        lines += [
            "",
            "[wifi-security]",
            f"key-mgmt={'sae' if security is Security.SAE else 'wpa-psk'}",
            "psk-flags=0",
            f"psk={_escape(psk)}",
        ]
    lines += ["", "[ipv4]", "method=auto", "", "[ipv6]", "method=auto"]
    return "\n".join(lines) + "\n"


# --- talking to NetworkManager ---------------------------------------------------

Runner = Callable[[list[str]], "subprocess.CompletedProcess[str]"]


def run_command(argv: list[str]) -> "subprocess.CompletedProcess[str]":
    """Run a command, capturing text, in the C locale: nmcli translates the words
    this module reads (`enabled`, `missing`, its failure messages), so a non-English
    session would break both the radio state and the error mapping. A missing
    program is a failed result, not a crash -- same shape as system_info.py."""
    try:
        return subprocess.run(
            argv,
            capture_output=True,
            text=True,
            check=False,
            env={**os.environ, "LC_ALL": "C"},
        )
    except OSError as error:
        return subprocess.CompletedProcess(argv, 127, "", str(error))


def _scrub(text: str, secret: str) -> str:
    return text.replace(secret, "***") if secret else text


def _failure(raw: str, psk: str) -> WifiError:
    """Name an `nmcli connection up` failure. Only the wording of what nmcli said
    is used to choose; the message shown never contains the passphrase."""
    text = _scrub(raw.strip(), psk)
    low = text.lower()
    if "secrets were required" in low or "no secrets" in low:
        return WrongPassword("The password was not accepted.")
    if "could not be found" in low or "(53)" in low:
        return NetworkNotFound("That network could not be found.")
    if "timeout expired" in low or "timed out" in low:
        return ConnectTimeout("Connecting took too long.")
    return ConnectFailed(text or "Could not connect.")


class WifiBackend:
    """The installer's view of NetworkManager."""

    def __init__(
        self,
        run: Runner = run_command,
        profile_dir: Path | str = DEFAULT_PROFILE_DIR,
        new_uuid: Callable[[], str] = lambda: str(_uuid.uuid4()),
    ) -> None:
        self._run = run
        self._dir = Path(profile_dir)
        self._new_uuid = new_uuid

    @property
    def _profile(self) -> Path:
        return self._dir / PROFILE_NAME

    # -- reading state

    def scan(self, rescan: bool = False) -> list[AccessPoint]:
        """The networks in range. NetworkManager throttles rescans, so a refused
        one falls back to its cached list instead of returning nothing."""
        result = self._list("yes" if rescan else "auto")
        if result.returncode != 0 and rescan:
            result = self._list("no")
        return parse_scan(result.stdout) if result.returncode == 0 else []

    def _list(self, rescan: str):
        return self._run(
            [
                "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
                "device", "wifi", "list", "--rescan", rescan,
            ]
        )  # fmt: skip

    def radio_state(self) -> RadioState:
        """The Wi-Fi radio's state, from `nmcli radio`: WIFI-HW is the rfkill
        hardware switch (`enabled` = not blocked, `disabled` = hard-blocked,
        `missing` = no Wi-Fi hardware or killswitch known to NetworkManager) and WIFI
        is the software switch. Only a value we recognise is acted on: anything else
        -- nmcli failing while NetworkManager starts (exit 8), a word we have not
        seen -- is UNKNOWN, never a confident "hardware switch". (This used to treat
        every WIFI-HW that was not `enabled` as a hard block, which reported `missing`
        that way; found on real hardware.)"""
        result = self._run(["nmcli", "-t", "-f", "WIFI-HW,WIFI", "radio"])
        fields = result.stdout.strip().split(":")
        if result.returncode != 0 or len(fields) != 2:
            return RadioState.UNKNOWN
        hardware, software = fields
        if hardware == "missing":
            return RadioState.NO_ADAPTER
        if hardware not in ("enabled", "disabled") or software not in ("enabled", "disabled"):
            return RadioState.UNKNOWN
        if hardware == "disabled":
            return RadioState.HARD_BLOCKED
        return RadioState.ON if software == "enabled" else RadioState.SOFT_BLOCKED

    def enable_radio(self) -> None:
        """Clear a soft rfkill block, then turn the radio on (the same recovery
        Omarchy ships as 'restart Wi-Fi')."""
        self._run(["rfkill", "unblock", "wifi"])
        self._run(["nmcli", "radio", "wifi", "on"])

    def ethernet_connected(self) -> bool:
        result = self._run(["nmcli", "-t", "-f", "TYPE,STATE", "device"])
        return "ethernet:connected" in result.stdout.split()

    def is_online(self) -> bool:
        """Connected with a default route. 'connected (site only)' and '(local
        only)' are limited, and do not count."""
        result = self._run(["nmcli", "-t", "-f", "STATE", "general"])
        return result.stdout.strip() == "connected"

    # -- joining a network

    def connect(
        self,
        ssid: str,
        psk: str,
        security: Security,
        hidden: bool = False,
        timeout: int = 30,
    ) -> None:
        """Join a network, or raise a WifiError that says why. On any failure the
        saved connection is removed again: a wrong password must not stay behind
        to retry forever, or be carried to the installed system."""
        validate_ssid(ssid)
        if security not in (Security.OPEN, Security.WPA_PSK, Security.SAE):
            raise UnsupportedNetwork("Use Network settings after install for this kind of network.")
        validate_passphrase(psk, security)

        connection_uuid = self._new_uuid()
        self._write_profile(keyfile_for(ssid, psk, security, hidden, connection_uuid))
        try:
            self._run(["nmcli", "connection", "reload"])
            # A file NetworkManager rejects (mode, ownership, syntax) is ignored
            # silently, so make sure it actually took.
            known = self._run(["nmcli", "-t", "-f", "UUID", "connection", "show"])
            if connection_uuid not in known.stdout.split():
                raise ConnectFailed("NetworkManager did not accept the saved connection.")
            result = self._run(
                ["nmcli", "-w", str(timeout), "connection", "up", "uuid", connection_uuid]
            )
            if result.returncode != 0:
                raise _failure(result.stderr or result.stdout, psk)
        except WifiError:
            self.forget()
            raise

    def forget(self) -> None:
        """Remove the connection this installer saved, if any."""
        try:
            self._profile.unlink()
        except FileNotFoundError:
            return
        self._run(["nmcli", "connection", "reload"])

    def _write_profile(self, text: str) -> None:
        """Write the connection file 0600 whatever the umask, replacing any
        earlier one (and tightening its mode if it was looser)."""
        self._dir.mkdir(parents=True, exist_ok=True)
        flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0)
        fd = os.open(self._profile, flags, 0o600)
        try:
            os.fchmod(fd, 0o600)
        except OSError:
            os.close(fd)
            raise
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
