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
  home.stateVersion = "24.11";
  home.sessionVariables.EDITOR = "nvim";
  manual.manpages.enable = false;
}
