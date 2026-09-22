# Phase 17 — Wi-Fi at install, and an interactive network bar

| | |
|---|---|
| **Status** | Complete (2026-09-21) |
| **Driver** | Claude + user |
| **Branch** | `phase/17-wifi-network-bar` (carries Phase 16's later commits too; both merged from it) |
| **Started** | 2026-09-20 |
| **Completed** | 2026-09-21 |

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
- Docs, decisions D-0068 to D-0077, an Omarchy-influences entry for network/Wi-Fi UI.

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

**Open** (closed 2026-09-21)
- [x] Spikes 4 and 5: the bar wiring held on hardware (spike 4); the live-session
      hand-off (spike 5) could not be exercised on this laptop -- the live ISO has no
      driver for its card -- and stays unit/smoke-verified; the password prompt under
      fuzzel works on the installed machine (masked, D-0071).

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

- [x] Branch, tracking doc, roadmap row, backlog item
- [x] Spikes 1-3, results logged (containerised NetworkManager, packages, regdb)
- [x] Spikes 4-5 -- see Decisions/Open
- [x] Step 1 -- live ISO to NetworkManager (red, green)
- [x] Step 2 -- `gui/installer/wifi.py` and `gui/tests/test_wifi.py` (red, green)
- [x] Step 3 -- `Answers`, Wi-Fi page, Review row, demo backend (red, green)
- [x] Step 4 -- target side: profile copy, connectivity drop-in, regdom, wait-online mask, wireless-regdb (red, green)
- [x] Step 5 -- Waybar `network`/`battery`, `network-menu`, keybinding, matugen `error` colour, theme migration (red, green)
- [x] Hotfixes -- diagnosing a blocked or missing radio (D-0073) and the PCI-ID hardware map with the Broadcom driver (D-0074), red then green
- [x] Step 6 -- `phase-17.bats`, runbooks, influences entry, decisions D-0068 to D-0074, roadmap
- [x] Build an ISO locally (`scripts/build-iso`): the Phase 16 local builds and, on the
      Alienware, the `sudo podman` spike (rootless podman cannot mount the chroot)
- [x] Real hardware (installed machine, via dev-deploy): icon states, left/right click, `SUPER+CTRL+N`, battery, toasts, autoconnect after reboot, `dell_rbtn` blacklist on all three boot entries; the Wi-Fi *page* cannot join on this laptop (no `wl` on the live ISO -- it says so) and is smoke-test-verified
- [ ] **Owed, on a second machine:** a fresh install from an ISO with all of this -- the
      Wi-Fi page joins (on a card the live ISO has a driver for), the profile lands `0600
      root` and autoconnects on first boot. On the Alienware the page correctly says the
      driver comes with the installed system (D-0074); the rest is confirmed above.
- [x] Hotfix -- the picker asked for SAE on a WPA2/WPA3 network (D-0077), red then green
- [x] Close: decisions, influences, roadmap, merge (together with Phase 16, on this branch)

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
  (`symphony-wifi.nmconnection`) so no file name is built from a user-typed SSID and
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

- **`pacman-filesdb-refresh.service` fails when its timer fires before Wi-Fi is up**
  (seen on the Alienware's first boot of the day: `Could not resolve host`), leaving
  the system `degraded` until the next run. The unit has no network ordering and
  `NetworkManager-wait-online` is masked (D-0068). Fix candidates: a drop-in with
  `After=network-online.target` plus unmasking wait-online for that unit only, or
  `Restart=on-failure` with a delay. Belongs with Phase 9's timers.

- **Validate the hibernation swap size.** Found on hardware round 2 of Phase 16: a
  malformed swap size typed on the Disk page reached `sgdisk`, which failed with
  "Could not create partition 2 ... Unable to set partition 2's name to cryptswap" --
  an error that says nothing about the cause (the failure itself was a typo). Fix:
  validate in `gui/installer/state.py` (GTK-free, unit-tested: a whole number plus
  `K/M/G/T`; reject spaces, `GB`/`GiB`, zero, empty units), block Next on the Disk
  page with a clear message, mirror it in the terminal fallback `symphony-install`,
  and have `install-base-system`'s preflight reject a bad or larger-than-the-disk
  `SWAP_SIZE` before anything destructive runs. Red tests first; small enough to
  bundle into whichever phase next touches the installer.

### 2026-09-20 (first hardware boot: "Wi-Fi is switched off by a hardware switch")
- **Symptom.** `symphony-local-c4f55d5` on the Alienware 14 (P39G): the Wi-Fi page said the
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
  3. **The hardware (sources; two items inferred).** *(Wrong on one point, corrected below: the
     research named the adapter as the Qualcomm Atheros Killer Wireless-N 1202 / AR9462 --
     this unit's is a Broadcom BCM4352.)* The BIOS has *Advanced > Function Key Behavior*
     and a *Wireless* menu (Wireless
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
  (37 checks). The live ISO gained `iw`, `pciutils`, `usbutils`, `evtest`; `symphony.nogui` on
  the kernel command line skips the GUI and leaves a terminal on tty1 (documented in
  `base-install.md`); `scripts/system-report` gained a Wi-Fi section reusing the same module.
- **For the user, before the new ISO** (no code): in the BIOS set *Function Key Behavior* to
  function-key-first and check the *Wireless* menu (Wireless Network / Wireless Switch/Hotkey
  enabled); power-cycle the embedded controller (shut down, unplug AC, hold the power button
  ~30 s); then try Fn+F2. On the new ISO the page names what it finds.

### 2026-09-20 (second hardware boot: what the new Details showed)
- **The page now reported:** "A Wi-Fi adapter `14e4:43b1`, driver `bcma-pci-bridge`, was found but
  the system can't use it", and `rfkill dell-rbtn (wlan): hard-blocked`, `hci0 (bluetooth):
  not blocked`. Two separate problems, and **my hardware research was wrong about the adapter**
  (it named an Atheros Killer 1202; this unit has a Broadcom BCM4352 -- corrected in D-0073).
- **Problem 1 -- no driver.** `14e4:43b1` is a BCM4352. Nothing open supports it (`b43` predates
  802.11ac, `brcmfmac`'s ID table lacks it, `bcma-pci-bridge` only enumerates the chip's cores),
  so no Wi-Fi interface ever appears and NetworkManager prints `missing`. Only the proprietary
  `wl` (`broadcom-wl-dkms`) works; the precompiled `broadcom-wl` no longer exists in Arch. Checked
  for real: it builds against `linux` 7.2.6 and `linux-lts` 6.18.52; in a real `pacstrap` of
  base plus both kernels plus the hardware packages (one transaction, like the installer's) DKMS
  built `wl` for both inside the new system, and the package ships its own modprobe blacklist.
- **Built (D-0074, red first):** `system/hardware.txt` (PCI ID -> package list),
  `packages/hardware/broadcom-wl.txt`, `scripts/hwpkglist` (12 bats tests, fails closed),
  `install-base-system` resolving and adding the packages before anything destructive,
  `iso/build-offline-repo` baking every hardware list into the offline repo, `pkg-audit` treating
  them as declared-but-optional, and the Wi-Fi page reading the same map (`hardware_map.py`) to
  say "your adapter needs a driver that comes with the installed system, so Wi-Fi will be
  available after the first boot" instead of "check the BIOS". User decisions (asked): ship it
  only when the chip is present; the live session just explains; test `dell-rbtn` before shipping
  a fix. One real smoke-test flake (1 run in 3) was traced to a fixed 700 ms sleep in the test
  itself and replaced with a wait for the condition (6 stable runs).
- **Problem 2 -- `dell-rbtn`, still open.** It registers an rfkill only for a firmware-reported
  airplane-mode *slider*; the state is whatever the BIOS returns and software cannot change it,
  and NetworkManager takes the worst state across all Wi-Fi rfkill devices, so it would keep
  Wi-Fi off even with the driver. Other Alienware owners (13 R3, 15 R2) and several Inspiron
  owners cleared it by blacklisting `dell_rbtn` (or, on the 15 R2, `acpi_osi="!Windows 2012"`);
  nothing confirms either for the 14 and no source shows `modprobe -r` clearing it live. **Waiting
  on the user's test** from `symphony.nogui`: `grep -H . /sys/class/rfkill/rfkill*/{name,hard,soft};
  modprobe -r dell_rbtn; rfkill list`, then the result decides between a DMI-gated blacklist and the
  `acpi_osi` parameter.
- **Problem 2 result: `modprobe -r dell_rbtn` clears the hard block** (user's test on the
  installed system, `wl` loaded: `dell-rbtn` was hard *and* soft blocked, removal made Wi-Fi
  work) -- but it does not survive a reboot, because nothing stops udev loading the module again.
- **Problem 3 -- the picker scanned and saved but never connected** (found on the installed
  machine; `nmcli --ask device wifi connect` worked and Chromium then browsed). Planned in plan
  mode after a repo investigation and research (fuzzel's dmenu semantics, networkmanager-dmenu's
  source and history, how GNOME/KDE/Windows/macOS show connecting, module-blacklist mechanics).
  Leading hypothesis when planned: `[dmenu] exit-immediately-if-empty=yes` in the fuzzel template
  closes networkmanager-dmenu's empty-list password prompt. **Refuted on the machine:** `~/.config/fuzzel/`
  does not exist there (fuzzel 1.15.0 runs on defaults), so that setting was never active. It stays
  fixed as a latent defect; the real cause is open. User decisions (asked): fix in place
  plus a feedback wrapper (not an own nmcli script, not nm-applet); the `dell_rbtn` blacklist for
  this model only, by DMI; toasts plus an honest tooltip, no new bar module.
- **Built (D-0075, red first):** the fuzzel template drops the setting, with a guard test and a
  migration for machines themed before (`1789937867-rerender-fuzzel-without-exit-if-empty.sh`, 3
  bats tests); `home/network/dot-local/bin/network-watch` (15 bats tests: connect, wrong password on
  a new profile deletes it, on an existing one never, fast failure, cancel, switching networks,
  timeout, colon in a name, no Wi-Fi device, no `notify-send`, never asks for secrets, a new
  Ethernet profile is never touched); `network-menu` snapshots, runs the picker, then the watcher
  (5 bats tests); Waybar's linked tooltip reworded.
- **Built (D-0076 mechanism, red first):** `system/quirks.txt` (DMI pattern -> kernel parameter),
  `scripts/quirkparams` (12 bats tests, fails closed, mirrors `hwpkglist`), `install-base-system`
  resolving the parameters before anything destructive, `configure-base-system` appending them to
  `/etc/kernel/cmdline` before the UKIs are built. The Alienware 14 entry is in the map; it is
  unproven until the cold-boot test below passes.
- **From the machine:** `sys_vendor` = `Alienware`, `product_name` = `Alienware 14`; `~/.config/{matugen,
  networkmanager-dmenu,waybar}` exist, `~/.config/fuzzel` does not (why matugen did not render
  `fuzzel.ini` is a second open question). The quirk entry is `dmi:*:svnAlienware:pnAlienware*14:*`.
- **Waiting on the machine:** (1) why the picker does not connect: needs the saved profile,
  `nmcli connection show` and NetworkManager's journal, ideally read directly (the user cannot
  copy and paste between the two machines, which argues for running Claude on the laptop);
  (2) the cold-boot test: `module_blacklist=dell_rbtn` in `/etc/kernel/cmdline` + `mkinitcpio -P` +
  reboot: is `dell_rbtn` gone from `lsmod` and WIFI-HW `enabled` with no manual step, on all three boot entries?

### 2026-09-20 (from the machine: Claude Code now runs on the Alienware)
- **Problem 3 established (D-0077).** The journal answered it in one read: the picker *did*
  `connection-add-activate` the 5 GHz network, with `key_mgmt SAE`; the supplicant could not
  select it on `wl`, association timed out, the activation failed as `ssid-not-found` and
  autoconnect retried the same failure on every boot (12 attempts, none succeeded). The 2.4 GHz
  profile that works is `wpa-psk` -- made by `nmcli --ask`, which lets the daemon choose.
  `/usr/bin/networkmanager_dmenu:1275` hard-codes `sae` for any AP advertising WPA3, transition
  mode included, and NetworkManager's `WIFI-PROPERTIES` for the BCM4352 lists no WPA3 at all.
  Not fuzzel (D-0075's fix stays as a latent defect), not the password, not `network-menu`.
  A second, unrelated failure in the same journal -- `psk mismatch` then `no secrets: No agents
  were available` -- is the expected shape of a wrong saved password in a session with no secret
  agent; `network-watch`'s "forget the network" toast is the right answer to it.
- **Fixed, red first:** `home/network/dot-local/bin/network-picker` loads the upstream script as
  a module and rebinds `create_wifi_profile` so a network that also offers PSK gets `wpa-psk`
  (`sae` only when it is the sole offer -- nmcli's rule and `classify_security`'s);
  `network-menu` calls it; 8 bats tests against a fake upstream (transition, WPA3-only,
  WPA2-only, WPA1+WPA3, open, argv pass-through, fail-closed on a renamed function, missing
  script); the real libnm path checked by hand (upstream `sae` -> patched `wpa-psk`, `verify()`
  true, PSK intact). `scripts/check` splits `dot-local/bin` by shebang so the Python script is
  parsed with `ast` (not `py_compile`, which leaves a `__pycache__` that stow would link and
  shellcheck would choke on -- it did, once). A red test briefly launched the *real* picker
  because the upstream stub had been renamed; the menu tests now stub both names and assert the
  upstream is never called directly.
- **D-0077 confirmed on the hardware** (after deploying the checkout, `local-ac75631`, and
  deleting the dead `sae` profile): left-click on the icon and `SUPER+CTRL+N` both open the
  picker; picking `Accio Internet_5G` logged `connection-add-activate` with
  `key_mgmt WPA-PSK WPA-PSK-SHA256`, the 4-way handshake completed and the device activated on
  5500 MHz. The saved profile is `wpa-psk`, `psk-flags=0`, no `permissions=`, autoconnect on;
  the journal has no trace of the passphrase. User-confirmed on the desktop: the
  Connecting/Connected toasts appeared, the hover tooltip shows the network details,
  right-click opens `nm-connection-editor`, the battery indicator is there. Still to see:
  `format-disabled` on an rfkill block, autoconnect after a reboot (the cold-boot test below
  covers it), and the Nerd Font glyphs -- the user reads the bar, so those are confirmed by
  the same look.
- **Why there was no bar to click:** Phase 16's `first-login` had never run on this machine
  (Hyprland ate the `[ -x ]` guard as exec rules -- see that phase's log). The bar, the theme
  and `fuzzel.ini` all arrive with the deploy of this checkout (`docs/runbooks/dev-deploy.md`).
- **`dell_rbtn` today:** loaded, but *unblocked* on this boot (the three earlier boots were
  hard-blocked; the user pressed Fn+F2 and power-cycled the EC in between, unsure which counted).
  The slider is firmware state that persists across boots and can be toggled; the blacklist stays
  the right defence, its cold-boot proof still owed.
- **`dell_rbtn` cold-boot proof done (D-0076 written).** `module_blacklist=dell_rbtn` appended to
  `/etc/kernel/cmdline` by hand (the install predates the quirk map), `mkinitcpio -P`, then
  three reboots: `arch-linux` (7.2.6), `arch-linux-lts` (6.18.52) and
  `arch-linux-lts-fallback` -- each logged `Module dell_rbtn is blacklisted`, had no
  `dell_rbtn` in `lsmod`, only `phy0`/`hci0` in `rfkill list`, "Wi-Fi enabled by radio
  killswitch", and autoconnected to the 5 GHz network. That also closes the autoconnect-after-
  reboot check. The fresh install from the next ISO proves the map itself produces the line.
- **Kernel warnings from `wl`** at every boot ("Unpatched return thunk in use", a `memcpy`
  field-spanning write in `wl_cfg80211_hybrid.c`), kernel tainted `P S W IOE`. Known
  broadcom-wl-dkms noise on current kernels; Wi-Fi works. Recorded for the hardware doc.

## VM → physical hardware notes

- A VM has no real radio: the unit tests use a fake command runner and recorded
  `nmcli` fixtures, and `--dry-run` uses a fake Wi-Fi backend. Real association,
  signal strength, rfkill, regulatory behaviour and battery can only be verified on
  the Alienware. That is also where the keyring-less session matters: profiles must
  be system-owned (`psk-flags=0`) or they will not autoconnect in a bare Hyprland
  session, and profiles created later in `nm-connection-editor` must be "available to
  all users" -- verify by rebooting and checking it reconnects.

## Exit criteria

- [x] All acceptance tests pass (full suite 204/204 on the Alienware, 2026-09-21)
- [x] Static checks pass (`scripts/check`, 266 unit tests, 92 GUI tests)
- [x] `DECISIONS.md` updated (D-0068 to D-0077)
- [x] `docs/omarchy-influences.md` updated
- [x] `docs/roadmap.md` status updated
- [x] Branch merged to `main`
