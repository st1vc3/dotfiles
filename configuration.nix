{ user, wallpaper, workMachine, lib, ... }:

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
    dock.persistent-apps = [];
    dock.show-recents = false;
    dock.persistent-others = [
      { folder = "/Users/${user}/Downloads"; }
    ];
    finder.FXPreferredViewStyle = "Nlsv";
    finder.CreateDesktop = false;
    finder.NewWindowTarget = "Home";
    trackpad.Clicking = true;
  };
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
      "openconnect"
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
    ] ++ lib.optionals workMachine [
      "webex"
      "microsoft-teams"
    ];
  };

  system.activationScripts.postActivation.text = ''
    uid=$(id -u ${user})
    launchctl asuser "$uid" sudo -u ${user} /usr/local/bin/desktoppr "${wallpaper}/abstract/red.png" \
      || echo "warning: desktoppr failed, wallpaper not set" >&2
  '';
}
