{ user, wallpaper, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
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
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    dock.autohide-time-modifier = 0.0;  # instant show/hide, no slide animation
    dock.orientation = "left";
    dock.persistent-apps = [];  # no pinned/running app icons
    dock.show-recents = false;  # no recently-used apps section
    dock.persistent-others = [
      { folder = "/Users/${user}/Downloads"; }
    ];
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    finder.NewWindowTarget = "Home";       # new windows open in the home dir
    trackpad.Clicking = true;              # tap to click
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
    onActivation.cleanup = "zap";  # remove anything not listed here
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
      "eza"      # ls replacement (aliased ls/ll/la/tree)
      "bat"      # cat replacement + fzf/man pager
      "zoxide"   # smart `cd` / directory jumping
      "jq"
      "neovim"
      "fastfetch"
      "shellcheck"
      "mas"
      "colima"
      "docker"
      "sshpass"
      "wget"
      "wireguard-tools"  # `wg` / `wg-quick` CLI (replaces the App Store GUI)
    ];
    casks = [
      "kitty"
      "claude-code"
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
      "obsidian"
      "balenaetcher"
      "ubersicht"
      "utm"
      "nikitabobko/tap/aerospace"
      "telegram"
      "whatsapp"
      "font-hack-nerd-font"
      "desktoppr"
    ];
  };

  system.activationScripts.postActivation.text = ''
    uid=$(id -u ${user})
    launchctl asuser "$uid" sudo -u ${user} /usr/local/bin/desktoppr "${wallpaper}/abstract/red.png" \
      || echo "warning: desktoppr failed, wallpaper not set" >&2
  '';
}
