# Phase 17 — Wi-Fi at install, and an interactive network bar

| | |
|---|---|
| **Status** | Planned |
| **Driver** | Claude + user |
| **Branch** | `phase/17-wifi-network-bar` (stacked on `phase/16-desktop-bring-up` until 16 merges) |
| **Started** | 2026-09-20 |
| **Completed** | |

## Goal

A laptop installed from the ISO can optionally join Wi-Fi during install and lands
on its desktop already online, and the status bar shows the network state and lets
you act on it -- signal-level icon, click for a network picker, right-click for full
network settings -- built the way the rest of this repo is: a GTK-free tested core,
one home for each piece of knowledge, red tests first.

## Scope

**In scope**
- Live ISO runs NetworkManager (iwd and dhcpcd removed), the same stack as the
  installed system (D-0014), so one tool and one connection-file format serve both.
- An optional "Connect to Wi-Fi" page in the GUI installer (between LanguageRegion
  and Account): signal-sorted list with lock icons, password with show/hide,
  "Join hidden network", connecting spinner with an inline error, Refresh, rfkill
  banner with "Turn Wi-Fi on", "Connected via Ethernet" state, Skip.
- Hand-off to the installed system: whatever connection the live session saved is
  copied to the target's NetworkManager profile directory (0600, root), so the
  installed laptop autoconnects. The password is never in argv, a log, or the vars file.
- Regulatory domain from the chosen timezone (only if the spike shows it takes effect).
- NetworkManager's connectivity check disabled on the installed system and the live
  ISO (no phone-home to `ping.archlinux.org`).
- Waybar: `network` module with signal-level icons, ethernet / disconnected /
  rfkill-disabled / linked states, tooltip, and click actions; a `battery` module.
- `network-menu` entry point: left-click and `SUPER+CTRL+N` open the
  `networkmanager-dmenu` picker through fuzzel; right-click opens `nm-connection-editor`.
- Docs, decisions D-0068 to D-0072, an Omarchy-influences entry for network/Wi-Fi UI.

**Out of scope**
- Enterprise 802.1X, VPN UI, captive-portal UI, tray producers (enterprise and VPN
  are reachable through `nm-connection-editor`).
- Bluetooth (needs bluez and a daemon -- classified DEFER), volume-mixer click, brightness.
- MAC-randomization and power-save tuning (NetworkManager defaults stay).
- Regulatory domain for the live session (it stays in the world domain).
- Hardware-quirk scripts and a "restart Wi-Fi" recovery action (a later `network-menu` entry).
- Hibernation swap-size validation -- see Backlog.

## Decisions

