#!/usr/bin/env bats
# Unit tests for home/hypr/dot-config/hypr/keymap/notation.lua (Task C, #21).
#
# Two chords that mean the same key must compare equal, or a user override silently
# adds a second binding instead of replacing the default -- writing `super+return`
# when the default says `SUPER + Return` has to win, not duplicate.
#
# Pure Lua, run under /usr/bin/lua (5.5.1, the same build Hyprland links), so no
# compositor is involved.

setup() {
  load '../helpers/common'
  # The same package.path Hyprland gives a config, so `require` resolves exactly
  # as it will in production.
  HYPR="$REPO_ROOT/home/hypr/dot-config/hypr"
}

# Evaluate a Lua expression with the keymap modules importable.
lua_eval() {
  lua -e "package.path = '$HYPR/?.lua;' .. package.path; local n = require('keymap.notation'); $1"
}

canonical() {
  lua_eval "print(n.canonical([[$1]]))"
}

format() {
  lua_eval "print(n.format([[$1]]))"
}

@test "case does not matter: a user writing lower case still overrides the default" {
  run canonical "super + return"
  local lower="$output"
  run canonical "SUPER + Return"
  assert_output "$lower"
}

@test "modifier order does not matter" {
  run canonical "SHIFT + SUPER + Q"
  local one="$output"
  run canonical "SUPER + SHIFT + Q"
  assert_output "$one"
}

@test "spacing does not matter" {
  run canonical "SUPER+SHIFT+Q"
  local tight="$output"
  run canonical "  SUPER  +  SHIFT  +  Q  "
  assert_output "$tight"
}

@test "CONTROL and CTRL are the same modifier" {
  run canonical "CONTROL + V"
  local long="$output"
  run canonical "CTRL + V"
  assert_output "$long"
}

@test "different keys do not collide" {
  run canonical "SUPER + Q"
  local q="$output"
  run canonical "SUPER + W"
  refute_output "$q"
}

@test "the same key with different modifiers does not collide" {
  run canonical "SUPER + Q"
  local plain="$output"
  run canonical "SUPER + SHIFT + Q"
  refute_output "$plain"
}

@test "a bare key with no modifier works" {
  run canonical "XF86AudioMute"
  assert_success
  refute_output ""
}

@test "format keeps the key exactly as written, for Hyprland to match on" {
  # Keysyms are not uppercase: XF86AudioRaiseVolume must reach hl.bind intact.
  run format "super + XF86AudioRaiseVolume"
  assert_output "SUPER + XF86AudioRaiseVolume"
}

@test "format uppercases the modifiers and uses the separator hl.bind expects" {
  run format "shift+super+q"
  assert_output "SUPER + SHIFT + q"
}

@test "format of a bare key is just the key" {
  run format "XF86AudioMute"
  assert_output "XF86AudioMute"
}

@test "a code: binding survives, since Hyprland accepts those too" {
  run format "SUPER + code:20"
  assert_output "SUPER + code:20"
}
