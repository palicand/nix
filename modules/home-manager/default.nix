{ config, pkgs, lib, ... }:

{
  imports = [
    ./cli
    ./git
    ./alacritty
  ];
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
    stateVersion = "25.11";

    activation = {
      # Skip the app management permission check (known issue on macOS)
      checkAppManagementPermission = lib.mkForce "";

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
      postgresql_14
      poetry
      jq
      openssh
      rsync
      tree
      yq
      pgcli
      man-db
      jwt-cli
      openvpn
      nodejs
      (yarn.override {
        nodejs = null;
      })
      htop
      tig
      ffmpeg
      cmake
      stripe-cli
      k9s
      kubernetes-helm
      openssl
      jdk21_headless
      (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
      terraform
      claude-code
    ];
};
}
