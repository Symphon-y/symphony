"""Hands off to install/run-guided-install (real) or gui/fake-backend
(--dry-run) -- never install logic here, same principle every bash
collector in this repo already follows. Streams output line-by-line via
a callback so the progress page can show it live.
"""

from __future__ import annotations

import os
import subprocess
import threading
from pathlib import Path
from typing import Callable

from .state import Answers

REPO_ROOT = Path(__file__).resolve().parents[2]
REAL_RUNNER = REPO_ROOT / "install" / "run-guided-install"
REAL_FINISH = REPO_ROOT / "install" / "finish-install"
FAKE_BACKEND = REPO_ROOT / "gui" / "fake-backend"


def _secret_pipe_fd(secret: str) -> int:
    """A pipe already holding `secret` (+ newline, matching read -r's
    own expectation) with the write end closed -- returns the read-end
    fd number."""
    r, w = os.pipe()
    os.write(w, secret.encode() + b"\n")
    os.close(w)
    return r


def start_install(
    answers: Answers,
    *,
    dry_run: bool,
    vars_path: Path,
    on_line: Callable[[str], None],
    on_done: Callable[[int], None],
) -> None:
    """Starts the install in a background thread -- subprocess I/O would
    otherwise block the GTK main loop -- and marshals every line, plus
    the final exit code, back to the main thread via GLib.idle_add (the
    only thread-safe way to touch GTK widgets from a worker thread).

    --no-reboot-prompt (real mode): run-guided-install's own interactive
    "Reboot now?" would hang with no terminal attached, or silently take
    the EOF-default branch -- this app shows its own Reboot/Stay UI
    instead (see finish_and_reboot()).
    """
    from gi.repository import GLib

    vars_path.write_text(answers.vars_file_content())

    user_r = _secret_pipe_fd(answers.user_password)
    luks_r = _secret_pipe_fd(answers.luks_passphrase)

    def preexec() -> None:
        # dup2 remaps whatever fd numbers the pipes happened to get onto
        # exactly 8/9 -- the contract install-base-system/configure-
        # base-system expect (D-0066). pass_fds=(8, 9) below is required
        # too: close_fds's own cleanup runs independently of this
        # function and would otherwise close right back out whatever
        # this dup2s in -- verified locally before relying on this.
        os.dup2(user_r, 8)
        os.dup2(luks_r, 9)
        os.close(user_r)
        os.close(luks_r)

    if dry_run:
        argv = [str(FAKE_BACKEND), str(vars_path)]
    else:
        argv = [str(REAL_RUNNER), "--no-reboot-prompt", str(vars_path)]

    def worker() -> None:
        proc = subprocess.Popen(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            preexec_fn=preexec,
            pass_fds=(8, 9),
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            GLib.idle_add(on_line, line.rstrip("\n"))
        code = proc.wait()
        GLib.idle_add(on_done, code)

    threading.Thread(target=worker, daemon=True).start()


def finish_and_reboot(dry_run: bool) -> None:
    """Unmount, close the encrypted volume, reboot -- install/
    finish-install itself, the same script the terminal collector calls
    on its own "Reboot now?" yes. Dry-run mode doesn't call it at all,
    since this dev VM's own disk must never actually be touched."""
    if dry_run:
        return
    subprocess.Popen([str(REAL_FINISH)])
