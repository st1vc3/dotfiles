{ config, lib, pkgs, ... }:

{
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
}
