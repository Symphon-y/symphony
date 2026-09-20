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

def check(label, cond):
    print(("ok   " if cond else "FAIL ") + label)
    if not cond: check.bad += 1
check.bad = 0

Adw.init()
page, answers = WifiPage(), Answers()
widget = page.build(answers)
check("build() returns a widget", widget is not None)
page.on_shown(answers, Win()); pump(700)
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
print("\nGTK page smoke failures:", check.bad)
sys.exit(1 if check.bad else 0)
