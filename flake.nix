{
  description = "dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";

    simpleBar.url = "github:Jean-Tinland/simple-bar";
    simpleBar.flake = false;

    wallpaper.url = "git+ssh://git@github.com/st1vc3/wallpaper.git";
    wallpaper.flake = false;
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs, firefox-addons, simpleBar, wallpaper }:
    let
      user = "stivce";
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user wallpaper; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit user firefox-addons simpleBar wallpaper; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };

      devShells.${system}.ci = pkgs.mkShell {
        packages = with pkgs; [
          actionlint
          jq
          neovim
          taplo
        ];
      };
    };
}
