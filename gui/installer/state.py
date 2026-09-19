"""The answers collected across every page, in one place.

Mirrors autarchy-install's own local variables (disk, host, username,
tzone, locale, keymap, swap_size) plus the two passwords Phase 15 adds
to the collector's job (user password, LUKS passphrase -- D-0066) and
the optional git identity. Nothing here is written to disk until the
review page's "Install" action -- see runner.py.
"""

from dataclasses import dataclass, field


@dataclass
class Answers:
    keymap: str = ""
    locale: str = ""
    timezone: str = ""
    hostname: str = ""
    username: str = ""
    user_password: str = ""
    disk: str = ""
    disk_confirmation: str = ""
    luks_passphrase: str = ""
    git_name: str = ""
    git_email: str = ""
    swap_size: str = ""

    def vars_file_content(self) -> str:
        """The KEY=VALUE content install-base-system expects -- never
        includes either password; those go through fd 9, not the vars
        file (D-0066)."""
        return (
            f"DISK={self.disk}\n"
            f"HOST={self.hostname}\n"
            f"USERNAME={self.username}\n"
            f"TZONE={self.timezone}\n"
            f"LOCALE={self.locale}\n"
            f"KEYMAP={self.keymap}\n"
            f"SWAP_SIZE={self.swap_size}\n"
        )
