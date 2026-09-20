# Phase 17 — Wi-Fi at install, and an interactive network bar

| | |
|---|---|
| **Status** | In progress (implemented and tested; real-hardware verification pending) |
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
- Regulatory domain from the chosen timezone, written to `/etc/conf.d/wireless-regdom`
  -- the `wireless-regdb` package's own mechanism (spike 3), not the kernel command line.
- `NetworkManager-wait-online` masked (spike 1: enabling NetworkManager pulls it in).
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
- Regulatory domain (mine; **revised by spike 3**): derive the country from `TZONE`
  (`zone.tab`, one country per zone) and write `WIRELESS_REGDOM="XX"` to
  `/etc/conf.d/wireless-regdom`. The original idea was `cfg80211.ieee80211_regdom` on
  the UKI command line; the spike found `wireless-regdb` already ships a udev rule that
  runs `set-wireless-regdom` (which sources that file and calls `iw reg set`) whenever
  `cfg80211` loads, so the package's own primitive wins and `configure_boot` stays
  untouched. `wireless-regdb` is **not** a dependency of `linux-firmware`, so it goes in
  `packages/network.txt`. Intel cards that are self-managed may still ignore the hint --
  checked with `iw reg get` on the Alienware.
- `NetworkManager-wait-online.service` masked at install (**spike 1**: `systemctl enable
  NetworkManager` links it into `network-online.target`, which holds boot for anything
  ordered after the network).
- Numbering (mine): this is Phase 17; the update pipeline is Phase 18.

**Where each piece of knowledge lives (DRY)**

| Knowledge | Single home |
|---|---|
| The `.nmconnection` format (escaping, `psk-flags=0`, never `permissions=`) | `keyfile_for()` in `gui/installer/wifi.py`. Escape rules (verified against a real NetworkManager 1.58.1, spike 1): `\` -> `\\`, tab/newline/CR -> `\t` `\n` `\r`, a leading or trailing space -> `\s`; nothing else needs escaping (`;` `#` `"` `=` `[` and Unicode round-trip unchanged) |
| Live-to-target hand-off | a generic copy of whatever the live session saved (`copy_network_profiles`); no format knowledge |
| Connectivity-check override | `system/networkmanager/20-connectivity.conf`; the ISO's airootfs copy is byte-identical, enforced by a `cmp` test (a symlink out of the profile would dangle in the ISO) |
| Country-from-timezone | one `configure_regdom()` step in `configure-base-system`, writing `/etc/conf.d/wireless-regdom` (the country lookup is a small helper over `zone.tab`) |
| Network menu entry point | `home/network/dot-local/bin/network-menu` (`network-menu` = picker, `network-menu edit` = editor); Waybar clicks and the keybinding all call it |
| Bar palette | the matugen `waybar.css` template (gains `@define-color error`) |

**Open**
- [ ] Spikes 4 and 5 (need a compositor / a booted ISO) may still change the bar wiring and
      the live-session hand-off; the `networkmanager-dmenu` password prompt under fuzzel
      is confirmed on the first ISO boot.

## Spikes (run before any code; results recorded here)

Spikes 1-3 run 2026-09-20 in an Arch container (NetworkManager 1.58.1).

1. **NetworkManager enable side effects and keyfile acceptance -- done.**
   - `systemctl --root=X enable NetworkManager.service` creates three links: the service,
     the dispatcher alias, **and `network-online.target.wants/NetworkManager-wait-online`**
     -> mask it at install.
   - A real NetworkManager daemon (containerised, keyfile plugin) loads a hand-written
     profile only when it is `0600 root` (a `0644` file is ignored, as the docs say).
   - Written **raw**, values were silently mangled: a backslash in an SSID turned into a
     space (`\s` is an escape), a password with backslashes came back empty, and leading
     spaces were trimmed. With the escape rules above all 16 round-trip cases pass,
     unchanged: plain, `;`, `1;2;3`, `#`, backslashes (including a trailing one and one
     followed by `s`/`t`), Unicode, leading/trailing/internal spaces, tab, quotes, `[..]`,
     `=`, a 32-character SSID with a 63-character password. That oracle becomes the golden
     fixtures for `keyfile_for()`. (Only UTF-8 text SSIDs are supported in v1.)
   - Live `nmcli -t` scan output can't be produced without a radio; its fixtures follow
     the escaping documented in the `nmcli` man page and are re-checked on hardware.
