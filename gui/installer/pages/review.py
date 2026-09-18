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

        return box

    def on_shown(self, answers: Answers, window) -> None:
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
        add("Hibernation swap", answers.swap_size or "none")
        add("Account password", "set")
        add("Disk encryption", "passphrase set")
        add(
            "Developer identity",
            f"{answers.git_name} <{answers.git_email}>"
            if answers.git_name or answers.git_email
            else "skipped",
        )
