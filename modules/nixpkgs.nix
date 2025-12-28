{ inputs, config, lib, pkgs, ... }: {
  nixpkgs = { config = import ./config.nix; };
  nix = {
    package = pkgs.nix;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
      interval = {
        Hour = 13;
        Minute = 30;
      };
    };
  };
  # registry = {
  #   nixpkgs = {
  #     from = {
  #       id = "nixpkgs";
  #       type = "indirect";
  #     };
  #     flake = inputs.nixpkgs;
  #   };

  #   stable = {
  #     from = {
  #       id = "stable";
  #       type = "indirect";
  #     };
  #     flake = inputs.stable;
  #   };
  # };

}
