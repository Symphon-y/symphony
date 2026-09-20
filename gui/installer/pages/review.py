from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from ..page import Page
from ..state import Answers


class ReviewPage(Page):
    title = "Review"
    next_label = "Install"

    def build(self, answers: Answers) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        heading = Gtk.Label(label="Review")
        heading.add_css_class("title-2")
        heading.set_halign(Gtk.Align.START)
        box.append(heading)

        warning = Gtk.Label(label="Everything on the selected disk will be erased.")
        warning.add_css_class("warning")
        warning.set_halign(Gtk.Align.START)
        box.append(warning)

        self._group = Adw.PreferencesGroup()
        box.append(self._group)
        self._rows: list[Adw.ActionRow] = []

        # A real, typed confirmation, not just this button click -- the
        # same reasoning install-base-system's own confirm_destructive()
        # already documents ("a reflexive Enter can't confirm the wrong
        # disk"). This is also what actually satisfies that gate: runner.py
        # forwards this text over the install process's stdin, since
        # install-base-system still expects the disk path typed back
        # there, and clicking Install in a kiosk GUI has no other way to
        # answer that prompt.
        confirm_group = Adw.PreferencesGroup()
        self._confirm_row = Adw.EntryRow(title="Type the disk path to confirm")
        confirm_group.add(self._confirm_row)
        box.append(confirm_group)

        return box

    def on_shown(self, answers: Answers, window) -> None:
        # Reset on every visit, not just the first: if Back led to
        # picking a different disk, a stale typed confirmation from the
        # old one must not silently carry over.
        self._confirm_row.set_text("")

        for row in self._rows:
            self._group.remove(row)
        self._rows = []

        def add(title: str, value: str) -> None:
            row = Adw.ActionRow(title=title)
            row.add_suffix(Gtk.Label(label=value))
            self._group.add(row)
            self._rows.append(row)

        add("Disk", f"{answers.disk} (ERASED)")
        add("Hostname", answers.hostname)
        add("Username", answers.username)
        add("Timezone", answers.timezone)
        add("Locale", answers.locale)
        add("Keyboard layout", answers.keymap)
        add("Wi-Fi", answers.wifi_ssid or "skipped")
        add("Hibernation swap", answers.swap_size or "none")
        add("Account password", "set")
        add("Disk encryption", "passphrase set")
        add(
            "Developer identity",
            f"{answers.git_name} <{answers.git_email}>"
            if answers.git_name or answers.git_email
            else "skipped",
        )

    def validate(self, answers: Answers) -> str | None:
        typed = self._confirm_row.get_text().strip()
        if not typed:
            return "Type the disk path to confirm."
        if typed != answers.disk:
            return "Doesn't match -- type it exactly."
        return None

    def save(self, answers: Answers) -> None:
        answers.disk_confirmation = self._confirm_row.get_text().strip()
