{
  description = "nix system configurations";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://palicand.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "palicand.cachix.org-1:VheixKbvU8a15SQQKHvbUqOP+gQ9uts8IwvreCqX3do="
    ];
  };

  inputs = {
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    comma = {
      url = "github:nix-community/comma";
      flake = false;
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:kclejeune/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, flake-utils, ... }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) nixosSystem;
      inherit (home-manager.lib) homeManagerConfiguration;
      inherit (flake-utils.lib) eachDefaultSystem eachSystem;
      inherit (builtins) listToAttrs map;

      isDarwin = system: (builtins.elem system nixpkgs.lib.platforms.darwin);
      homePrefix = system: if isDarwin system then "/Users" else "/home";

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable
        , baseModules ? [
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ]
        , extraModules ? [ ]
        }:
        darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit inputs nixpkgs stable; };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeConfig =
        { username
        , system ? "x86_64-linux"
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable
        , baseModules ? [
            ./modules/home-manager
            {
              home.sessionVariables = {
                NIX_PATH =
                  "nixpkgs=${nixpkgs}:stable=${stable}\${NIX_PATH:+:}$NIX_PATH";
              };
            }
          ]
        , extraModules ? [ ]
        }:
        homeManagerConfiguration rec {
          inherit system username;
          homeDirectory = "${homePrefix system}/${username}";
          extraSpecialArgs = { inherit inputs nixpkgs stable; };
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
        mac = mkDarwinConfig {
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
    } //
    # add a devShell to this flake
    eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ inputs.devshell.overlay ];
        };
        pyEnv = (pkgs.python3.withPackages
          (ps: with ps; [ black pylint typer colorama shellingham ]));
        sysdo = pkgs.writeShellScriptBin "sysdo" ''
          cd $PRJ_ROOT && ${pyEnv}/bin/python3 bin/do.py $@
        '';
      in
      {
        devShell = pkgs.devshell.mkShell {
          packages = with pkgs; [ nixfmt pyEnv rnix-lsp stylua treefmt ];
          commands = [{
            name = "sysdo";
            package = sysdo;
            category = "utilities";
            help = "perform actions on this repository";
          }];
        };
      });
}
