{ config, pkgs, user, firefox-addons, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  zenAddons = firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  zenExtensions = pkgs.symlinkJoin {
    name = "zen-extensions";
    paths = [ zenAddons.ublock-origin zenAddons.sponsorblock ];
  };
  # Zen's profile folder name is randomly generated on first launch. If Zen is
  # ever reset, or this config is applied on a new machine, open
  # ~/Library/Application Support/zen/profiles.ini and update this to match
  # the profile referenced by the [InstallXXXX] section's Default= line.
  zenProfile = "Library/Application Support/zen/Profiles/aooe5794.Default (release)";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.sessionVariables.EDITOR = "nvim";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      l = "ls --color=auto";
      ll = "ls -l --color=auto";
      lll = "ls -lah --color=auto";

      ".." = "cd ..";
     
      v = "nvim";
      ff = "clear; fastfetch";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
      c = "clear";
      zc = "nvim ~/.zshrc";
      zr = "source ~/.zshrc";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";

  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # uBlock Origin + SponsorBlock, side-loaded into Zen's real profile.
  home.file."${zenProfile}/extensions" = {
    source = "${zenExtensions}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
    recursive = true;
    force = true;
  };

  home.file."${zenProfile}/user.js".text = ''
    user_pref("extensions.autoDisableScopes", 0);
  '';
}
