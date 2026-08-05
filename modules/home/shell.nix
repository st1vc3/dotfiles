{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;

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

    initContent = lib.mkOrder 1500 ''
      setopt AUTOCD NOBEEP NUMERIC_GLOB_SORT

      mkdir -p "${config.xdg.stateHome}/zsh"

      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      rebuild() {
        "$HOME/.dotfiles/rebuild.sh" || return
        rehash
      }
      generations() {
        sudo darwin-rebuild --list-generations
      }
      rollback_system() {
        sudo darwin-rebuild --rollback || return
        rehash
      }

      if (( $+commands[zoxide] )); then
        eval "$(zoxide init zsh)"
      fi

      alias -- -='cd -'

      compdef eza=ls 2>/dev/null || true

      if (( $+commands[bat] )); then
        export MANPAGER="bat -l man -p"
      fi

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

      _fzf_file_no_hidden() {
        local result
        local -a fd_command=(fd --type f --strip-cwd-prefix --exclude .git)
        result=$("''${fd_command[@]}" | fzf --preview "$_FZF_PREVIEW_CMD") \
          && LBUFFER+="''${(q)result}"
        zle reset-prompt
      }
      zle -N _fzf_file_no_hidden

      source "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
      source "${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
      source "${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
      source "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

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
      user.email = "304027875+st1vc3@users.noreply.github.com";
      core.editor = "nvim";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      fetch.prune = true;
      rebase.autoStash = true;
      diff.colorMoved = "default";
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

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
