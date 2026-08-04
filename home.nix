{ user, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/development.nix
    ./modules/home/desktop.nix
    ./modules/home/zen.nix
  ];

  home.username = user;
  home.homeDirectory = "/Users/${user}";
  # Keep this at the first Home Manager version used by this account. It is a
  # compatibility boundary, not the version of the currently pinned release.
  home.stateVersion = "24.11";
  home.sessionVariables.EDITOR = "nvim";
  # The generated options manual currently triggers an invalid store-context warning.
  manual.manpages.enable = false;
}
