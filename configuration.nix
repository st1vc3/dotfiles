{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

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
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    taps = [
      "nikitabobko/tap"
    ];
    brews = [
      "herdr"
      "opencode"
      "ripgrep"
      "python3"
      "tree"
      "git"
      "gh"
      "fd"
      "fzf"
      "jq"
      "neovim"
      "fastfetch"
      "mas"
    ];
    casks = [
      "ghostty"
      "claude-code"
      "zen"
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
    ];
    # Mac App Store apps (mas) can't be automated here: darwin-rebuild runs
    # `brew bundle` under sudo during activation, but mas needs the logged-in
    # user's App Store session, which isn't reachable from that context.
    # Known upstream issue, no fix available - install these manually instead:
    #   mas install 1451685025   # WireGuard
  };
}
