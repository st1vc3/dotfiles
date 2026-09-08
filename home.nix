{
  host,
  lib,
  user,
  ...
}:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/development.nix
    ./modules/home/desktop.nix
    ./modules/home/zen.nix
    ./modules/home/ssh.nix
  ]
  # Corporate-only tooling. Mirrors the hosts/ split: anything that must not
  # reach the personal machine is imported per host rather than guarded by a
  # conditional inside a shared module.
  ++ lib.optional (host == "work") ./modules/home/work.nix;

  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.sessionVariables.EDITOR = "nvim";
  manual.manpages.enable = false;
}
