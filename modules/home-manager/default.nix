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
      postgresql
      jq
      openssh
      rsync
      tree
      yq
      pgcli
      man-db
      nix-doc
      jwt-cli
      openvpn
      wireguard-tools
      nodejs-16_x
      (yarn.override {
        nodejs = null;
      })
      htop
      tig
      ffmpeg
      cmake
      stripe-cli
      awscli2
      eksctl
      k9s
      kubernetes-helm
      openssl
    ];
  };

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

}
