{ pkgs, ... }:
{
  nixpkgs = {
    config = import ./config.nix;
  };
  nix = {
    # nix.package set per-host in hosts/*.nix
    settings = {
      max-jobs = "auto";
    };
    extraOptions = ''
      keep-outputs = false
      keep-derivations = false
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
}
