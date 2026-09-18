"""The common shape every wizard page follows, so app.py's navigation
frame (Back/Next, validation, saving) doesn't need to know anything
page-specific."""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk  # noqa: E402

from .state import Answers  # noqa: E402


class Page:
    #: Shown in the header bar's subtitle while this page is active.
    title = ""
    #: The Next button's own label on this page -- most pages just say
    #: "Next", but the review page says "Install" and progress/done hide
    #: it entirely (handled by app.py, not here).
    next_label = "Next"

    def build(self, answers: Answers) -> Gtk.Widget:
        """Builds and returns this page's widget tree. Called once, the
        first time this page is shown -- not rebuilt on every visit, so
        implementations should read `answers` here to restore any value
        the user already entered if they went Back and returned."""
        raise NotImplementedError

    def validate(self, answers: Answers) -> str | None:
        """An error message to show (and block Next) instead of saving
        and advancing, or None if this page's current input is fine."""
        return None

    def save(self, answers: Answers) -> None:
        """Copies this page's widget state into `answers`. Only called
        after validate() returns None."""
        return None

    def on_shown(self, answers: Answers, window) -> None:
        """Called every time this page becomes visible (including
        returning via Back). Default: nothing -- only the progress page
        needs this, to kick off the install the first time it's shown."""
        return None
