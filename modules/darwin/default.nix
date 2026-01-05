{ config, pkgs, ... }:

{
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    allowUnsupportedSystem = true;
  };
  imports = [
    ../common.nix
    ./ollama.nix
    ./charging-chime.nix
  ];
  # Auto upgrade nix package and the daemon service.
  # Create /etc/bashrc that loads the nix-darwin environment.
  # programs.zsh.enable = true; # default shell on catalina
  programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system = {
    stateVersion = 6;
    primaryUser = "palicand";
    # Disable charging chime/alert sound
    chargingChime.enable = false;
  };

  # Keep existing nixbld group ID after stateVersion upgrade
  ids.gids.nixbld = 30000;

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
    enableSyntaxHighlighting = true;
  };

  users.users.palicand = {
    name = "palicand";
    home = "/Users/palicand";
  };

  # Enable passwordless sudo
  security.sudo.extraConfig = ''
    palicand ALL = (ALL) NOPASSWD: ALL
  '';

  # Install Iosevka Nerd Font
  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];

  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
  ];

  # Set PATH for GUI applications (like Lens) so they can find Nix-managed binaries
  # Include Homebrew paths to avoid breaking apps that depend on Homebrew
  launchd.user.envVariables.PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:${config.environment.systemPath}";
}
