{ pkgs, ... }:
{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget

  # Auto upgrade nix package and the daemon service.
  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command
    '';
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

  };
}
