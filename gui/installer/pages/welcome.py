from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from ..page import Page
from ..state import Answers


class WelcomePage(Page):
    title = "Welcome"

    def build(self, answers: Answers) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_valign(Gtk.Align.CENTER)
        box.set_margin_top(48)
        box.set_margin_bottom(48)

        icon = Gtk.Image.new_from_icon_name("computer-symbolic")
        icon.set_pixel_size(96)
        box.append(icon)

        title = Gtk.Label(label="Welcome to autarchy")
        title.add_css_class("title-1")
        box.append(title)

        subtitle = Gtk.Label(
            label=(
                "A few questions, then this installer runs on its own.\n"
                "Nothing is written to the disk until you confirm at the end."
            )
        )
        subtitle.add_css_class("dim-label")
        subtitle.set_justify(Gtk.Justification.CENTER)
        box.append(subtitle)

        return box
