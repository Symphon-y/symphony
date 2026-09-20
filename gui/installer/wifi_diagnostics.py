"""What the machine itself says about its Wi-Fi radio (Phase 17), read from sysfs.

Exists because "Wi-Fi is blocked" or "there is no Wi-Fi" tells the user nothing they
can act on, and the live installer has no terminal to look for themselves (`cage`
has no VT switching, D-0066). So the Wi-Fi page shows these facts: which rfkill
device is blocking the radio and which driver owns it, whether a Wi-Fi adapter is on
the PCI bus at all and whether a driver bound to it, and which wireless interfaces
exist. That separates the cases that need different fixes -- a hardware or BIOS
switch holding a present adapter off, an adapter the OS cannot see, and an adapter
with no driver.

sysfs is read through an injectable root, so the tests use a throwaway tree instead
of the machine running them. Anything unreadable is skipped, never an error.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from .wifi import RadioState

DEFAULT_SYS = Path("/sys")

# PCI class 0x0280: "network controller, other" -- how Wi-Fi cards enumerate. Wired
# controllers are 0x0200 and are not Wi-Fi adapters.
_WIRELESS_PCI_CLASS = "0x0280"


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _driver_name(link: Path) -> str:
    """The name of the driver a `.../driver` symlink points at, or ''."""
    try:
        return os.path.basename(os.readlink(link))
    except OSError:
        return ""


@dataclass(frozen=True)
class RfkillDevice:
    name: str
    kind: str
    hard: bool
    soft: bool
    driver: str

    @property
    def state(self) -> str:
        if self.hard:
            return "hard-blocked"
        return "soft-blocked" if self.soft else "not blocked"


@dataclass(frozen=True)
class PciAdapter:
    ids: str  # vendor:device, e.g. 168c:0034
    driver: str


@dataclass(frozen=True)
class Diagnostics:
    machine: str
    rfkill: list[RfkillDevice]
    wireless_interfaces: list[str]
    pci_adapters: list[PciAdapter]

    def blockers(self) -> list[RfkillDevice]:
        """The Wi-Fi rfkill devices whose hardware switch is holding the radio off.
        (A hard block cannot be cleared from software; a soft one can.)"""
        return [device for device in self.rfkill if device.kind == "wlan" and device.hard]

    def lines(self) -> list[str]:
        out = [f"Machine: {self.machine or 'unknown'}"]
        if self.pci_adapters:
            for adapter in self.pci_adapters:
                driver = f"driver {adapter.driver}" if adapter.driver else "no driver bound"
                out.append(f"Wi-Fi adapter: {adapter.ids} ({driver})")
        else:
            out.append("No Wi-Fi adapter found on the PCI bus.")
        out.append(f"Wireless interfaces: {', '.join(self.wireless_interfaces) or 'none'}")
        if self.rfkill:
            for device in self.rfkill:
                driver = f", driver {device.driver}" if device.driver else ""
                out.append(f"rfkill {device.name} ({device.kind}{driver}): {device.state}")
        else:
            out.append("No rfkill devices registered.")
        return out


def collect(sys_root: Path | str = DEFAULT_SYS) -> Diagnostics:
    root = Path(sys_root)

    rfkill: list[RfkillDevice] = []
    for directory in sorted((root / "class/rfkill").glob("rfkill*")):
        name = _read(directory / "name")
        if not name:
            continue
        rfkill.append(
            RfkillDevice(
                name=name,
                kind=_read(directory / "type"),
                hard=_read(directory / "hard") == "1",
                soft=_read(directory / "soft") == "1",
                # A wireless PHY's rfkill shares its name with the PHY, whose device
                # is the PCI adapter; platform switches (dell-wifi, ...) have none.
                driver=_driver_name(root / "class/ieee80211" / name / "device" / "driver"),
            )
        )

    pci: list[PciAdapter] = []
    for directory in sorted((root / "bus/pci/devices").glob("*")):
        if not _read(directory / "class").startswith(_WIRELESS_PCI_CLASS):
            continue
        vendor = _read(directory / "vendor").removeprefix("0x")
        device = _read(directory / "device").removeprefix("0x")
        pci.append(PciAdapter(f"{vendor}:{device}", _driver_name(directory / "driver")))

    interfaces = sorted(
        entry.name for entry in (root / "class/net").glob("*") if (entry / "wireless").is_dir()
    )

    vendor = _read(root / "class/dmi/id/sys_vendor")
    product = _read(root / "class/dmi/id/product_name")
    return Diagnostics(
        machine=" ".join(part for part in (vendor, product) if part),
        rfkill=rfkill,
        wireless_interfaces=interfaces,
        pci_adapters=pci,
    )


def status_message(radio: RadioState, diagnostics: Diagnostics) -> str | None:
    """What to tell the user about the radio, or None when it is on. Specific
    enough to act on (which device, what to try) and never a claim the facts do
    not support: a hardware switch is only blamed when NetworkManager reports a
    hard block, and a missing adapter is reported as missing, not as switched off."""
    if radio is RadioState.ON:
        return None
    if radio is RadioState.SOFT_BLOCKED:
        return "Wi-Fi is turned off."
    if radio is RadioState.UNKNOWN:
        return "Could not read the Wi-Fi state -- try Refresh."

    if radio is RadioState.HARD_BLOCKED:
        blockers = diagnostics.blockers()
        if not blockers:
            return "Wi-Fi is switched off by a hardware switch."
        names = ", ".join(f"{b.name} ({b.driver})" if b.driver else b.name for b in blockers)
        return (
            f"Wi-Fi is switched off by the laptop's wireless switch ({names}). "
            "Try the Wi-Fi key or switch; on some laptops it is also a setting in the BIOS."
        )

    # NO_ADAPTER: NetworkManager knows of no Wi-Fi hardware.
    adapters = diagnostics.pci_adapters
    unbound = [a for a in adapters if not a.driver]
    if unbound:
        ids = ", ".join(a.ids for a in unbound)
        return f"A Wi-Fi adapter ({ids}) was found, but no driver is using it."
    if adapters:
        found = ", ".join(f"{a.ids}, driver {a.driver}" for a in adapters)
        return f"A Wi-Fi adapter ({found}) was found, but the system can't use it. Check the wireless settings in the BIOS."
    return (
        "No Wi-Fi adapter was found. If this laptop has one, it may be switched off "
        "in the BIOS (Wireless settings) or by its wireless key."
    )


if __name__ == "__main__":
    # `python3 -m installer.wifi_diagnostics` (from gui/): the same facts the
    # installer's Wi-Fi page shows under Details, for scripts/system-report.
    print("\n".join(collect().lines()))
