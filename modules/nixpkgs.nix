{ inputs, config, lib, pkgs, ... }: {
  nixpkgs = { config = import ./config.nix; };
  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    trustedUsers = [ "palicand" "root" "@admin" "@wheel" ];
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

  };
  registry = {
    nixpkgs = {
      from = {
        id = "nixpkgs";
        type = "indirect";
      };
      flake = inputs.nixpkgs;
    };

    stable = {
      from = {
        id = "stable";
        type = "indirect";
      };
      flake = inputs.stable;
    };
  };

}