**Resolved** (user-confirmed 2026-09-20 unless marked)
- Live ISO stack: **NetworkManager** on the live ISO too. One stack and one keyfile
  format, so the hand-off is a file copy (Calamares' `networkcfg` pattern). Matches
  what Omarchy's current line moved to; its old iwd path is not taken.
- Left-click: **`networkmanager-dmenu`** through fuzzel, following the
  `power-menu` / `clipboard-menu` shape. Right-click: **`nm-connection-editor`**
  (a real settings window: hidden networks, VPN, static IP, 802.1X), accepting its
  GTK3/libnma weight; it picks up the existing matugen GTK3 theme.
- Bar extras: **battery only** (built into Waybar, no daemon). Bluetooth deferred.
- NetworkManager connectivity check: **disabled**, no-telemetry rule; cost is no
  automatic captive-portal detection.
- Regulatory domain (mine, spike-gated): derive the country from `TZONE`, persist as
  `cfg80211.ieee80211_regdom=XX` on the UKI command line -- only if the spike shows
  it is honoured (Intel iwlwifi is often self-managed and ignores software hints).
- Numbering (mine): this is Phase 17; the update pipeline is Phase 18.

**Where each piece of knowledge lives (DRY)**

| Knowledge | Single home |
|---|---|
| The `.nmconnection` format (escaping, `psk-flags=0`, never `permissions=`) | `keyfile_for()` in `gui/installer/wifi.py` |
| Live-to-target hand-off | a generic copy of whatever the live session saved (`copy_network_profiles`); no format knowledge |
| Connectivity-check override | `system/networkmanager/20-connectivity.conf`; the ISO's airootfs copy is byte-identical, enforced by a `cmp` test (a symlink out of the profile would dangle in the ISO) |
| Country-from-timezone | one `regdom_arg()` helper called by `configure_boot`, which already owns `/etc/kernel/cmdline` |
| Network menu entry point | `home/network/dot-local/bin/network-menu` (`network-menu` = picker, `network-menu edit` = editor); Waybar clicks and the keybinding all call it |
| Bar palette | the matugen `waybar.css` template (gains `@define-color error`) |

**Open**
- [ ] Spike results below may change the regdom step, the wait-online handling, the
      `networkmanager-dmenu` password prompt, and whether `wireless-regdb` needs listing.

## Spikes (run before any code; results recorded here)

1. `systemctl --root=X enable NetworkManager` in an Arch container: does it pull in
   `NetworkManager-wait-online`? (If so, add a `mask` step.) Load golden keyfiles with
   awkward SSIDs/passwords (`;` `\` `#`, spaces, non-ASCII) into NetworkManager and
   inspect them; capture real `nmcli -t` scan output as fixtures.
2. `pacman -Si` for `networkmanager-dmenu` and `nm-connection-editor` (repo, offline
   closure); how `networkmanager-dmenu` uses fuzzel, asks for a WPA password, and
   handles hidden networks.
3. Regdom: whether `wireless-regdb` already arrives with `linux-firmware`; `zone.tab`
   layout; on the Alienware, `iw reg get` (if it says `self-managed`, drop the regdom
   step and D-0072).
4. Waybar: `battery` hides when there is no battery; `format-disabled` fires on
   rfkill; the Nerd Font Wi-Fi glyphs render.
5. Live boot in a VM: NetworkManager starts, the override is honoured, a root process
   under `cage` can add and activate a connection with no polkit or keyring,
   `copytoram` doesn't disturb `/etc/NetworkManager`.

## Acceptance tests (written before implementation)

Files: `gui/tests/test_wifi.py` (new), `gui/tests/test_state.py`,
`tests/unit/configure-base-system.bats`, `tests/unit/network-menu.bats` (new),
`tests/acceptance/phase-12.bats` (updated), `tests/acceptance/phase-17.bats` (new).

| Test | What it proves |
|---|---|
| ISO: NetworkManager and resolved wants links exist; no `iwd`/`dhcpcd` in the package list or wants; header no longer says "network installer"; live and `system/` connectivity drop-ins are byte-identical | One stack on the live ISO, no phone-home there, one source for the override |
| `parse_scan`: `\:` and `\\` escapes, empty SSID dropped, duplicates collapse to the strongest, sorted by signal, current network marked | The scan list is what the user should see |
| `classify_security`: open / WPA2 / WPA2+WPA3 transition -> psk; WPA3 -> sae; 802.1X -> enterprise (unsupported in v1); WEP/OWE unsupported | The page only offers what it can actually connect |
| `keyfile_for`: `psk-flags=0`, `autoconnect=true`, explicit uuid, `hidden=true` only when hidden, no security section for open, **never `permissions=`**, golden tests for `;` `\` `#`, spaces, non-ASCII | The one place that knows the format writes files NetworkManager accepts |
| `WifiBackend` (fake runner): profile written 0600, reload then `connection up`; the password is in **no** argv element, log line or exception message; profile deleted on failure or when switching network; errors map to wrong-password / not-found / timeout | Secrets stay out of `ps`, logs and the target; a bad password is never copied to disk on the target |
| `Answers.wifi_ssid` is display-only: no Wi-Fi keys in the vars file, no password field anywhere | The vars file contract is unchanged |
| `configure-base-system`: saved profiles copied at mode 600 root, byte-identical, none = no error; `TZONE=America/New_York` adds `cfg80211.ieee80211_regdom=US`, `UTC` adds nothing, existing cmdline assertions unchanged; drop-in installed | The installed laptop autoconnects; regdom only when known |
| `network-menu` dispatch: no argument -> `networkmanager_dmenu`, `edit` -> `nm-connection-editor` | Roles, not hardcoded executables |
| acceptance: `.network` has `on-click`, `on-click-right`, `format-disabled`, `format-disconnected`, a `format-icons` array of >= 4; `battery` in `modules-right`; CSS state selectors; `@define-color error`; `wifi` page sits between LanguageRegion and Account; influences entry present | The bar and installer wiring hold together |

Red confirmed: | Green confirmed: |

## Tasks

- [ ] Branch, tracking doc, roadmap row, backlog item (this commit)
- [ ] Spikes 1-5, results logged
- [ ] Step 1 -- live ISO to NetworkManager (red, green)
- [ ] Step 2 -- `gui/installer/wifi.py` and `gui/tests/test_wifi.py` (red, green)
- [ ] Step 3 -- `Answers`, Wi-Fi page, Review row, fake backend (red, green)
- [ ] Step 4 -- target side: profile copy, connectivity drop-in, regdom (if spiked in), packages (red, green)
- [ ] Step 5 -- Waybar `network`/`battery`, `network-menu`, keybinding, matugen `error` colour (red, green)
- [ ] Step 6 -- `phase-17.bats`, runbooks, influences entry, decisions D-0068 to D-0072, roadmap
- [ ] Build an ISO locally (`scripts/build-iso`), boot in a VM: guided install with Skip, no regression
- [ ] Real hardware: Wi-Fi page on the Alienware, install, reboot, land online; icon states,
      left/right click, rfkill, `SUPER+CTRL+N`, battery; password absent from `ps` and the
      journal; profile files `0600 root`
- [ ] Close: decisions, influences, roadmap, merge (after Phase 16 merges)

## Implementation log

### 2026-09-20
- Plan mode. User asked for an optional Wi-Fi step in the installer and a taskbar where
  the Wi-Fi icon can be seen and used, to be researched (Omarchy, Windows, macOS, other
  installers) and built cleanly. Three read-only research passes plus a design review:
  - **The bar already exists.** Waybar is running (Phase 5) but its `network` module is
    display-only -- no click action, no signal icons, plain-text "disconnected", no
    rfkill or linked state, no CSS states -- and there is no battery module although the
    target is now a laptop. The tray has no producers.
  - **Install is fully offline** (D-0063/64), so Wi-Fi at install only leaves the
    machine connected. Nothing carried a credential to the target; the live ISO ran
    iwd + dhcpcd with a manual, undocumented `iwctl`; the installed system runs
    NetworkManager.
  - **Omarchy** (current `quattro` line): no Wi-Fi step in its ISO -- Wi-Fi is set up
    after first boot from a bar panel, with a first-run notification if there is no
    link. It dropped iwd/impala/networkd for NetworkManager + wireless-regdb because
    enterprise, VPN, hidden and captive-portal networks were painful, sets the
    regulatory domain from the timezone at install, masks `NetworkManager-wait-online`,
    and ships a "restart Wi-Fi" recovery action. Its old ISO step scanned and connected
    with `iwctl` and carried iwd credentials over through archinstall. Ideas taken:
    NetworkManager, regdom from timezone, the recovery action later. Not taken: its
    panel, and the iwd/impala stack.
  - **Other OSes and installers:** Windows and macOS converge on a signal-sorted list
    with lock icons, a password field with show/hide, a hidden-network row, a
    spinner with an inline failure, and (macOS) a skip. Calamares has no Wi-Fi page:
    users connect in the live session and its `networkcfg` module copies the
    NetworkManager connection files to the target -- the hand-off adopted here.
  - **Design review** tightened: keep the hand-written connection file but golden-test
    its escaping (with libnm as the recorded fallback); delete a profile that fails so
    a bad password never autoconnects or reaches the target; no `permissions=` line
    ever; scan without BSSID (avoids `\:` noise); regdom via the kernel command line
    that `configure_boot` already owns, spike-gated; one `network-menu` entry point.
- User decisions (asked directly): NetworkManager on the live ISO; `nm-connection-editor`
  on right-click; battery as the only extra indicator; connectivity check disabled.

## Backlog (recorded, not in this phase)

- **Validate the hibernation swap size.** Found on hardware round 2 of Phase 16: a
  malformed swap size typed on the Disk page reached `sgdisk`, which failed with
  "Could not create partition 2 ... Unable to set partition 2's name to cryptswap" --
  an error that says nothing about the cause (the failure itself was a typo). Fix:
  validate in `gui/installer/state.py` (GTK-free, unit-tested: a whole number plus
  `K/M/G/T`; reject spaces, `GB`/`GiB`, zero, empty units), block Next on the Disk
  page with a clear message, mirror it in the terminal fallback `autarchy-install`,
  and have `install-base-system`'s preflight reject a bad or larger-than-the-disk
  `SWAP_SIZE` before anything destructive runs. Red tests first; small enough to
  bundle into whichever phase next touches the installer.

## VM → physical hardware notes

- A VM has no real radio: the unit tests use a fake command runner and recorded
  `nmcli` fixtures, and `--dry-run` uses a fake Wi-Fi backend. Real association,
  signal strength, rfkill, regulatory behaviour and battery can only be verified on
  the Alienware. That is also where the keyring-less session matters: profiles must
  be system-owned (`psk-flags=0`) or they will not autoconnect in a bare Hyprland
  session, and profiles created later in `nm-connection-editor` must be "available to
  all users" -- verify by rebooting and checking it reconnects.

## Exit criteria

- [ ] All acceptance tests pass
- [ ] Static checks pass
- [ ] `DECISIONS.md` updated (D-0068 to D-0072)
- [ ] `docs/omarchy-influences.md` updated
- [ ] `docs/roadmap.md` status updated
- [ ] Branch merged to `main`
