{ user, wallpaper, ... }:

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
    finder.NewWindowTarget = "Home";       # new windows open in the home dir
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    # Keep switches deterministic: don't let brew pull whatever is newest that
    # day. Update deliberately with `brew update` before a rebuild instead.
    onActivation.autoUpdate = false;
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
      "desktoppr"
    ];
    # Mac App Store apps (mas) can't be automated here: darwin-rebuild runs
    # `brew bundle` under sudo during activation, but mas needs the logged-in
    # user's App Store session, which isn't reachable from that context.
    # Known upstream issue, no fix available - install these manually instead:
    #   mas install 1451685025   # WireGuard
  };

  # All nix-darwin activation runs as root, so desktoppr (which sets a
  # per-user desktop picture) has to be handed off to the logged-in user's
  # session via launchctl asuser. Runs after the homebrew block above, so
  # desktoppr is already installed by the time this executes.
  # A cosmetic step must not abort the switch after everything else already
  # applied, so warn instead of failing if desktoppr or the image is missing.
  system.activationScripts.postActivation.text = ''
    uid=$(id -u ${user})
    launchctl asuser "$uid" sudo -u ${user} /usr/local/bin/desktoppr "${wallpaper}/abstract/red.png" \
      || echo "warning: desktoppr failed, wallpaper not set" >&2
  '';
}
