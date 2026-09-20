"""The optional Wi-Fi page (Phase 17). Thin on purpose: every decision -- what a
scan means, what may be joined, what a failure is called -- lives in the tested,
GTK-free wifi.py. This only lays out widgets and moves work off the main thread.

The install itself needs no network, so the page is skippable (Next with nothing
joined). A network joined here is remembered on the installed system:
install/configure-base-system copies the connection file this leaves behind.
"""

from __future__ import annotations

import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, GLib, Gtk

from .. import wifi, wifi_diagnostics
from ..page import Page
from ..state import Answers
from ..wifi_demo import demo_backend

_SECURITY_LABEL = {
    wifi.Security.OPEN: "Open",
    wifi.Security.WPA_PSK: "Password",
    wifi.Security.SAE: "WPA3",
    wifi.Security.ENTERPRISE: "Enterprise -- set up after install",
    wifi.Security.UNSUPPORTED: "Not supported here",
}


def _signal_icon(signal: int) -> str:
    level = "excellent" if signal >= 75 else "good" if signal >= 50 else "ok" if signal >= 25 else "weak"
    return f"network-wireless-signal-{level}-symbolic"


class WifiPage(Page):
    title = "Wi-Fi"

    def __init__(self, diagnostics=None) -> None:
        # What to read the machine's Wi-Fi facts from; injectable so the smoke test
        # can present a blocked laptop without one.
        self._diagnostics = diagnostics or wifi_diagnostics.collect
        self._radio: wifi.RadioState | None = None
        self._poll_id: int | None = None
        self._root: Gtk.Widget | None = None
        self._backend: wifi.WifiBackend | None = None
        self._selected: wifi.AccessPoint | None = None
        self._hidden = False
        self._connected_ssid = ""
        self._busy = False
        self._rows: list[Gtk.Widget] = []

    # -- layout

    def build(self, answers: Answers) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        heading = Gtk.Label(label="Connect to Wi-Fi")
        heading.add_css_class("title-2")
        heading.set_halign(Gtk.Align.START)
        box.append(heading)

        note = Gtk.Label(
            label="Optional -- installing needs no network. A network you join here is remembered on the new system.",
            wrap=True,
            xalign=0,
        )
        note.add_css_class("dim-label")
        box.append(note)

        status_group = Adw.PreferencesGroup()
        box.append(status_group)
        self._status_row = Adw.ActionRow(title="")
        self._spinner = Gtk.Spinner()
        self._status_row.add_suffix(self._spinner)
        self._radio_button = Gtk.Button(label="Turn Wi-Fi on", valign=Gtk.Align.CENTER)
        self._radio_button.connect("clicked", self._on_turn_on)
        self._status_row.add_suffix(self._radio_button)
        self._forget_button = Gtk.Button(label="Forget", valign=Gtk.Align.CENTER)
        self._forget_button.connect("clicked", self._on_forget)
        self._status_row.add_suffix(self._forget_button)
        self._refresh_button = Gtk.Button(label="Refresh", valign=Gtk.Align.CENTER)
        self._refresh_button.connect("clicked", lambda _b: self._refresh(rescan=True))
        self._status_row.add_suffix(self._refresh_button)
        status_group.add(self._status_row)

        # The machine's own facts about its Wi-Fi radio, shown when something is
        # wrong: the live installer has no terminal to look for them in.
        self._details = Gtk.Expander(label="Details")
        self._details_label = Gtk.Label(wrap=True, xalign=0, selectable=True)
        self._details_label.add_css_class("dim-label")
        self._details.set_child(self._details_label)
        self._details.set_visible(False)
        box.append(self._details)

        self._networks = Adw.PreferencesGroup(title="Networks")
        box.append(self._networks)
        self._hidden_row = Adw.ActionRow(title="Join a hidden network...", activatable=True)
        self._hidden_row.connect("activated", self._on_hidden)

        self._join = Adw.PreferencesGroup()
        self._join.set_visible(False)
        box.append(self._join)
        self._ssid_row = Adw.EntryRow(title="Network name")
        self._join.add(self._ssid_row)
        self._password_row = Adw.PasswordEntryRow(title="Password")
        self._password_row.connect("entry-activated", self._on_connect)
        self._join.add(self._password_row)
        self._connect_button = Gtk.Button(label="Connect", halign=Gtk.Align.END)
        self._connect_button.add_css_class("suggested-action")
        self._connect_button.connect("clicked", self._on_connect)
        box.append(self._connect_button)
        self._connect_button.set_visible(False)

        self._error = Gtk.Label(wrap=True, xalign=0)
        self._error.add_css_class("error")
        self._error.set_visible(False)
        box.append(self._error)

        self._show_status("Looking for networks...")
        self._radio_button.set_visible(False)
        self._forget_button.set_visible(False)
        self._root = box
        return box

    # -- page lifecycle

    def on_shown(self, answers: Answers, window) -> None:
        if self._backend is None:
            self._backend = demo_backend() if window.dry_run else wifi.WifiBackend()
        self._refresh(rescan=False)

    def validate(self, answers: Answers) -> str | None:
        # Skipping is fine; only hold Next while a join is mid-flight, so its result
        # can't land after the install has started.
        if self._busy:
            return "Still connecting -- wait a moment."
        return None

    def save(self, answers: Answers) -> None:
        answers.wifi_ssid = self._connected_ssid

    # -- background work

    def _in_thread(self, work, done) -> None:
        def run() -> None:
            try:
                result, error = work(), None
            except Exception as caught:  # noqa: BLE001 -- shown to the user, not swallowed
                result, error = None, caught
            GLib.idle_add(done, result, error)

        threading.Thread(target=run, daemon=True).start()

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self._spinner.set_spinning(busy)
        self._refresh_button.set_sensitive(not busy)
        self._connect_button.set_sensitive(not busy)

    def _show_status(self, text: str) -> None:
        self._status_row.set_title(text)

    def _show_error(self, text: str | None) -> None:
        self._error.set_label(text or "")
        self._error.set_visible(bool(text))

    # -- scanning

    def _refresh(self, rescan: bool) -> None:
        if self._busy:
            return
        self._set_busy(True)
        self._show_status("Looking for networks...")
        backend = self._backend
        collect = self._diagnostics

        def work():
            radio = backend.radio_state()
            # The machine's facts are only worth reading when something is off.
            diagnostics = collect() if radio is not wifi.RadioState.ON else None
            return radio, backend.ethernet_connected(), backend.scan(rescan=rescan), diagnostics

        self._in_thread(work, self._scan_done)

    def _scan_done(self, result, error) -> None:
        self._set_busy(False)
        if error is not None:
            self._show_status("Could not look for networks.")
            self._show_error(str(error))
            return
        radio, ethernet, aps, diagnostics = result
        self._radio = radio
        problem = radio is not wifi.RadioState.ON
        self._radio_button.set_visible(radio is wifi.RadioState.SOFT_BLOCKED)
        self._forget_button.set_visible(bool(self._connected_ssid))

        # When something is off, say what is true (which device, what to try) and put
        # the machine's own facts one click away.
        self._details.set_visible(problem and diagnostics is not None)
        if problem and diagnostics is not None:
            self._details_label.set_label("\n".join(diagnostics.lines()))

        if radio in (wifi.RadioState.HARD_BLOCKED, wifi.RadioState.SOFT_BLOCKED, wifi.RadioState.NO_ADAPTER):
            aps = []
            self._show_status(wifi_diagnostics.status_message(radio, diagnostics))
        elif radio is wifi.RadioState.UNKNOWN:
            # Can't tell -- a scan may still work, so leave whatever it found.
            self._show_status(wifi_diagnostics.status_message(radio, diagnostics))
        elif self._connected_ssid:
            self._show_status(f"Connected to {self._connected_ssid}.")
        elif ethernet:
            self._show_status("Connected by cable. Wi-Fi is optional.")
        else:
            self._show_status("Choose a network." if aps else "No networks found -- try Refresh.")
        self._populate(aps)
        self._ensure_polling(problem)

    # -- noticing a change without a click on Refresh

    def _ensure_polling(self, wanted: bool) -> None:
        if wanted and self._poll_id is None:
            self._poll_id = GLib.timeout_add_seconds(2, self._poll)

    def _poll(self) -> bool:
        """While the radio is blocked, missing or unreadable, re-read its state every
        couple of seconds, so pressing the Wi-Fi key, fixing a BIOS setting, or
        NetworkManager finishing its start-up is noticed on its own. Stops once the
        radio is on or the page is no longer on screen."""
        if self._radio is wifi.RadioState.ON or self._root is None or not self._root.get_mapped():
            self._poll_id = None
            return False
        if not self._busy:
            self._in_thread(self._backend.radio_state, self._poll_done)
        return True

    def _poll_done(self, state, error) -> None:
        if error is None and state is not None and state is not self._radio:
            self._refresh(rescan=True)

    def _populate(self, aps: list[wifi.AccessPoint]) -> None:
        for row in self._rows:
            self._networks.remove(row)
        self._rows = []
        for ap in aps:
            row = Adw.ActionRow(title=GLib.markup_escape_text(ap.ssid), subtitle=_SECURITY_LABEL[ap.security])
            row.add_prefix(Gtk.Image.new_from_icon_name(_signal_icon(ap.signal)))
            if ap.security is not wifi.Security.OPEN:
                row.add_suffix(Gtk.Image.new_from_icon_name("channel-secure-symbolic"))
            if ap.ssid == self._connected_ssid:
                row.add_suffix(Gtk.Image.new_from_icon_name("object-select-symbolic"))
            row.set_activatable(ap.supported)
            row.set_sensitive(ap.supported)
            row.connect("activated", self._on_network, ap)
            self._networks.add(row)
            self._rows.append(row)
        # The hidden-network entry always comes last.
        if self._hidden_row.get_parent() is not None:
            self._networks.remove(self._hidden_row)
        self._networks.add(self._hidden_row)

    # -- choosing and joining

    def _open_join(self, hidden: bool, ap: wifi.AccessPoint | None) -> None:
        self._hidden = hidden
        self._selected = ap
        self._show_error(None)
        self._ssid_row.set_visible(hidden)
        self._ssid_row.set_text("")
        self._password_row.set_text("")
        self._password_row.set_visible(hidden or (ap is not None and ap.security is not wifi.Security.OPEN))
        self._join.set_title("Join a hidden network" if hidden else GLib.markup_escape_text(ap.ssid))
        self._join.set_visible(True)
        self._connect_button.set_visible(True)

    def _on_network(self, _row, ap: wifi.AccessPoint) -> None:
        self._open_join(hidden=False, ap=ap)

    def _on_hidden(self, _row) -> None:
        self._open_join(hidden=True, ap=None)

    def _on_connect(self, _widget) -> None:
        if self._busy:
            return
        if self._hidden:
            ssid = self._ssid_row.get_text()
            password = self._password_row.get_text()
            # A hidden network's security can't be scanned; a password means WPA.
            security = wifi.Security.WPA_PSK if password else wifi.Security.OPEN
        elif self._selected is not None:
            ssid, security = self._selected.ssid, self._selected.security
            password = self._password_row.get_text()
        else:
            return

        try:
            wifi.validate_ssid(ssid)
            wifi.validate_passphrase(password, security)
        except wifi.WifiError as problem:
            self._show_error(str(problem))
            return

        self._show_error(None)
        self._set_busy(True)
        self._show_status(f"Connecting to {ssid}...")
        backend, hidden = self._backend, self._hidden
        self._in_thread(
            lambda: backend.connect(ssid, password, security, hidden=hidden),
            lambda _result, error: self._connect_done(ssid, error),
        )

    def _connect_done(self, ssid: str, error) -> None:
        # Whatever happened, the password is not kept in the widget.
        self._password_row.set_text("")
        self._set_busy(False)
        if error is not None:
            # The installer keeps a single saved connection, so this attempt replaced
            # any earlier one and a failure removed it: nothing is saved any more.
            self._connected_ssid = ""
            self._forget_button.set_visible(False)
            self._show_status("Could not connect.")
            self._show_error(str(error))
            return
        self._connected_ssid = ssid
        self._join.set_visible(False)
        self._connect_button.set_visible(False)
        self._refresh(rescan=False)

    # -- undoing / recovering

    def _on_forget(self, _button) -> None:
        self._backend.forget()
        self._connected_ssid = ""
        self._forget_button.set_visible(False)
        self._refresh(rescan=False)

    def _on_turn_on(self, _button) -> None:
        if self._busy:
            return
        self._set_busy(True)
        backend = self._backend
        self._in_thread(backend.enable_radio, lambda _r, _e: (self._set_busy(False), self._refresh(rescan=True)))
