"""system/hardware.txt, read for the installer's Wi-Fi page (Phase 17; grammar of Phase 19).

The file maps hardware identity to what it needs. This reader wants one thing from it:
for a PCI device the page found, a short note naming it -- the entry's own trailing
comment, or the comment line just above it. scripts/hwmatch is the strict reader that
acts on the file; this one only decorates a message, so it is forgiving: a missing file
or a malformed line is skipped, never an error that could take the installer down.
"""

from __future__ import annotations

import re
from pathlib import Path

# gui/installer/hardware_map.py -> the repo root, which on the live ISO is /root/symphony.
MAP_PATH = Path(__file__).resolve().parents[2] / "system" / "hardware.txt"

_PCI_KEY = re.compile(r"^pci:([0-9a-f]{4}:[0-9a-f]{4})$")


def parse_map(text: str) -> dict[str, str]:
    """{pci id: note}. Entries are `pci:<vendor:device>  <value>...  # note`; a note may
    also be the comment line directly above the entry."""
    entries: dict[str, str] = {}
    previous_comment = ""
    for raw in text.splitlines():
        body, _, note = raw.partition("#")
        fields = body.split()
        if not fields:
            previous_comment = note.strip() if raw.lstrip().startswith("#") else ""
            continue
        match = _PCI_KEY.match(fields[0].lower())
        if match and len(fields) >= 2:
            entries[match.group(1)] = note.strip() or previous_comment
        previous_comment = ""
    return entries


def load_map(path: Path = MAP_PATH) -> dict[str, str]:
    try:
        return parse_map(path.read_text(encoding="utf-8"))
    except OSError:
        return {}
