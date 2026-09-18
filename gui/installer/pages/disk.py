from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from .. import system_info
from ..page import Page
from ..state import Answers


class DiskPage(Page):
    title = "Disk"

    def build(self, answers: Answers) -> Gtk.Widget:
        self._disks = system_info.available_disks()

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        heading = Gtk.Label(label="Choose a Disk")
        heading.add_css_class("title-2")
        heading.set_halign(Gtk.Align.START)
        box.append(heading)

        warning = Gtk.Label(
            label="Everything on the selected disk will be erased."
        )
        warning.add_css_class("warning")
        warning.set_halign(Gtk.Align.START)
        box.append(warning)

        group = Adw.PreferencesGroup()
        box.append(group)

        labels = []
        candidates = []
        for disk in self._disks:
            label = f"{disk.path} -- {disk.size}"
            if disk.model:
                label += f" ({disk.model})"
            if disk.is_installer_media:
                label += "  [this installer -- do not select]"
            labels.append(label)
            candidates.append(disk)
        if not labels:
            labels = ["(no disks found)"]

        self._disk_row = Adw.ComboRow(title="Target disk")
        self._disk_row.set_model(Gtk.StringList.new(labels))
        # Default to the one non-installer-media disk when there's
        # exactly one -- same "everything else is picked for you" feel
        # the terminal collector's ask_disk() already has.
        non_installer = [d for d in candidates if not d.is_installer_media]
        if len(non_installer) == 1:
            self._disk_row.set_selected(candidates.index(non_installer[0]))
        elif answers.disk:
            for i, d in enumerate(candidates):
                if d.path == answers.disk:
                    self._disk_row.set_selected(i)
                    break
        group.add(self._disk_row)

        swap_group = Adw.PreferencesGroup(
            title="Hibernation",
            description="Optional -- a dedicated encrypted swap partition sized for your RAM, e.g. 16G. Leave blank to skip.",
        )
        box.append(swap_group)
        self._swap_row = Adw.EntryRow(title="Hibernation swap size")
        self._swap_row.set_text(answers.swap_size)
        swap_group.add(self._swap_row)

        return box

    def validate(self, answers: Answers) -> str | None:
        if not self._disks:
            return "No disks found."
        return None

    def save(self, answers: Answers) -> None:
        answers.disk = self._disks[self._disk_row.get_selected()].path
        answers.swap_size = self._swap_row.get_text().strip()
