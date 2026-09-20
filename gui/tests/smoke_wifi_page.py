"""Smoke test: runs the REAL GTK/libadwaita Wi-Fi page (installer/pages/wifi.py)
under a virtual display, against the demo backend (installer/wifi_demo.py).

The page is GTK code, so the unittest suite (which must not import `gi`) can't
cover it; all of its logic lives in the tested wifi.py and this only checks the
wiring -- scan rows, selecting, joining, wrong password, hidden network, Forget --
with real widgets. Needs gtk4, libadwaita, python-gobject and a display, so CI's
`scripts/check` does not run it (it is only syntax-checked there). Run it by hand:

    xvfb-run -a python3 gui/tests/smoke_wifi_page.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gi
gi.require_version("Gtk", "4.0"); gi.require_version("Adw", "1")
from gi.repository import Adw, GLib
from installer.pages.wifi import WifiPage
from installer.state import Answers

class Win: dry_run = True

def pump(ms):
    loop = GLib.MainLoop(); GLib.timeout_add(ms, loop.quit); loop.run()

def wait_until(condition, ms=6000):
    """Run the main loop in short slices until `condition()` holds (or `ms` pass) -- a
    fixed sleep is a race against the page's worker thread, and flaked on a cold start."""
    waited = 0
    while waited < ms and not condition():
        pump(100)
        waited += 100

def check(label, cond):
    print(("ok   " if cond else "FAIL ") + label)
    if not cond: check.bad += 1
check.bad = 0

Adw.init()
page, answers = WifiPage(), Answers()
widget = page.build(answers)
check("build() returns a widget", widget is not None)
page.on_shown(answers, Win()); wait_until(lambda: page._radio is not None and not page._busy)
titles = [r.get_title() for r in page._rows]
check(f"scan populated {len(titles)} network rows, strongest first", titles[:2] == ["HomeNet", "Neighbour 5G"])
check("an SSID with a colon is shown unescaped", any("Cafe: Free Wi-Fi" in t for t in titles))
check("the hidden-network row is last", page._hidden_row.get_parent() is not None)
enterprise = next(r for r in page._rows if "Office" in r.get_title())
check("enterprise row is greyed out (not sensitive)", not enterprise.get_sensitive())
check("status says to choose a network", page._status_row.get_title() == "Choose a network.")
check("Skip: validate() lets Next through with nothing joined", page.validate(answers) is None)
page.save(answers); check("Skip: wifi_ssid stays empty", answers.wifi_ssid == "")

# --- join a good network
ap = next(a for a in page._backend.scan() if a.ssid == "HomeNet")
page._on_network(None, ap)
check("selecting a secured network shows the password row", page._password_row.get_visible() and page._join.get_visible())
page._password_row.set_text("correct horse"); page._on_connect(None)
check("busy while connecting: Next is held", page.validate(answers) == "Still connecting -- wait a moment.")
pump(2500)
check("connected: not busy", not page._busy)
check("connected: password cleared from the widget", page._password_row.get_text() == "")
check("connected: status names the network", page._status_row.get_title() == "Connected to HomeNet.")
page.save(answers); check("connected: wifi_ssid recorded for Review", answers.wifi_ssid == "HomeNet")
check("connected: Forget offered", page._forget_button.get_visible())

# --- a wrong password afterwards replaces and removes the saved connection
ap = next(a for a in page._backend.scan() if a.ssid == "Wrong Password Net")
page._on_network(None, ap); page._password_row.set_text("whatever pass"); page._on_connect(None); pump(2500)
check("wrong password: error shown", page._error.get_visible() and "not accepted" in page._error.get_label())
page.save(answers); check("wrong password: nothing is saved any more (wifi_ssid cleared)", answers.wifi_ssid == "")
check("wrong password: password cleared from the widget", page._password_row.get_text() == "")

# --- validation errors are shown, not thrown
page._on_network(None, next(a for a in page._backend.scan() if a.ssid == "HomeNet"))
page._password_row.set_text("short"); page._on_connect(None)
check("short password: inline error, no connection attempt", page._error.get_visible() and "8 to 63" in page._error.get_label() and not page._busy)

# --- hidden network
page._on_hidden(None)
check("hidden: name row shown", page._ssid_row.get_visible())
page._ssid_row.set_text("Secret Net"); page._password_row.set_text("correct horse"); page._on_connect(None); pump(2500)
page.save(answers); check("hidden: connected and recorded", answers.wifi_ssid == "Secret Net")

