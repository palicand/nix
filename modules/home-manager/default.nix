{ config, pkgs, ... }:

{
  imports = [
    ./cli
  ];
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };
  programs.home-manager = {
    enable = true;
    path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
  };
  home = with pkgs; {
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    stateVersion = "20.09";

    packages = with pkgs; [
      wget
      tmux
      yadm
      fzf
      rustup
      poetry
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
      kubernetes
      kubernetes-helm
      cachix
      man-db
      nix-doc
      cloud-sql-proxy
      jwt-cli
      openvpn
      wireguard-tools
      postgresql_11
    ];
  };
  programs = {
    git = {
      enable = true;
      userName = "Andrej Palicka";
      userEmail = "andrej.palicka@gmail.com";
      aliases = {
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        fap = "fetch -ap";
        co = "checkout";
        cob = "checkout -b";
        unstage = "reset HEAD --";
        ci = "commit";
        ciam = "commit -am";
        st = "status";
        br = "branch";
        type = "cat-file -t";
        dump = "cat-file -p";
        ff = "merge --ff";
      };
      signing = {
        key = "7E2DD79792CEC919";
        signByDefault = true;
      };
      ignores = [
        ".vscode"
        ".mypy_cache"
        ".pytest_cache"
        "docker-compose.dev.yaml"
        ".env"
        "docs/README.md"
        "*.~lock*"
        "*.egg-info/"
        ".idea/"
        ".metals/"
        ".bloop/"
        "target/"
      ];
      extraConfig = {
        rerere = {
          enabled = true;
        };
        pull = {
          rebase = true;
        };
      };
      includes = [{
        contents = {
          core = {
            editor = "vim";
          };
          push = {
            default = "simple";
          };
        };
      }];
    };
  };
  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

}
