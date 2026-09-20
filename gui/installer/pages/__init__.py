"""Every wizard page, in the fixed order they're shown -- a linear
sequential flow ending in one review screen, not a free-navigation menu
(the same principle autarchy-install's own terminal flow already
documents and was researched against archinstall/Calamares/Windows
Setup precedent for)."""

from .welcome import WelcomePage
from .language_region import LanguageRegionPage
from .wifi import WifiPage
from .account import AccountPage
from .disk import DiskPage
from .encryption import EncryptionPage
from .developer_identity import DeveloperIdentityPage
from .review import ReviewPage
from .progress import ProgressPage

PAGES = [
    WelcomePage,
    LanguageRegionPage,
    WifiPage,
    AccountPage,
    DiskPage,
    EncryptionPage,
    DeveloperIdentityPage,
    ReviewPage,
    ProgressPage,
]
