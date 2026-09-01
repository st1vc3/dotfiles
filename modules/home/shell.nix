{
  config,
  lib,
  pkgs,
  ...
}:

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
      vpn = "$HOME/.dotfiles/vpn.sh";
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
      # The remote host is machine-specific, so it lives in the untracked .env
      # rather than in the repository; see .env.example.
      #
      # .env is sourced inside a subshell that emits only the single value this
      # needs, so the rest of the file never lands in the interactive shell.
      rcc() {
        local env_file="$HOME/.dotfiles/.env"
        local remote
        remote="$(
          [ -r "$env_file" ] && . "$env_file" >/dev/null 2>&1
          printf '%s' "''${HERDR_REMOTE:-}"
        )"
        if [ -z "$remote" ]; then
          echo "rcc: HERDR_REMOTE is not set - copy .env.example to .env and fill it in" >&2
          return 1
        fi
        herdr --remote "$remote" --session cc
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

      # jwp - jenkins work pull. Refreshes every repo in the jenkins-git
      # workspace, then drops you in the jenkins-setup root. It is a function
      # rather than an alias to a script because a script runs in a subshell and
      # cannot change the directory of the shell that called it.
      export JENKINS_WORK_ROOT="$HOME/Documents/cargo-partner/jenkins-git"
      jwp() {
        "$HOME/.dotfiles/jenkins-work-pull.sh" "$@"
        local rc=$?
        cd "$JENKINS_WORK_ROOT/jenkins-setup" 2>/dev/null || {
          print -u2 "jwp: could not cd to $JENKINS_WORK_ROOT/jenkins-setup"
          return 1
        }
        print -P "%B-> $PWD%b"
        return $rc
      }

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
      # pushInsteadOf rather than insteadOf: rewriting fetches as well would
      # force every anonymous https clone through SSH, which breaks tooling
      # that bootstraps itself from GitHub (lazy.nvim, go modules, pip and
      # cargo git dependencies) on a machine with no key loaded. Pushes still
      # go over SSH.
      url."git@github.com:".pushInsteadOf = "https://github.com/";
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

      nodejs = {
        symbol = "";
        format = "[$symbol $version](green) ";
      };
      rust = {
        symbol = "";
        format = "[$symbol $version](red) ";
      };
      golang = {
        symbol = "";
        format = "[$symbol $version](cyan) ";
      };
      php = {
        symbol = "";
        format = "[$symbol $version](purple) ";
      };

      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](blue)";
      };
    };
  };
}
