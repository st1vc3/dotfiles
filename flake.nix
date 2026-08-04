{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Prebuilt Firefox-compatible browser extensions (used to side-load into Zen).
    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";

    # Wallpaper images. Private repo, so fetched over SSH using the same key
    # already used to push this repo - no separate Nix access-token setup needed.
    wallpaper.url = "git+ssh://git@github.com/st1vc3/wallpaper.git";
    wallpaper.flake = false;
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs, firefox-addons, wallpaper }:
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
            home-manager.extraSpecialArgs = { inherit user firefox-addons; };
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
