"""Everything this app reads from the live system itself, rather than
hand-maintaining a duplicate data table (this project's own DRY
convention -- see e.g. profiledef.sh's git-derived file_permissions,
Phase 14). Keymaps/locales/timezones/disks all come from the same
tools/files the bash install scripts already use or would use.
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass


def available_keymaps() -> list[str]:
    """Console keymap names, e.g. 'us', 'de'. Same source
    configure-base-system's target `vconsole.conf` ultimately names."""
    out = subprocess.run(
        ["localectl", "list-keymaps"], capture_output=True, text=True, check=False
    ).stdout
    return sorted(line.strip() for line in out.splitlines() if line.strip())


def available_locales() -> list[str]:
    """Locale names as they appear in /etc/locale.gen, e.g.
    'en_US.UTF-8 UTF-8' -- the exact format configure-base-system's own
    enable_locale()/locale_is_listed() already parse, so this app and
    that script agree on what's valid without a second list to maintain."""
    locales = []
    try:
        with open("/etc/locale.gen", encoding="utf-8") as f:
            for line in f:
                line = line.strip().lstrip("#").strip()
                if line and not line.startswith("#") and " " in line:
                    locales.append(line)
    except OSError:
        pass
    return sorted(set(locales))


def available_timezones() -> list[str]:
    """'Region/City' timezone names, e.g. 'America/Chicago'."""
    out = subprocess.run(
        ["timedatectl", "list-timezones"], capture_output=True, text=True, check=False
    ).stdout
    return [line.strip() for line in out.splitlines() if line.strip()]


@dataclass
class Disk:
    path: str
    size: str
    model: str
    is_installer_media: bool


def _boot_disk_name() -> str:
    """The whole disk the live medium itself is booted from, if it can be
    identified -- mirrors autarchy-install's own boot_disk() exactly, a
    best-effort label, not a hard block."""
    try:
        source = subprocess.run(
            ["findmnt", "-no", "SOURCE", "/run/archiso/bootmnt"],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
        if not source:
            return ""
        return subprocess.run(
            ["lsblk", "-no", "PKNAME", source],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
    except OSError:
        return ""


def available_disks() -> list[Disk]:
    """Every whole disk, labeling the live medium's own disk -- mirrors
    autarchy-install's list_disks()."""
    boot = _boot_disk_name()
    out = subprocess.run(
        ["lsblk", "-dno", "NAME,SIZE,MODEL,TYPE"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout
    disks = []
    for line in out.splitlines():
        parts = line.split()
        if not parts or parts[-1] != "disk":
            continue
        name = parts[0]
        size = parts[1] if len(parts) > 2 else ""
        model = " ".join(parts[2:-1]) if len(parts) > 3 else ""
        disks.append(Disk(f"/dev/{name}", size, model, name == boot))
    return disks
