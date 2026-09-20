"""system/hardware.txt, read for the installer's Wi-Fi page (Phase 17).

The file maps a PCI vendor:device ID to a package list that machine needs (a proprietary
Wi-Fi driver, say) plus a short note naming the device. scripts/hwpkglist is the strict
reader that adds the packages at install time; this one only lets the page say what a
Wi-Fi adapter it found needs, so it is forgiving: a missing file or a malformed line is
skipped, never an error that could take the installer down.
"""

from __future__ import annotations

import re
from pathlib import Path

# gui/installer/hardware_map.py -> the repo root, which on the live ISO is /root/autarchy.
MAP_PATH = Path(__file__).resolve().parents[2] / "system" / "hardware.txt"

_PCI_ID = re.compile(r"^[0-9a-f]{4}:[0-9a-f]{4}$")


def parse_map(text: str) -> dict[str, str]:
    """{pci id: note}. Lines are `<vendor:device>  <list>  # note`."""
    entries: dict[str, str] = {}
    for raw in text.splitlines():
        body, _, note = raw.partition("#")
        fields = body.split()
        if len(fields) != 2:
            continue
        pci_id = fields[0].lower()
        if _PCI_ID.match(pci_id):
            entries[pci_id] = note.strip()
    return entries


def load_map(path: Path = MAP_PATH) -> dict[str, str]:
    try:
        return parse_map(path.read_text(encoding="utf-8"))
    except OSError:
        return {}
