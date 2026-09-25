#!/usr/bin/env bats
# Phase 6 acceptance tests: visual system (fonts, icons, cursor, GTK/Qt, wallpaper).
#
# Two groups, same split as every prior phase. Static (this file's default): runnable
# over SSH, no graphical session needed. Live-session (tagged in each test name): needs
# an actual logged-in Hyprland session on seat0. Package installation and the generic
# Hyprland-config-validates/home-linking checks are already covered by phase-02.bats
# and phase-04.bats's tests (which iterate all of packages/desktop.txt and all of
# home/), so this file only adds Phase-6-specific checks, not duplicates.
#
# Run on the VM as the regular user, after `sudo -v`, together with phase-01..05:
#   bats tests/acceptance
# Red run: before this phase's implementation, where the static group must fail.

setup() {
  load '../helpers/common'
  load '../helpers/system'
}

# --- theming (matugen, wallpaper-driven) -----------------------------------------

@test "theming: matugen renders the GTK templates from an image seed" {
  local seed="$HOME/.local/state/symphony/wallpaper"
  run matugen --config "$HOME/.config/matugen/config.toml" image "$seed" --source-color-index 0
  assert_success
  assert [ -s "$HOME/.config/gtk-3.0/gtk.css" ]
  assert [ -s "$HOME/.config/gtk-4.0/gtk.css" ]
}

# --- fonts -------------------------------------------------------------------------

@test "fonts: fontconfig resolves monospace to JetBrainsMono Nerd Font" {
  run fc-match monospace
  assert_success
  assert_output --partial "JetBrainsMono"
}

# --- GTK/cursor static config --------------------------------------------------------

@test "gtk: settings.ini declares the chosen icon and cursor theme" {
  run cat "$HOME/.config/gtk-3.0/settings.ini"
  assert_success
  assert_output --partial "gtk-icon-theme-name=Papirus"
  assert_output --partial "gtk-cursor-theme-name=Bibata"
}

# --- wallpaper -----------------------------------------------------------------------

@test "wallpaper: the pointer resolves to a real file" {
  assert [ -s "$HOME/.local/state/symphony/wallpaper" ]
}

@test "wallpaper: the library is a Wallpapers folder in the pictures directory (D-0086)" {
  local library
  library="$(xdg-user-dir PICTURES)/Wallpapers"
  assert [ -d "$library" ]
}

@test "wallpaper: the old backgrounds directory is gone, library and state separated (D-0086)" {
  # It mixed the user's library, the pointer and a shipped asset in one place, and
  # wallpaper-random defaulted at it -- a folder no user ever fills.
  assert [ ! -e "$HOME/.local/share/backgrounds" ]
}

@test "wallpaper: hyprpaper.conf uses the current block-based wallpaper syntax" {
  # hyprpaper's config format changed to a `wallpaper { monitor = ...; path = ...; }`
  # block; the old flat `wallpaper = monitor,path` line is silently ignored by the
  # current version (confirmed live: it produced no error, but also no wallpaper --
  # `Monitor Virtual-1 has no target: no wp will be created` in the journal, and
  # `hyprctl hyprpaper listactive` was empty). This is a regression guard against
  # reintroducing that silent failure.
  run cat "$HOME/.config/hypr/hyprpaper.conf"
  assert_success
  assert_output --partial "wallpaper {"
  assert_output --partial "path ="
}

@test "wallpaper: hyprpaper.conf is generated, not a stow link (D-0085)" {
  # wallpaper-set rewrites it with the chosen image; a link into the payload would be
  # restored by every restow, freezing the picture.
  assert [ ! -L "$HOME/.config/hypr/hyprpaper.conf" ]
  run grep -qi generated "$HOME/.config/hypr/hyprpaper.conf"
  assert_success
}

@test "wallpaper: nothing drives hyprpaper over its runtime IPC any more (D-0085)" {
  # 0.8.4 accepts `hyprctl hyprpaper wallpaper ...` and silently ignores it.
  run grep -rn 'hyprctl hyprpaper' "$REPO_ROOT/home" "$REPO_ROOT/install" "$REPO_ROOT/scripts"
  assert_failure
}

# --- live-session (user, from Unraid's console, after logging into Hyprland) -------

@test "live-session: hyprpaper has an active wallpaper" {
  # listactive reports the resolved real path, which may be anywhere the user keeps
  # images (an SMB mount, say) -- so only that there is one.
  run hyprctl hyprpaper listactive
  assert_success
  refute_output ""
  assert_output --partial ": /"
}

@test "live-session: wallpaper-set changes the picture on screen, not only the palette" {
  # The palette alone is not the outcome: for a while this passed while hyprpaper kept
  # showing the payload's default.png, because the IPC it used had gone away (D-0085).
  # Assert what the user sees -- hyprpaper is showing the file we just set.
  local before after chosen
  chosen=$(realpath "$HOME/.local/state/symphony/wallpaper")
  before=$(stat -c %Y "$HOME/.config/waybar/colors.css" 2>/dev/null || echo 0)
  sleep 1
  run wallpaper-set "$chosen"
  assert_success
  after=$(stat -c %Y "$HOME/.config/waybar/colors.css" 2>/dev/null || echo 0)
  assert [ "$after" -gt "$before" ]
  run hyprctl hyprpaper listactive
  assert_output --partial "$chosen"
  run cat "$HOME/.config/hypr/hyprpaper.conf"
  assert_output --partial "path = $chosen"
}
