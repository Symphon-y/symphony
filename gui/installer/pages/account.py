from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from ..page import Page
from ..state import Answers


class AccountPage(Page):
    title = "Account"

    def build(self, answers: Answers) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        heading = Gtk.Label(label="Your Account")
        heading.add_css_class("title-2")
        heading.set_halign(Gtk.Align.START)
        box.append(heading)

        machine_group = Adw.PreferencesGroup(title="This machine")
        box.append(machine_group)

        self._hostname_row = Adw.EntryRow(title="Hostname")
        self._hostname_row.set_text(answers.hostname)
        machine_group.add(self._hostname_row)

        user_group = Adw.PreferencesGroup(title="Your user account")
        box.append(user_group)

        self._username_row = Adw.EntryRow(title="Username")
        self._username_row.set_text(answers.username)
        user_group.add(self._username_row)

        self._password_row = Adw.PasswordEntryRow(title="Password")
        self._password_row.set_text(answers.user_password)
        user_group.add(self._password_row)

        self._confirm_row = Adw.PasswordEntryRow(title="Confirm password")
        user_group.add(self._confirm_row)

        return box

    def validate(self, answers: Answers) -> str | None:
        if not self._hostname_row.get_text().strip():
            return "Enter a hostname."
        if not self._username_row.get_text().strip():
            return "Enter a username."
        password = self._password_row.get_text()
        if not password:
            return "Enter a password."
        if password != self._confirm_row.get_text():
            return "Passwords don't match."
        return None

    def save(self, answers: Answers) -> None:
        answers.hostname = self._hostname_row.get_text().strip()
        answers.username = self._username_row.get_text().strip()
        answers.user_password = self._password_row.get_text()