2. **Packages -- done.** `networkmanager-dmenu` 2.6.3 and `nm-connection-editor` 1.36.0 are
   both in `extra` (60 KiB and 4.5 MiB), so the offline builder's official-package closure
   picks them up with no AUR step; dependencies are `python-gobject`/`libnm` and
   `libnma`/`jansson`. `networkmanager-dmenu` reads `~/.config/networkmanager-dmenu/config.ini`;
   `[dmenu] dmenu_command = fuzzel` is a supported launcher; it has a "launch
   nm-connection-editor" entry; passwords go through pinentry, the launcher itself
   (`[dmenu_passphrase]`), or nmcli. **Settled by reading the source (Step 5):** the
   package's `networkmanager_dmenu` supports fuzzel natively (`--dmenu --placeholder` for
   the list, `--password` for the passphrase) -- but only passes `--password` when
   `[dmenu_passphrase] obscure = True`, whose default is `False`, so without it the Wi-Fi
   password would be shown in plain text; the shipped config sets it and a test pins it.
   `pinentry` is not needed and not added. Still to confirm on the first ISO boot: hidden
   networks through the picker.
3. **Regdom -- done; changed the design.** `wireless-regdb` (in `core`, depends on `bash`
   and `iw`) is *not* pulled in by `linux-firmware`, so it must be listed. Its udev rule
   runs `set-wireless-regdom` on `cfg80211` load, which sources `/etc/conf.d/wireless-regdom`
   and runs `iw reg set`; that file ships with all 182 countries commented out. `zone.tab`
   is tab-separated `CC  coordinates  TZ  comment`, one country per zone (`zone1970.tab`
   has comma lists, so it is not used); `UTC` has no entry, so it correctly yields none.
   Still to check on the Alienware: `iw reg get` (a self-managed Intel card may ignore it).
4. Waybar -- **partly done.** Run for real under a headless Sway with the repo's config,
   stylesheet and a palette from the real matugen: it stays up, no CSS errors, the
   `network` module comes up, and `battery` logs "No batteries." and stays inert (so it is
   safe on a desktop VM). **Still pending, hardware only:** `format-disabled` firing on an
   rfkill block, and the Nerd Font Wi-Fi glyphs rendering.
5. Live boot in a VM: NetworkManager starts, the override is honoured, a root process
   under `cage` can add and activate a connection with no polkit or keyring,
   `copytoram` doesn't disturb `/etc/NetworkManager`. **Pending** -- needs a booted ISO.

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
| `configure-base-system`: saved profiles copied at mode 600 root, byte-identical, none = no error; `TZONE=America/New_York` writes `WIRELESS_REGDOM="US"` to `/etc/conf.d/wireless-regdom`, `UTC` and unknown zones write nothing, `/etc/kernel/cmdline` untouched; `NetworkManager-wait-online.service` masked; connectivity drop-in installed | The installed laptop autoconnects; regdom only when known; boot isn't held for a network that isn't there |
| `network-menu` dispatch: no argument -> `networkmanager_dmenu`, `edit` -> `nm-connection-editor` | Roles, not hardcoded executables |
| acceptance: `.network` has `on-click`, `on-click-right`, `format-disabled`, `format-disconnected`, a `format-icons` array of >= 4; `battery` in `modules-right`; CSS state selectors; `@define-color error`; `wifi` page sits between LanguageRegion and Account; influences entry present | The bar and installer wiring hold together |

Red confirmed: | Green confirmed: |

## Tasks

- [ ] Branch, tracking doc, roadmap row, backlog item (this commit)
- [x] Spikes 1-3, results logged (containerised NetworkManager, packages, regdb)
- [ ] Spikes 4-5 (need a compositor / a booted ISO) -- on the first ISO boot
- [x] Step 1 -- live ISO to NetworkManager (red, green)
- [x] Step 2 -- `gui/installer/wifi.py` and `gui/tests/test_wifi.py` (red, green)
- [x] Step 3 -- `Answers`, Wi-Fi page, Review row, demo backend (red, green)
- [x] Step 4 -- target side: profile copy, connectivity drop-in, regdom, wait-online mask, wireless-regdb (red, green)
- [x] Step 5 -- Waybar `network`/`battery`, `network-menu`, keybinding, matugen `error` colour, theme migration (red, green)
- [x] Step 6 -- `phase-17.bats`, runbooks, influences entry, decisions D-0068 to D-0072, roadmap
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

### 2026-09-20 (implementation)
- **Step 1 -- live ISO on NetworkManager (green).** Red first: the phase-17 static tests
  and the updated phase-12 wants assertion failed, then passed. `iwd` and `dhcpcd` are
  removed (a second manager would fight NetworkManager), the connectivity override ships
  in the live airootfs -- checked against a real NetworkManager, the same-named `/etc`
  file replaces Arch's shipped one and leaves `enabled=false` with no URI -- and the
  terminal-fallback banner now says `nmtui`. `tests/helpers/common.bash` gained
  `is_symlink`, which falls back to the git index because this repo's symlinks are
  flattened to plain files in a Windows checkout.
