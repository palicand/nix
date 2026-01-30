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

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    # Pre-built nix-index database for command-not-found
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code native binary with pinned version
    claude-code-native = {
      url = "path:./pkgs/claude-code-native";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kotlin LSP from JetBrains
    kotlin-lsp = {
      url = "path:./pkgs/kotlin-lsp";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      darwin,
      home-manager,
      nix-homebrew,
      nix-index-database,
      claude-code-native,
      kotlin-lsp,
      ...
    }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (builtins) listToAttrs;

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        {
          system,
          nixpkgs ? inputs.nixpkgs,
          baseModules ? [
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ],
          extraModules ? [ ],
        }:
        darwinSystem {
          inherit system;
          modules =
            baseModules
            ++ extraModules
            ++ [
              # Import nix-index-database for command-not-found with pre-built database
              {
                home-manager.sharedModules = [
                  nix-index-database.homeModules.nix-index
                ];
              }
            ];
          specialArgs = { inherit inputs nixpkgs; };
        };

    in
    {
      checks = listToAttrs (
        # darwin checks
        (map (system: {
          name = system;
          value = {
            darwin = self.darwinConfigurations.uber-mac.config.system.build.toplevel;
          };
        }) nixpkgs.lib.platforms.darwin)
        ++
          # linux checks
          (map (system: {
            name = system;
            value = { };
          }) nixpkgs.lib.platforms.linux)
      );

      darwinConfigurations = {
        uber-mac = mkDarwinConfig {
          system = "aarch64-darwin";
          extraModules = [
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = false;
                user = "palicand";
                autoMigrate = true;
                mutableTaps = true;
              };
            }
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
