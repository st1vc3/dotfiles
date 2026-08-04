{ config, lib, pkgs, user, firefox-addons, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  zenAddons = firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  zenExtensions = pkgs.symlinkJoin {
    name = "zen-extensions";
    paths = [ zenAddons.ublock-origin zenAddons.sponsorblock ];
  };
  zenUserJs = pkgs.writeText "zen-user.js" ''
    user_pref("extensions.autoDisableScopes", 0);
    // No confirmation dialogs when quitting or closing a window with tabs open.
    user_pref("browser.warnOnQuit", false);
    user_pref("browser.warnOnQuitShortcut", false);
    user_pref("browser.sessionstore.warnOnQuit", false);
    user_pref("browser.tabs.warnOnClose", false);
    user_pref("browser.tabs.warnOnCloseOtherTabs", false);
  '';
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

  programs.git = {
    enable = true;
    settings = {
      user.name = "st1vc3";
      # GitHub noreply address: the account has email privacy on, and GitHub
      # rejects pushes whose commits contain the real address (GH007).
      user.email = "304027875+st1vc3@users.noreply.github.com";
      core.editor = "nvim";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;   # first `git push` just works, no -u dance
      pull.rebase = true;            # rebase instead of merge commits on pull
      fetch.prune = true;            # drop remote-tracking refs deleted upstream
      rebase.autoStash = true;       # pull --rebase works with a dirty tree
      diff.colorMoved = "default";   # moved lines colored differently from add/delete
      # Repos cloned over https still push over ssh - matches how this
      # machine authenticates to GitHub (no https credential helper set up).
      url."git@github.com:".insteadOf = "https://github.com/";
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

  home.file.".config/kitty".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/kitty";

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # uBlock Origin + SponsorBlock, side-loaded into Zen's real profile.
  # Zen picks a random profile folder name the first time it launches, so it
  # can't be a static home.file path known at Nix eval time - it has to be
  # resolved live, on the machine, at activation time (every rebuild), by
  # reading the Default= profile out of Zen's own profiles.ini. If Zen hasn't
  # been launched yet, this quietly does nothing; the next rebuild after Zen
  # has run once will pick it up.
  home.activation.zenExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profilesIni="$HOME/Library/Application Support/zen/profiles.ini"
    if [ -f "$profilesIni" ]; then
      zenProfile="$(${pkgs.gawk}/bin/awk '
        /^\[Install/ { inInstall=1; next }
        /^\[/ { inInstall=0 }
        inInstall && /^Default=/ { sub(/^Default=/, ""); print; exit }
      ' "$profilesIni")"
      if [ -n "$zenProfile" ]; then
        profileDir="$HOME/Library/Application Support/zen/$zenProfile"
        $DRY_RUN_CMD mkdir -p "$profileDir"
        $DRY_RUN_CMD ln -sfn "${zenExtensions}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}" "$profileDir/extensions"
        $DRY_RUN_CMD ln -sfn "${zenUserJs}" "$profileDir/user.js"
      fi
    fi
  '';
}
