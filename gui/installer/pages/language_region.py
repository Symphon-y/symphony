from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from .. import system_info
from ..page import Page
from ..state import Answers


class LanguageRegionPage(Page):
    title = "Language & Region"

    def build(self, answers: Answers) -> Gtk.Widget:
        self._keymaps = system_info.available_keymaps() or ["us"]
        self._locales = system_info.available_locales() or ["en_US.UTF-8 UTF-8"]
        self._timezones = system_info.available_timezones() or ["UTC"]

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        heading = Gtk.Label(label="Language & Region")
        heading.add_css_class("title-2")
        heading.set_halign(Gtk.Align.START)
        box.append(heading)

        group = Adw.PreferencesGroup()
        box.append(group)

        self._keymap_row = Adw.ComboRow(title="Keyboard layout")
        self._keymap_row.set_model(Gtk.StringList.new(self._keymaps))
        self._keymap_row.set_enable_search(True)
        self._select(self._keymap_row, self._keymaps, answers.keymap or "us")
        group.add(self._keymap_row)

        self._locale_row = Adw.ComboRow(title="Locale")
        self._locale_row.set_model(Gtk.StringList.new(self._locales))
        self._locale_row.set_enable_search(True)
        self._select(
            self._locale_row,
            self._locales,
            answers.locale + " " if answers.locale else "en_US.UTF-8 UTF-8",
            by_prefix=True,
        )
        group.add(self._locale_row)

        self._tz_row = Adw.ComboRow(title="Timezone")
        self._tz_row.set_model(Gtk.StringList.new(self._timezones))
        self._tz_row.set_enable_search(True)
        self._select(self._tz_row, self._timezones, answers.timezone or "UTC")
        group.add(self._tz_row)

        return box

    @staticmethod
    def _select(row: Adw.ComboRow, items: list[str], value: str, *, by_prefix: bool = False) -> None:
        for i, item in enumerate(items):
            if (item.startswith(value) if by_prefix else item == value):
                row.set_selected(i)
                return
        row.set_selected(0)

    def save(self, answers: Answers) -> None:
        answers.keymap = self._keymaps[self._keymap_row.get_selected()]
        answers.locale = self._locales[self._locale_row.get_selected()].split()[0]
        answers.timezone = self._timezones[self._tz_row.get_selected()]
