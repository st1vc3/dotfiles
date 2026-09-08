-- Neovim 0.11+ ships an LSP client, so no plugin is required: a server is a
-- command plus the filetypes and root markers it attaches to.
--
-- The binaries are declared in modules/home/development.nix and resolved from
-- PATH rather than by store path, so this file stays a plain portable config.
-- Anything not installed is skipped, which keeps a bare checkout (and CI's
-- headless start) quiet instead of reporting a server that failed to spawn.

local servers = {
  lua_ls = {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.stylua.toml', '.git' },
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        -- hs is Hammerspoon, Snacks is set up by snacks.nvim.
        diagnostics = { globals = { 'vim', 'hs', 'Snacks' } },
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
      },
    },
  },
  nil_ls = {
    cmd = { 'nil' },
    filetypes = { 'nix' },
    root_markers = { 'flake.nix', '.git' },
  },
  bashls = {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'sh', 'bash' },
    root_markers = { '.git' },
  },
}

local enabled = {}
for name, config in pairs(servers) do
  if vim.fn.executable(config.cmd[1]) == 1 then
    vim.lsp.config(name, config)
    enabled[#enabled + 1] = name
  end
end

if #enabled > 0 then
  vim.lsp.enable(enabled)
end
