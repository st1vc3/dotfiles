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
    # Autosuggestions and highlighting are sourced manually in initContent
    # below (not via the Home Manager modules) so plugin load order matches
    # the nixos repo exactly - fast-syntax-highlighting must load last so it
    # wraps every widget. See the plugin block for the full ordering.

    # History matched to the nixos repo: large, shared across sessions, stored
    # under XDG state, with the same dedup behaviour.
    history = {
      size = 100000;
      save = 100000;
      path = "${config.xdg.stateHome}/zsh/history";
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      findNoDups = true;
    };

    shellAliases = {
      # App-backed coreutils replacements, aliased identically to the nixos
      # repo (eza/bat/ripgrep, all installed as Homebrew formulae).
      ls = "eza --icons";
      ll = "eza -lh --icons --git";
      la = "eza -lah --icons --git";
      tree = "eza --tree --icons";
      cat = "bat";
      grep = "rg --color=auto";
      diff = "diff --color=auto";
      df = "df -h";
      vim = "nvim";

      ".." = "cd ..";

      v = "nvim";
      ff = "clear; fastfetch";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";

      # Git shortcuts shared with the nixos repo. -F quits if the log fits one
      # screen, -X leaves it on screen after quitting.
      gs = "git status";
      gd = "git diff";
      glog = ''PAGER="less -F -X" git log'';
      gadog = ''PAGER="less -F -X" git log --all --decorate --oneline --graph'';
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
      cx = "codex --dangerously-bypass-approvals-and-sandbox";
      c = "clear";
      zc = "nvim ~/.zshrc";
      zr = "source ~/.zshrc";
    };

    # Mirrors the nixos repo's config/zsh so the shell behaves the same on
    # both machines. Pinned to the very end (mkOrder 1500) so it runs after
    # Home Manager's compinit and so fast-syntax-highlighting loads last.
    initContent = lib.mkOrder 1500 ''
      # Shell behaviour: type a dir name to cd into it, no bell, natural sort.
      setopt AUTOCD NOBEEP NUMERIC_GLOB_SORT

      # Home Manager points HISTFILE here; make sure its directory exists.
      mkdir -p "${config.xdg.stateHome}/zsh"

      # Completion tuned like the nixos repo: arrow-key menu selection and
      # case-insensitive matching ("doc" completes "Documents"). Runs after
      # Home Manager's compinit thanks to the mkOrder above.
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      # System rebuild helpers, mirroring the nixos repo's names. rebuild runs
      # the repo's own script (symlink + flake archive + darwin-rebuild switch
      # + skhd check); rehash afterwards so new binaries resolve immediately.
      rebuild() {
        "$HOME/.dotfiles/rebuild.sh" || return
        rehash
      }
      generations() {
        darwin-rebuild --list-generations
      }
      rollback_system() {
        sudo darwin-rebuild --rollback || return
        rehash
      }

      # Smart directory jumping.
      if (( $+commands[zoxide] )); then
        eval "$(zoxide init zsh)"
      fi

      # `cd -` shortcut. shellAliases can't express a bare `-` alias.
      alias -- -='cd -'

      # Reuse ls completions for eza.
      compdef eza=ls 2>/dev/null || true

      # Route man pages through bat.
      if (( $+commands[bat] )); then
        export MANPAGER="bat -l man -p"
      fi

      # fzf shell integration (Ctrl-T files, Ctrl-R history). fzf >= 0.48.
      if (( $+commands[fzf] )); then
        source <(fzf --zsh)
      fi

      export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_DEFAULT_OPTS='
        --height=60%
        --layout=reverse
        --border=rounded
        --prompt="  "
        --pointer="  "
        --preview-window=right:65%:wrap:border-left
      '
      export _FZF_PREVIEW_CMD='bat --color=always --style=plain,numbers --line-range=:500 -- {}'
      export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD'"

      # Ctrl-F: fzf file picker excluding hidden files.
      _fzf_file_no_hidden() {
        local result
        local -a fd_command=(fd --type f --strip-cwd-prefix --exclude .git)
        result=$("''${fd_command[@]}" | fzf --preview "$_FZF_PREVIEW_CMD") \
          && LBUFFER+="''${(q)result}"  # Quote the path for safe insertion.
        zle reset-prompt
      }
      zle -N _fzf_file_no_hidden

      # Plugins, sourced in this order so fast-syntax-highlighting wraps every
      # widget defined above.
      source "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
      source "${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
      source "${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
      source "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

      # zsh-vi-mode rebuilds its keymaps on the first prompt and wipes any
      # bindkey made earlier - including fzf's Ctrl-R/Ctrl-T - so custom keys
      # are (re)applied in its documented hook.
      function zvm_after_init() {
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down
        bindkey -M vicmd 'k' history-substring-search-up
        bindkey -M vicmd 'j' history-substring-search-down
        bindkey '^F' _fzf_file_no_hidden
        bindkey '^R' fzf-history-widget
        bindkey '^T' fzf-file-widget
      }
    '';
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

  # Ported verbatim from the nixos repo's config/zsh/starship.toml so the
  # prompt is identical on both machines. The os module resolves to the Apple
  # glyph here and the NixOS glyph there from the same config.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$os$git_branch$git_status$nodejs$rust$golang$php $character";

      os = {
        disabled = false;
        format = "[$symbol](#blue) ";
        symbols = {
          NixOS = "󱄅";
          Ubuntu = "󰕈";
          Artix = "󰣇";
          Arch = "󰣇";
          CachyOS = "󰣇";
          Macos = "";
        };
      };

      directory = {
        format = "[$path](cyan) ";
        truncation_length = 4;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = "";
        format = "[$symbol $branch](bold purple) ";
      };

      git_status = {
        format = "($ahead_behind$staged$modified$untracked$deleted$conflicted)";
        ahead = "[⇡$count ](bold cyan)";
        behind = "[⇣$count ](bold cyan)";
        diverged = "[⇡$ahead_count⇣$behind_count ](bold cyan)";
        staged = "[+$count ](bold green)";
        modified = "[●$count ](bold yellow)";
        untracked = "[?$count ](bold white)";
        deleted = "[✘$count ](bold red)";
        conflicted = "[⚡$count ](bold red)";
      };

      nodejs = { symbol = ""; format = "[$symbol $version](green) "; };
      rust = { symbol = ""; format = "[$symbol $version](red) "; };
      golang = { symbol = ""; format = "[$symbol $version](cyan) "; };
      php = { symbol = ""; format = "[$symbol $version](purple) "; };

      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](blue)";
      };
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

  # Reload Übersicht on rebuild so managed settings reach its long-lived WebView.
  home.activation.reloadUbersicht = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/pkill -TERM -f '/Applications/.*bersicht.app/Contents/' || true
    attempt=0
    while /usr/bin/pgrep -f '/Applications/.*bersicht.app/Contents/' >/dev/null && [ "$attempt" -lt 10 ]; do
      /bin/sleep 1
      attempt=$((attempt + 1))
    done

    /usr/bin/open -g -b tracesOf.Uebersicht
    attempt=0
    until /usr/bin/osascript -e 'tell application id "tracesOf.Uebersicht" to refresh widget id "simple-bar-index-jsx"' >/dev/null 2>&1; do
      attempt=$((attempt + 1))
      if [ "$attempt" -ge 15 ]; then
        echo "warning: Übersicht started but Simple Bar was not ready after 15 seconds" >&2
        break
      fi
      /bin/sleep 1
    done
  '';

  # Start Übersicht once per login, then refresh Simple Bar after its external
  # configuration has loaded. Übersicht remains running after the shell exits.
  launchd.agents.uebersicht = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/usr/bin/open -g /Applications/Übersicht.app; /bin/sleep 2; /usr/bin/osascript -e 'tell application id \"tracesOf.Uebersicht\" to refresh widget id \"simple-bar-index-jsx\"'"
      ];
      RunAtLoad = true;
    };
  };
  # Keep the active-window border independent from AeroSpace restarts.
  launchd.agents.borders = {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/borders"
        "active_color=0xffff4057"
        "inactive_color=0x00000000"
        "width=3.0"
        "style=round"
        "hidpi=on"
      ];
      KeepAlive = true;
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
