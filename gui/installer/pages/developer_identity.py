from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from ..page import Page
from ..state import Answers


class DeveloperIdentityPage(Page):
    title = "Developer Identity (Optional)"

    def build(self, answers: Answers) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        heading = Gtk.Label(label="Developer Identity")
        heading.add_css_class("title-2")
        heading.set_halign(Gtk.Align.START)
        box.append(heading)

        description = Gtk.Label(
            label=(
                "Optional -- for your own local git commits only.\n"
                "No GitHub account or sign-in is needed to use this machine.\n"
                "Leave blank to skip; you can set this later."
            )
        )
        description.add_css_class("dim-label")
        description.set_justify(Gtk.Justification.CENTER)
        box.append(description)

        group = Adw.PreferencesGroup()
        box.append(group)

        self._name_row = Adw.EntryRow(title="Name")
        self._name_row.set_text(answers.git_name)
        group.add(self._name_row)

        self._email_row = Adw.EntryRow(title="Email")
        self._email_row.set_text(answers.git_email)
        group.add(self._email_row)

        return box

    def save(self, answers: Answers) -> None:
        answers.git_name = self._name_row.get_text().strip()
        answers.git_email = self._email_row.get_text().strip()
