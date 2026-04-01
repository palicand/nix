{ config, pkgs, ... }:

{
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    allowUnsupportedSystem = true;
  };

  # Workaround: direnv 2.37.1 in nixpkgs uses -linkmode=external but sets CGO_ENABLED=0
  nixpkgs.overlays = [
    (final: prev: {
      direnv = prev.direnv.overrideAttrs (old: {
        env = (old.env or { }) // {
          CGO_ENABLED = 1;
        };
      });
    })
  ];
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

  # Make Nix-managed binaries visible to GUI apps via macOS path_helper
  environment.etc."paths.d/nix".text = ''
    /etc/profiles/per-user/${config.user.name}/bin
    /run/current-system/sw/bin
    /nix/var/nix/profiles/default/bin
  '';
}
