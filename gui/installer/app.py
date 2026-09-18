"""The main window: a linear Back/Next wizard over a fixed page list,
plus the shared Answers state every page reads from and writes into.
No install logic here -- see runner.py."""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from .state import Answers


class InstallerWindow(Adw.ApplicationWindow):
    def __init__(self, app: Adw.Application, pages: list, *, dry_run: bool) -> None:
        super().__init__(application=app, default_width=760, default_height=640)
        self.set_title("autarchy installer")

        self.answers = Answers()
        self.dry_run = dry_run
        self._pages = pages
        self._built = [False] * len(pages)
        self._index = 0

        toolbar_view = Adw.ToolbarView()
        self.set_content(toolbar_view)

        self.header = Adw.HeaderBar()
        self.header.set_show_end_title_buttons(True)
        toolbar_view.add_top_bar(self.header)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        clamp = Adw.Clamp(maximum_size=560)
        clamp.set_child(self.stack)
        clamp.set_margin_top(24)
        clamp.set_margin_bottom(24)
        clamp.set_margin_start(24)
        clamp.set_margin_end(24)
        toolbar_view.set_content(clamp)

        self.error_label = Gtk.Label()
        self.error_label.add_css_class("error")
        self.error_label.set_visible(False)

        nav_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=12, homogeneous=False
        )
        nav_box.set_margin_top(6)
        nav_box.set_margin_bottom(12)
        nav_box.set_margin_start(24)
        nav_box.set_margin_end(24)

        self.back_button = Gtk.Button(label="Back")
        self.back_button.connect("clicked", self._on_back)
        nav_box.append(self.back_button)

        nav_box.append(self.error_label)

        spacer = Gtk.Box(hexpand=True)
        nav_box.append(spacer)

        self.next_button = Gtk.Button(label="Next")
        self.next_button.add_css_class("suggested-action")
        self.next_button.connect("clicked", self._on_next)
        nav_box.append(self.next_button)

        toolbar_view.add_bottom_bar(nav_box)

        self._show_page(0)

    def _current_page(self):
        return self._pages[self._index]

    def _show_page(self, index: int) -> None:
        self._index = index
        page = self._current_page()
        name = f"page{index}"
        if not self._built[index]:
            widget = page.build(self.answers)
            self.stack.add_named(widget, name)
            self._built[index] = True
        self.stack.set_visible_child_name(name)
        self.header.set_title_widget(Adw.WindowTitle(title="autarchy installer", subtitle=page.title))
        self.back_button.set_sensitive(index > 0)
        self.back_button.set_visible(page.next_label != "")
        self.next_button.set_label(page.next_label)
        self.next_button.set_visible(page.next_label != "")
        self._set_error(None)
        page.on_shown(self.answers, self)

    def _set_error(self, message: str | None) -> None:
        if message:
            self.error_label.set_label(message)
            self.error_label.set_visible(True)
        else:
            self.error_label.set_visible(False)

    def _on_back(self, _button: Gtk.Button) -> None:
        if self._index > 0:
            self._show_page(self._index - 1)

    def _on_next(self, _button: Gtk.Button) -> None:
        page = self._current_page()
        error = page.validate(self.answers)
        if error:
            self._set_error(error)
            return
        page.save(self.answers)
        if self._index + 1 < len(self._pages):
            self._show_page(self._index + 1)


class InstallerApp(Adw.Application):
    def __init__(self, pages: list, *, dry_run: bool) -> None:
        super().__init__(application_id="com.autarchy.installer")
        self._pages = pages
        self._dry_run = dry_run
        self.connect("activate", self._on_activate)

    def _on_activate(self, app: Adw.Application) -> None:
        win = InstallerWindow(app, self._pages, dry_run=self._dry_run)
        win.present()
