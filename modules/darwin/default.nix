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
  ];
  # Auto upgrade nix package and the daemon service.
  # Create /etc/bashrc that loads the nix-darwin environment.
  # programs.zsh.enable = true; # default shell on catalina
  programs.fish.enable = true;

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

  # Ollama service for local AI models
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    loadModels = [
      "qwen2.5:7b"
    ];
  };

  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
  ];

  # Set PATH for GUI applications (like Lens) so they can find Nix-managed binaries
  # Include Homebrew paths to avoid breaking apps that depend on Homebrew
  launchd.user.envVariables.PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:${config.environment.systemPath}";
}
