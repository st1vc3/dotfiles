{ user, private, ... }:

{
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      _HIHideMenuBar = true;
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    dock.autohide-time-modifier = 0.0;
    dock.orientation = "left";
    dock.persistent-apps = [ ];
    dock.show-recents = false;
    dock.persistent-others = [
      { folder = "/Users/${user}/Downloads"; }
    ];
    finder.FXPreferredViewStyle = "Nlsv";
    finder.CreateDesktop = false;
    finder.NewWindowTarget = "Home";
    trackpad.Clicking = true;
  };

  # rebuild.sh, vpn.sh and the generation helpers all shell out to sudo, so
  # authenticate them with the fingerprint reader instead of a password.
  security.pam.services.sudo_local.touchIdAuth = true;

  services.skhd.enable = true;
  nix-homebrew = {
    enable = true;
    inherit user;
    trust.taps = [
      "nikitabobko/tap"
      "FelixKratz/formulae"
    ];
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = false;
    onActivation.extraFlags = [ "--force" ];
    taps = [
      "nikitabobko/tap"
      "FelixKratz/formulae"
    ];
    brews = [
      "FelixKratz/formulae/borders"
      "herdr"
      "opencode"
      "ripgrep"
      "python3"
      "tree"
      "git"
      "gh"
      "fd"
      "fzf"
      "eza"
      "bat"
      "zoxide"
      "jq"
      "neovim"
      "fastfetch"
      "filen-cli"
      "shellcheck"
      "colima"
      "docker"
      "sshpass"
      "wget"
    ];
    casks = [
      "kitty"
      "claude-code"
      "codex"
      "wispr-flow"
      "zen"
      "helium-browser"
      "transmission"
      "vlc"
      "lulu"
      "appcleaner"
      "hiddenbar"
      "raycast"
      "displaylink"
      "localsend"
      "keepassxc"
      "filen"
      "obsidian"
      "balenaetcher"
      "ubersicht"
      "utm"
      "hammerspoon"
      "nikitabobko/tap/aerospace"
      "telegram"
      "whatsapp"
      "font-hack-nerd-font"
      "desktoppr"
      "tailscale-app"
    ];
  };

  # desktoppr is a cask, so on a first run it may not exist yet when this
  # fires. Setting the wallpaper is cosmetic - never fail activation over it.
  #
  # Reading the current wallpaper first keeps this idempotent: without the
  # check every rebuild re-applies the same image, which makes the desktop
  # flash and briefly steals focus.
  system.activationScripts.postActivation.text = ''
    desktoppr=/usr/local/bin/desktoppr
    wallpaperPath="${private}/abstract/red.jpg"
    if [ ! -x "$desktoppr" ]; then
      echo "warning: desktoppr not installed, wallpaper not set" >&2
    else
      uid=$(id -u ${user})
      runAsUser() { launchctl asuser "$uid" sudo -u ${user} "$@"; }
      current=$(runAsUser "$desktoppr" 2>/dev/null | head -n 1 || true)
      if [ "$current" != "$wallpaperPath" ]; then
        runAsUser "$desktoppr" "$wallpaperPath" \
          || echo "warning: desktoppr failed, wallpaper not set" >&2
      fi
    fi
  '';
}
