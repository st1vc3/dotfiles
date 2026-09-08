-- Lua in this repository runs inside two embedded interpreters that inject
-- their own globals, so luacheck has to be told about them.
std = 'lua54'
max_line_length = false

-- vim is writable: config assigns through vim.g and vim.opt.
globals = { 'vim' }

read_globals = {
  'hs',     -- Hammerspoon
  'Snacks', -- set up by snacks.nvim
}

files['home/.hammerspoon/init.lua'] = {
  -- Hammerspoon collects anything not held by a global, so the hotkey, the
  -- overlay handle and the config watcher are deliberately global.
  globals = {
    'shortcutOverlayHotkey',
    'shortcutOverlay',
    'configWatcher',
  },
}
