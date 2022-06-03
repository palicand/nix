{ config, pkgs, ... }:

{
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

    packages = with pkgs; [
      wget
      tmux
      yadm
      fzf
      yarn
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
      alacritty
    ];
  };
    programs = {
      zsh = {
        localVariables = {
          LANG = "en_US.UTF-8";
          GPG_TTY = "/dev/ttys000";
          CLICOLOR = 1;
          LS_COLORS = "ExFxBxDxCxegedabagacad";
          TERM = "xterm-256color";
        };

        enable = true;
        autocd = true;
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "sudo" "common-aliases" ];
        };
        initExtra = ''
          if [[ -d /opt/homebrew ]]; then
                  eval "$(/opt/homebrew/bin/brew shellenv)"
          fi
          SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
          source <(kubectl completion zsh)
          complete -F __start_kubectl k
        '';
        shellAliases = {
          grep = "rg";
          cat = "bat";
          iftop = "bandwhich";
          ua = "sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y";
          whatismyip = "dig +short myip.opendns.com @resolver1.opendns.com";
          k = "kubectl";
        };
      };

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
          }
        ];
      };

      starship = {
        enable = true;
        package = pkgs.starship;
      };
      skim = {
        enable = true;
      };

      fzf = {
        enable = false;
      };

      neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
      };

      gitui = {
        enable = true;
      };
    };

    # Use a custom configuration.nix location.
    # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
    # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

}