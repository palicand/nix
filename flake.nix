{
  description = "nix system configurations";

  nixConfig = { };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ... }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) nixosSystem;
      inherit (home-manager.lib) homeManagerConfiguration;
      inherit (builtins) listToAttrs map;

      isDarwin = system: (builtins.elem system nixpkgs.lib.platforms.darwin);
      homePrefix = system: if isDarwin system then "/Users" else "/home";

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system
        , nixpkgs ? inputs.nixpkgs
        , baseModules ? [
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ]
        , extraModules ? [ ]
        }:
        darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit inputs nixpkgs; };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeConfig =
        { username
        , system ? "x86_64-linux"
        , nixpkgs ? inputs.nixpkgs
        , baseModules ? [
            ./modules/home-manager
            {
              home.sessionVariables = {
                NIX_PATH =
                  "nixpkgs=${nixpkgs}\${NIX_PATH:+:}$NIX_PATH";
              };
            }
          ]
        , extraModules ? [ ]
        }:
        homeManagerConfiguration rec {
          inherit system username;
          homeDirectory = "${homePrefix system}/${username}";
          extraSpecialArgs = { inherit inputs nixpkgs; };
          configuration = {
            imports = baseModules ++ extraModules;
          };
        };
    in
    {
      checks = listToAttrs (
        # darwin checks
        (map
          (system: {
            name = system;
            value = {
              darwin =
                self.darwinConfigurations.mac.config.system.build.toplevel;
            };
          })
          nixpkgs.lib.platforms.darwin) ++
        # linux checks
        (map
          (system: {
            name = system;
            value = { };
          })
          nixpkgs.lib.platforms.linux)
      );

      darwinConfigurations = {
        uber-mac = mkDarwinConfig {
          system = "aarch64-darwin";
          extraModules = [
            ./profiles/personal.nix
            ./modules/darwin/apps.nix
            { homebrew.brewPrefix = "/opt/homebrew/bin"; }
          ];
        };
      };

      nixosConfigurations = { };

      homeConfigurations = { };
    };
}
