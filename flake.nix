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

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    # Homebrew taps
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-services = {
      url = "github:homebrew/homebrew-services";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      darwin,
      home-manager,
      pre-commit-hooks,
      nix-homebrew,
      homebrew-bundle,
      homebrew-services,
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
          modules = baseModules ++ extraModules;
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
                taps = {
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                  "homebrew/homebrew-services" = homebrew-services;
                };
                mutableTaps = false;
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

      # Development shell with pre-commit hooks
      devShells = {
        aarch64-darwin.default =
          let
            pkgs = nixpkgs.legacyPackages.aarch64-darwin;
            pre-commit-check = pre-commit-hooks.lib.aarch64-darwin.run {
              src = ./.;
              hooks = {
                nixfmt = {
                  enable = true;
                  name = "nixfmt";
                  description = "Format Nix files with nixfmt";
                  entry = "${pkgs.nixfmt}/bin/nixfmt";
                  files = "\\.nix$";
                };
                statix = {
                  enable = true;
                  name = "statix";
                  description = "Lint Nix files with statix";
                  entry = "${pkgs.statix}/bin/statix check";
                  files = "\\.nix$";
                };
              };
            };
          in
          pkgs.mkShell {
            inherit (pre-commit-check) shellHook;
            buildInputs = pre-commit-check.enabledPackages;
          };
      };
    };
}