- **Step 2 -- `gui/installer/wifi.py` (green).** 43 new tests (red = the module did not
  exist), all passing first time. Then the check that matters: the *production*
  `keyfile_for()` output for all 16 awkward SSID/password cases was fed to a real
  NetworkManager 1.58.1 and every `id`, `ssid`, `psk`, `psk-flags=0` and `key-mgmt`
  came back exactly. Design points settled while writing it: one fixed profile file
  (`autarchy-wifi.nmconnection`) so no file name is built from a user-typed SSID and
  joining another network replaces the first; the profile is written 0600 under any
  umask and tightened if it already existed looser; a file NetworkManager silently
  ignores is detected after the reload; a failed join deletes the profile (a wrong
  password must not stay to autoconnect-loop or reach the installed system); the
  passphrase is scrubbed from every error message and never in any argv element; WPA
  passphrases follow NetworkManager's own rule (8-63 printable ASCII, or 64 hex).
  `nmcli` failure wording (wrong password / not found / timeout) is matched from its
  documented messages and is re-verified on real hardware.
- **Step 3 -- state, page, demo backend (green).** `Answers.wifi_ssid` is display-only
  (tests: never in the vars file, no password field can exist). `--dry-run` has no radio,
  so the page runs against `wifi_demo.demo_backend()` -- the *real* `WifiBackend` over
  canned `nmcli` answers, not a second implementation, so the page exercises the same
  parsing, profile writing and error mapping as on hardware. The GTK page is thin
  (`pages/wifi.py`): scan on a worker thread, signal-sorted rows with lock icons and
  unescaped SSIDs, enterprise rows greyed out, password row with the built-in show/hide,
  "Join a hidden network", spinner, inline errors, rfkill button, Forget, Skip. It is
  registered between LanguageRegion and Account, and Review shows the network or
  "skipped". Because GTK code can't be unit-tested here, the *real* page was run under a
  virtual display against the demo backend (`gui/tests/smoke_wifi_page.py`, kept as a
  documented dev tool CI does not run): 22 checks -- and it paid for itself. Reading the
  page back found a real flaw that no unit test could: the installer keeps one saved
  connection, so a *failed* second attempt deletes the first, yet the page went on saying
  "Connected to HomeNet" while nothing was saved. Fixed (a failure clears the recorded
  network) and the smoke test now covers it.
- **Step 4 -- the installed system (green).** `configure-base-system` gains three small
  steps and one line: `copy_network_profiles` (a plain copy of whatever `*.nmconnection`
  files the live session saved, 0600 root, into the target -- it knows nothing about the
  format, and "nothing saved", the common case, is not an error); `configure_regdom`
  (country from the target's `zone.tab`, written to wireless-regdb's own
  `/etc/conf.d/wireless-regdom`, replacing any earlier line so a re-run or a changed
  timezone never leaves two; skipped if the package's file is absent; `configure_boot`
  and the kernel command line are untouched); and `systemctl mask
  NetworkManager-wait-online.service` *after* the enable (enabling a masked unit fails).
  `system/networkmanager/20-connectivity.conf` is the one source for the connectivity
  override, installed by `sync-system`, with the live ISO's copy kept byte-identical by an
  acceptance test. `wireless-regdb` joins `packages/network.txt`. Beyond the stubs: the
  real function bodies were run on the real package-shipped file and wireless-regdb's own
  `set-wireless-regdom` turned the result into `iw reg set US` (and UTC wrote nothing).
  One of my own tests was wrong, not the code (it `find`ed a directory the implementation
  deliberately does not create when nothing is saved) and was corrected.
- **Step 5 -- the bar and the menu (green).** `home/network/` is a new stow package:
  `network-menu` (no argument = the picker, `edit` = the settings window; Waybar's two
  clicks and `SUPER+CTRL+N` all call it, never the tools) and the
  `networkmanager-dmenu` config. Waybar's `network` module now shows one of five signal
  icons plus distinct cable / cable-without-an-address / not-connected / radio-off icons,
  with the name and details in the tooltip, refreshing every 5 s; a `battery` module
  (warning 30, critical 15) joins the right side; the stale "no battery" header comment is
  gone. `#network.disconnected` and `#battery.*` are styled with a new `@error` in the
  matugen template. Two things beyond the plan turned up: **(1)** reading the
  `networkmanager_dmenu` source showed fuzzel's `--password` masking is applied only when
  `[dmenu_passphrase] obscure = True` -- its default is `False`, which would have shown
  the Wi-Fi password in plain text -- so the config sets it and a test pins it; **(2)** a
  machine themed before this has a `colors.css` with no `@error`, and a stylesheet naming
  an undefined colour fails to load, so a migration
  (`migrations/*-rerender-theme-for-waybar-error-color.sh`, idempotent, skipped on a
  never-themed machine) re-renders the palette; a test also checks that every colour
  `style.css` uses is defined by the template, so this can't recur silently. Beyond the
  static tests, the *real* Waybar was run under a headless Sway with the repo's config and
  stylesheet and a palette rendered by the real matugen: it stays up (10 s, no crash),
  reports no CSS errors, brings the `network` module up, and `battery` logs "No batteries."
  and stays inert -- **spike 4's battery question is answered.** (The unrelated
  `wireplumber` module segfaults without PipeWire in a bare container, so it was left out of
  that run; the only other error was the container having no `/dev/rfkill`.) Still for real
  hardware: `format-disabled` on an rfkill block, and the Nerd Font glyph rendering.
