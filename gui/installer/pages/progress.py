from __future__ import annotations

import tempfile
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from .. import runner
from ..page import Page
from ..state import Answers


class ProgressPage(Page):
    title = "Installing"
    # No Back/Next once the install has started -- there's nothing to go
    # back to (the disk is already being wiped) and nowhere to advance
    # to until it finishes; the Reboot/Stay buttons below take over.
    next_label = ""

    def build(self, answers: Answers) -> Gtk.Widget:
        self._started = False

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)

        self._heading = Gtk.Label(label="Installing symphony...")
        self._heading.add_css_class("title-2")
        box.append(self._heading)

        self._spinner = Gtk.Spinner(spinning=True)
        self._spinner.set_size_request(32, 32)
        box.append(self._spinner)

        scroller = Gtk.ScrolledWindow(vexpand=True)
        scroller.set_min_content_height(240)
        self._log_buffer = Gtk.TextBuffer()
        log_view = Gtk.TextView(buffer=self._log_buffer, editable=False, monospace=True)
        log_view.add_css_class("card")
        scroller.set_child(log_view)
        box.append(scroller)

        self._done_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self._done_box.set_visible(False)
        self._done_label = Gtk.Label()
        self._done_box.append(self._done_label)

        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        button_box.set_halign(Gtk.Align.CENTER)
        reboot_button = Gtk.Button(label="Reboot Now")
        reboot_button.add_css_class("suggested-action")
        reboot_button.connect("clicked", self._on_reboot)
        button_box.append(reboot_button)
        stay_button = Gtk.Button(label="Stay at the Shell")
        stay_button.connect("clicked", self._on_stay)
        button_box.append(stay_button)
        self._done_box.append(button_box)
        box.append(self._done_box)

        return box

    def on_shown(self, answers: Answers, window) -> None:
        if self._started:
            return
        self._started = True
        self._window = window

        if window.dry_run:
            vars_path = Path(tempfile.gettempdir()) / "symphony-gui-dry-run.vars"
        else:
            vars_path = Path("/root/symphony/base-install.local.vars")

        runner.start_install(
            answers,
            dry_run=window.dry_run,
            vars_path=vars_path,
            on_line=self._append_line,
            on_done=self._on_done,
        )

    def _append_line(self, line: str) -> bool:
        end = self._log_buffer.get_end_iter()
        self._log_buffer.insert(end, line + "\n")
        return False

    def _on_done(self, code: int) -> bool:
        self._spinner.set_visible(False)
        if code == 0:
            self._heading.set_label("Base install done.")
            self._done_label.set_label("You can reboot now, or stay at the shell.")
        else:
            self._heading.set_label(f"Install failed (exit code {code}).")
            self._done_label.set_label(
                "See the log above. Nothing further has been touched."
            )
        self._done_box.set_visible(True)
        return False

    def _on_reboot(self, _button: Gtk.Button) -> None:
        runner.finish_and_reboot(self._window.dry_run)
        if self._window.dry_run:
            self._done_label.set_label("[dry-run] would unmount, close, and reboot now.")

    def _on_stay(self, _button: Gtk.Button) -> None:
        self._done_label.set_label(
            "Staying at the shell. When ready: umount -R /mnt; cryptsetup close root; poweroff"
        )
