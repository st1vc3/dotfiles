{ config, lib, pkgs, user, firefox-addons, simpleBar, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
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
  # Keep this at the first Home Manager version used by this account. It is a
  # compatibility boundary, not the version of the currently pinned release.
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

  home.file.".config/nvim".source = liveLink "home/.config/nvim";

  # Only the durable config belongs in git. Herdr logs, sockets, release notes,
  # and session state remain ordinary files under ~/.config/herdr.
  home.file.".config/herdr/config.toml".source = liveLink "home/.config/herdr/config.toml";

  home.file.".config/kitty".source = liveLink "home/.config/kitty";

  home.file.".config/aerospace".source = liveLink "home/.config/aerospace";

  home.file.".config/skhd".source = liveLink "home/.config/skhd";

  # skhd runs as a nix-darwin launchd agent, but its config is an out-of-store
  # symlink edited live in the repo. skhd's config watcher tracks the file by
  # inode, which git rewrites on checkout, so the daemon can silently keep
  # running a stale config after a rebuild or pull. Kick the service on every
  # activation so the current skhdrc is always loaded. The Accessibility grant
  # is tied to skhd's /nix/store path and survives a same-path restart.
  home.activation.reloadSkhd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/Library/LaunchAgents/org.nixos.skhd.plist" ]; then
      $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$(id -u)/org.nixos.skhd" || true
    fi
  '';

  home.file.".claude/settings.json".source = liveLink "home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source = liveLink "home/AGENTS.md";

  home.file.".codex/AGENTS.md".source = liveLink "home/AGENTS.md";

  home.file.".config/opencode/AGENTS.md".source = liveLink "home/AGENTS.md";

  home.file.".simplebarrc".source = ./home/.simplebarrc;

  home.file."Library/Application Support/Übersicht/widgets/simple-bar".source = simpleBar;

  # Hide Übersicht's welcome widget while keeping Simple Bar visible.
  home.file."Library/Application Support/tracesOf.Uebersicht/WidgetSettings.json".text =
    builtins.toJSON {
      "GettingStarted-jsx" = {
        hidden = true;
        screens = [ ];
        showOnAllScreens = true;
        showOnMainScreen = false;
        showOnSelectedScreens = false;
      };
      "simple-bar-index-jsx" = {
        hidden = false;
        screens = [ ];
        showOnAllScreens = true;
        showOnMainScreen = false;
        showOnSelectedScreens = false;
      };
    };

  # Start Übersicht once per login, then refresh Simple Bar after its external
  # configuration has loaded. Übersicht remains running after the shell exits.
  launchd.agents.uebersicht = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/usr/bin/open -gj /Applications/Übersicht.app; /bin/sleep 2; /usr/bin/osascript -e 'tell application id \"tracesOf.Uebersicht\" to refresh widget id \"simple-bar-index-jsx\"'"
      ];
      RunAtLoad = true;
    };
  };

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
        extensionsDir="$profileDir/extensions"
        $DRY_RUN_CMD mkdir -p "$profileDir"
        # Older generations managed the whole directory as one symlink. Move
        # to per-extension links so existing user-installed extensions survive.
        if [ -L "$extensionsDir" ]; then
          $DRY_RUN_CMD rm "$extensionsDir"
        fi
        $DRY_RUN_CMD mkdir -p "$extensionsDir"
        for extension in "${zenExtensions}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"/*; do
          $DRY_RUN_CMD ln -sfn "$extension" "$extensionsDir/$(basename "$extension")"
        done
        $DRY_RUN_CMD ln -sfn "${zenUserJs}" "$profileDir/user.js"
      fi
    fi
  '';
}
