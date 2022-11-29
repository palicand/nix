{ config, pkgs, lib, ... }:

{
  imports = [
    ./cli
    ./git
    ./alacritty
  ];
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };
  programs.home-manager = {
    enable = true;
    path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
  };

  programs.tmux = {
    enable = true;
    clock24 = true;
    plugins = with pkgs; [
      tmuxPlugins.cpu
      tmuxPlugins.resurrect
    ];

  };

  home = with pkgs; {
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    stateVersion = "20.09";

    activation = {
      aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "$HOME/Applications/Home Manager Applications" ]; then
          ln -sfn $genProfilePath/home-path/Applications "$HOME/Applications/Home Manager Applications"
        fi
      '';
    };

    packages = with pkgs; [
      alacritty
      wget
      yadm
      fzf
      rustup
      ripgrep
      bat
      bandwhich
      google-cloud-sdk
      postgresql
      jq
      openssh
      rsync
      tree
      yq
      pgcli
      jdk17_headless
      cachix
      man-db
      nix-doc
      cloud-sql-proxy
      jwt-cli
      openvpn
      wireguard-tools
      nodejs-16_x
      htop
      tig
      ffmpeg
    ];
  };

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

}