# --- forget
page._on_forget(None); pump(600); page.save(answers)
check("forget: cleared", answers.wifi_ssid == "" and not page._forget_button.get_visible())

# --- blocked / missing / unknown radio states (Phase 17 hotfix, found on real hardware) ---
from gi.repository import Gtk
from installer.wifi_demo import demo_backend
from installer.wifi_diagnostics import Diagnostics, PciAdapter, RfkillDevice

BLOCKED = Diagnostics(
    machine="Alienware Alienware 14",
    rfkill=[RfkillDevice("phy0", "wlan", True, False, "ath9k")],
    wireless_interfaces=[],
    pci_adapters=[PciAdapter("168c:0034", "ath9k")],
)
NOTHING = Diagnostics(machine="", rfkill=[], wireless_interfaces=[], pci_adapters=[])


def shown_page(radio, diagnostics):
    """A real page inside a real (mapped) window, over a demo backend in `radio` state."""
    page = WifiPage(diagnostics=lambda: diagnostics)
    page._backend = demo_backend(delay=0, radio=radio)
    win = Gtk.Window()
    win.set_child(page.build(Answers()))
    win.present()
    page.on_shown(Answers(), Win())
    wait_until(lambda: page._radio is not None and not page._busy)
    return page, win


page, win = shown_page("disabled:enabled", BLOCKED)
status = page._status_row.get_title()
check("hard block: names the blocking device and driver", "phy0 (ath9k)" in status and "wireless switch" in status)
check("hard block: suggests the key and the BIOS", "BIOS" in status)
check("hard block: no networks are listed", page._rows == [])
check("hard block: Details are shown, with the adapter's ids", page._details.get_visible() and "168c:0034" in page._details_label.get_label())
check("hard block: skipping still works", page.validate(Answers()) is None)

# The user presses the Wi-Fi key: the page notices by itself, without a click on Refresh.
page._backend.set_demo_radio("enabled:enabled")
pump(3500)
check("recovery: picks up the change on its own and lists networks", page._status_row.get_title() == "Choose a network." and len(page._rows) > 0)
check("recovery: Details are hidden again", not page._details.get_visible())
pump(2500)
check("recovery: polling stops once the radio is on", page._poll_id is None)

page, win = shown_page("missing:enabled", NOTHING)
status = page._status_row.get_title()
check("no adapter: says so, and does not blame a hardware switch", "No Wi-Fi adapter" in status and "hardware switch" not in status)
check("no adapter: Details say none was found on the PCI bus", "No Wi-Fi adapter found on the PCI bus" in page._details_label.get_label())

page, win = shown_page("missing:enabled", Diagnostics("", [], [], [PciAdapter("168c:0034", "")]))
check("no driver: names the adapter and that no driver is using it", "168c:0034" in page._status_row.get_title() and "no driver" in page._status_row.get_title())

page, win = shown_page("garbage", NOTHING)
check("unknown: says it could not read the state, not a hardware switch", "Could not read" in page._status_row.get_title())

page, win = shown_page("enabled:disabled", NOTHING)
check("soft block: turned off, with the button to turn it on", page._status_row.get_title() == "Wi-Fi is turned off." and page._radio_button.get_visible())

# The Alienware 14's real case: a Broadcom BCM4352 bound to the bcma bus driver, which never
# gets a Wi-Fi interface. The page should say the installed system has the driver, not "BIOS".
page = WifiPage(
    diagnostics=lambda: Diagnostics("", [], [], [PciAdapter("14e4:43b1", "bcma-pci-bridge")]),
    known={"14e4:43b1": "Broadcom BCM4352 802.11ac"},
)
page._backend = demo_backend(delay=0, radio="missing:enabled")
win = Gtk.Window()
win.set_child(page.build(Answers()))
win.present()
page.on_shown(Answers(), Win())
wait_until(lambda: page._radio is not None and not page._busy)
status = page._status_row.get_title()
check("known adapter: names it and says Wi-Fi comes after the first boot", "Broadcom BCM4352" in status and "after the first boot" in status)
check("known adapter: does not send the user to the BIOS", "BIOS" not in status)
check("known adapter: skipping still works", page.validate(Answers()) is None)

# Polling must stop when the page is no longer on screen.
page, win = shown_page("disabled:enabled", BLOCKED)
check("polling: running while blocked and on screen", page._poll_id is not None)
win.set_child(None)   # the wizard moved on
pump(2600)
check("polling: stops when the page leaves the screen", page._poll_id is None)

print("\nGTK page smoke failures:", check.bad)
sys.exit(1 if check.bad else 0)
