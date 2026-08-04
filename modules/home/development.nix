{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.file.".config/nvim".source = liveLink "home/.config/nvim";

  # Only the durable config belongs in git. Herdr logs, sockets, release notes,
  # and session state remain ordinary files under ~/.config/herdr.
  home.file.".config/herdr/config.toml".source = liveLink "home/.config/herdr/config.toml";

  home.file.".claude/settings.json".source = liveLink "home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source = liveLink "home/AGENTS.md";

  home.file.".codex/AGENTS.md".source = liveLink "home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source = liveLink "home/AGENTS.md";
}
