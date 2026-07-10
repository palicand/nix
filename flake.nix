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
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    # Pin Homebrew core to a known-good version. Override of nix-homebrew's
    # transitive brew-src input. 5.1.7/5.1.8 ship a regression in
    # cask_struct_generator.rb (`to_sym` on nil for bare `depends :macos`);
    # fixed upstream in 5.1.9 (Homebrew/brew@1c8cbf3).
    brew-src = {
      url = "github:Homebrew/brew/5.1.10";
      flake = false;
    };

    # Pre-built nix-index database for command-not-found
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Encrypted secrets management (age/GPG/KMS). Decrypts to /run/secrets at activation.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # herdr — terminal multiplexer for AI coding agents. Not in nixpkgs; ships
    # its own flake. Pin to a release tag per upstream's install guidance.
    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.3";
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
      sops-nix,
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

      # Per-repo dev shell. Activated by `.envrc` via nix-direnv.
      # Holds tooling that should NOT pollute the global user profile
      devShells.aarch64-darwin.default =
        let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        in
        pkgs.mkShell {
          packages = with pkgs; [
            sops
            ssh-to-age
            nil
            (writeShellScriptBin "rotate" ''
              set -euo pipefail
              if [ "$#" -ne 2 ]; then
                echo "usage: rotate <key> <value>" >&2
                exit 1
              fi
              root=$(${pkgs.git}/bin/git rev-parse --show-toplevel)
              exec ${pkgs.sops}/bin/sops set "$root/secrets/tokens.yaml" \
                "[\"$1\"]" "$(printf '%s' "$2" | ${pkgs.jq}/bin/jq -Rs .)"
            '')
          ];
        };

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
            ./hosts/uber-mac.nix
            { homebrew.prefix = "/opt/homebrew"; }
          ];
        };

        mac-2026 = mkDarwinConfig {
          system = "aarch64-darwin";
          extraModules = [
            nix-homebrew.darwinModules.nix-homebrew
            sops-nix.darwinModules.sops
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
            ./hosts/mac-2026.nix
            ./modules/darwin/sops.nix
            { homebrew.prefix = "/opt/homebrew"; }
          ];
        };
      };

      nixosConfigurations = { };

      homeConfigurations = { };
    };
}
