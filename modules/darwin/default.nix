{ config, pkgs, ... }:

{
  imports = [ "../common.nix" ];
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # Create /etc/bashrc that loads the nix-darwin environment.
  # programs.zsh.enable = true; # default shell on catalina
  # programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
  };

  users.users.palicand = {
    name = "palicand";
    home = "/Users/palicand";
  };

  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
    rnix-lsp
  ];
}
