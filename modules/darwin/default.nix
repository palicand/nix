{ config, pkgs, ... }:

{
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    allowUnsupportedSystem = true;
  };
  imports = [ ../common.nix ];
  # Auto upgrade nix package and the daemon service.
  # Create /etc/bashrc that loads the nix-darwin environment.
  # programs.zsh.enable = true; # default shell on catalina
  # programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
  system.primaryUser = "palicand";

  # Keep existing nixbld group ID after stateVersion upgrade
  ids.gids.nixbld = 30000;
  documentation.enable = false;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.man.enable = false;
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

  # Configure iTerm2 with similar settings to Alacritty
  system.defaults.CustomUserPreferences = {
    "com.googlecode.iterm2" = {
      # Use Iosevka Nerd Font at size 20
      "Normal Font" = "IosevkaNerdFont-Regular 20";
      "Non Ascii Font" = "IosevkaNerdFont-Regular 20";

      # Basic settings
      "Default Bookmark Guid" = "Default";
    };
  };

  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
  ];
}
