#!/usr/bin/env bats
# Unit tests for home/hypr/dot-config/hypr/keymap/userconfig.lua (Task C, #21):
# reading ~/.config/symphony/*.lua.
#
# The rule that matters: a broken user file must never cost a session. It is loaded
# with pcall, per file -- so a bad options.lua does not take keymap.lua with it -- and
# a failure returns an error for the caller to show rather than raising.
#
# Pure Lua under /usr/bin/lua: it reports the error, keymap.lua is what notifies.

setup() {
  load '../helpers/common'
  HYPR="$REPO_ROOT/home/hypr/dot-config/hypr"
  export SYMPHONY_CONFIG_DIR="$BATS_TEST_TMPDIR/symphony"
  mkdir -p "$SYMPHONY_CONFIG_DIR"
}

# Print "value-kind|error" for a named config file.
load_config() {
  lua -e "
    package.path = '$HYPR/?.lua;' .. package.path
    local uc = require('keymap.userconfig')
    local value, err = uc.load('$1')
    print(type(value) .. '|' .. tostring(err))"
}

write_config() {
  printf '%s\n' "$2" >"$SYMPHONY_CONFIG_DIR/$1.lua"
}

@test "a file that is not there is not an error: most machines have no overrides" {
  run load_config keymap
  assert_output "nil|nil"
}

@test "a file returning a table gives back that table" {
  write_config keymap 'return { global = { ["SUPER + Q"] = "window.close" } }'
  run load_config keymap
  assert_output "table|nil"
}

@test "a syntax error is reported, not raised" {
  write_config keymap 'return { global = '
  run load_config keymap
  assert_success
  assert_output --regexp "^nil\|.+"
}

@test "the error names the file, so it can be found and fixed" {
  write_config keymap 'return { global = '
  run load_config keymap
  assert_output --partial "keymap"
}

@test "a file that raises at load time is caught too, not only a syntax error" {
  write_config keymap 'error("deliberate")'
  run load_config keymap
  assert_success
  assert_output --regexp "^nil\|.+"
}

@test "a file returning something that is not a table is rejected with a reason" {
  write_config keymap 'return 42'
  run load_config keymap
  assert_success
  assert_output --regexp "^nil\|.+table.+"
}

@test "a file returning nothing at all is treated as no config, not as a failure" {
  # `-- just a comment` is a legitimate empty override, and the seeded file starts
  # that way: it must not raise an error toast on every login.
  write_config keymap '-- nothing here yet'
  run load_config keymap
  assert_output "nil|nil"
}

@test "one broken file does not stop another from loading" {
  write_config options 'return { broken'
  write_config keymap 'return { global = {} }'
  run load_config keymap
  assert_output "table|nil"
}
