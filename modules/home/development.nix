{ config, pkgs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  # Language servers for home/.config/nvim/lua/lsp.lua. Declared here rather
  # than brewed so flake.lock pins them, and resolved from PATH by the Lua
  # config so it stays portable.
  home.packages = [
    pkgs.bash-language-server
    pkgs.lua-language-server
    pkgs.nil
  ];

  home.file.".config/nvim".source = liveLink "home/.config/nvim";

  home.file.".config/herdr/config.toml".source = liveLink "home/.config/herdr/config.toml";

  home.file.".claude/settings.json".source = liveLink "home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source = liveLink "home/AGENTS.md";

  home.file.".codex/AGENTS.md".source = liveLink "home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source = liveLink "home/AGENTS.md";
}
