from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from ..page import Page
from ..state import Answers


class EncryptionPage(Page):
    title = "Disk Encryption"

    def build(self, answers: Answers) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        heading = Gtk.Label(label="Disk Encryption")
        heading.add_css_class("title-2")
        heading.set_halign(Gtk.Align.START)
        box.append(heading)

        description = Gtk.Label(
            label=(
                "The entire disk is encrypted. You'll type this passphrase\n"
                "every time the machine boots -- choose something you'll remember."
            )
        )
        description.add_css_class("dim-label")
        description.set_justify(Gtk.Justification.CENTER)
        box.append(description)

        group = Adw.PreferencesGroup()
        box.append(group)

        self._passphrase_row = Adw.PasswordEntryRow(title="Disk encryption passphrase")
        self._passphrase_row.set_text(answers.luks_passphrase)
        group.add(self._passphrase_row)

        self._confirm_row = Adw.PasswordEntryRow(title="Confirm passphrase")
        group.add(self._confirm_row)

        return box

    def validate(self, answers: Answers) -> str | None:
        passphrase = self._passphrase_row.get_text()
        if not passphrase:
            return "Enter a passphrase."
        if passphrase != self._confirm_row.get_text():
            return "Passphrases don't match."
        return None

    def save(self, answers: Answers) -> None:
        answers.luks_passphrase = self._passphrase_row.get_text()
