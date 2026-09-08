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

    # Machine account names and wallpapers. Private, so this public repository
    # carries neither. Fetched over https so it works with the gh credential
    # helper and needs no SSH key.
    private.url = "git+https://github.com/st1vc3/dotfiles-private.git";
  };

  outputs =
    {
      nix-darwin,
      nix-homebrew,
      home-manager,
      nixpkgs,
      firefox-addons,
      simpleBar,
      private,
      ...
    }:
    let
      # The machines differ only in the account they run as and the extra
      # module they load. The accounts come from the private input, so no
      # account name appears in this repository.
      hosts = {
        personal = {
          user = private.hosts.personal.user;
          module = ./hosts/personal.nix;
        };
        work = {
          user = private.hosts.work.user;
          module = ./hosts/work.nix;
        };
      };

      mkHost =
        { user, module }:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit user private; };
          modules = [
            ./hosts/common.nix
            module
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit
                  user
                  firefox-addons
                  simpleBar
                  private
                  ;
              };
              home-manager.users.${user} = import ./home.nix;
            }
          ];
        };

      # The lint and Neovim checks are platform independent, so CI runs them on
      # a Linux runner. Only the darwin system build needs a macOS runner.
      ciSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      ciShell =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShell {
          packages = with pkgs; [
            actionlint
            deadnix
            jq
            luaPackages.luacheck
            neovim
            nixfmt
            shellcheck
            statix
            stylua
            taplo
          ];
        };
    in
    {
      darwinConfigurations = builtins.mapAttrs (_name: mkHost) hosts;

      # Lets host.sh resolve an account to a host without any account name
      # living in this repository.
      hostForAccount = builtins.listToAttrs (
        map (name: {
          name = hosts.${name}.user;
          value = name;
        }) (builtins.attrNames hosts)
      );

      devShells = nixpkgs.lib.genAttrs ciSystems (system: {
        ci = ciShell system;
      });

      formatter = nixpkgs.lib.genAttrs ciSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