- **Deviation from the plan:** Next is held with "Still connecting" while a join is in
  flight, rather than never blocked -- a result landing after the install has started
  could delete the file being copied. Skipping with nothing joined is unaffected. A
  "Forget" button was added (the backend already had `forget()`), so a joined network can
  be undone before installing.

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

### 2026-09-20 (first hardware boot: "Wi-Fi is switched off by a hardware switch")
- **Symptom.** `autarchy-local-c4f55d5` on the Alienware 14 (P39G): the Wi-Fi page said the
  radio was switched off by a hardware switch, and the F2 key (which carries a Wi-Fi symbol)
  did nothing however it was combined (F2, Shift/Alt/Fn/Super+F2). The live session had no
  terminal to investigate with.
- **Two read-only investigations** (our code and the live ISO's tooling; the hardware and
  Linux rfkill research), then a container check to settle the one point they disagreed on.
  Findings, in order of certainty:
  1. **A defect in our code.** `radio_state()` treated every `WIFI-HW` value other than
     `enabled` as a hard block. A real NetworkManager 1.58.1 in a container with no Wi-Fi
     device prints `missing:enabled` (exit 0), so "no adapter visible to the OS" was reported
     as "hardware switch" -- possibly the very message seen. It had only ever been tested
     with a fake runner and four invented fixtures, never real `nmcli` output.
  2. **A dead end.** The page hid the network list *and* the "Turn Wi-Fi on" button on a hard
     block, named no device, offered no next step, and only re-read on a click; and the live
     session offered no way to look (`cage` has no VT switching; `iw`, `lspci`, `lsusb` and
     `evtest` were not on the ISO; `system-report` collected nothing about Wi-Fi).
  3. **The hardware (sources; two items inferred).** The P39G's adapter is the Qualcomm Atheros
     Killer Wireless-N 1202 = AR9462 (PCI 168c:0034, in-tree `ath9k`, Bluetooth on the same
     card). Its BIOS has *Advanced > Function Key Behavior* and a *Wireless* menu (Wireless
     Network, Wireless Switch/Hotkey); the owner's manual says "Wireless Network: Disabled"
     makes the device invisible to the OS; a Dell community report of an Alienware 14-R1 whose
     Fn+F2 did nothing was fixed through Function Key Behavior. `dell-laptop` probably never
     binds (vendor "Alienware"), so a genuine hard block would be the adapter's own rfkill
     line held by the embedded controller; Fn+F2 there is typically handled in firmware and may
     send the OS no event at all. Whether this machine is a real hard block or a missing
     adapter is decided by the new page's Details, not assumed.
- **Fixed (red first, D-0073).** Explicit radio classification with a new `NO_ADAPTER` state
  and `UNKNOWN` for anything unrecognised; commands run under `LC_ALL=C`; a GTK-free
  `wifi_diagnostics` module (fake-sysfs tests) whose facts and per-state messages the page
  shows -- the blocking device and driver, or the adapter found with/without a driver, or that
  none was found -- with a Details section and auto-recheck that notices a change without a
  click and stops when the page leaves the screen. The real GTK page was driven under a
  virtual display through hard block, recovery, no adapter, no driver, unknown and soft block
  (37 checks). The live ISO gained `iw`, `pciutils`, `usbutils`, `evtest`; `autarchy.nogui` on
  the kernel command line skips the GUI and leaves a terminal on tty1 (documented in
  `base-install.md`); `scripts/system-report` gained a Wi-Fi section reusing the same module.
- **For the user, before the new ISO** (no code): in the BIOS set *Function Key Behavior* to
  function-key-first and check the *Wireless* menu (Wireless Network / Wireless Switch/Hotkey
  enabled); power-cycle the embedded controller (shut down, unplug AC, hold the power button
  ~30 s); then try Fn+F2. On the new ISO the page names what it finds.

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
